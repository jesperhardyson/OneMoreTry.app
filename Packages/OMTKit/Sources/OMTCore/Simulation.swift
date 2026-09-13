// OMTCore — simulering. Importerar ingenting. Se CLAUDE.md.

/// Gravitationens riktning. Binart tillstand — det ar hela poangen med mekaniken.
public enum Sign: Sendable {
    case down, up

    public var flipped: Sign { self == .down ? .up : .down }
    var acceleration: Double { self == .down ? -1 : 1 }
}

/// Vad ett tap gor. Se docs/decision-log.md 2026-09-13.
public enum ControlMode: Sendable, Hashable {
    /// Tap vander accelerationens tecken. Position ar dubbelintegralen av
    /// input, sa kostnaden att halla en korridor skalar som 1/T^2.
    case gravityFlip
    /// Tap satter vertikal hastighet direkt. En integration istallet for tva,
    /// vilket ger exakt sqrt(2) ganger billigare svavande.
    case impulse
}

/// Trimkonstanter. Det justerbara vardet ar `flipFootprint` — hur langt figuren
/// fardas horisontellt under en full kanalkorsning, matt i kanalhojder.
/// Scrollhastigheten harleds ur den. Se docs/decision-log.md.
public struct Tuning: Sendable {
    public var channelHeight: Double
    public var characterHeight: Double
    public var characterWidth: Double
    public var flipDuration: Double
    public var flipFootprint: Double
    public var mode: ControlMode
    /// Impulsens styrka som andel av farten vid en full korsning fran vila.
    /// 0,5 ger en exkursion pa 25 % av kanalen per tap.
    public var impulseFraction: Double
    /// Hur mycket uppatriktad fart som behalls nar fingret slapper tidigt.
    /// Lagre varde = storre skillnad mellan ett kort och ett langt tryck.
    public var impulseCutFraction: Double

    public init(
        channelHeight: Double,
        characterHeight: Double,
        characterWidth: Double,
        flipDuration: Double,
        flipFootprint: Double,
        mode: ControlMode = .gravityFlip,
        impulseFraction: Double = 0.5,
        impulseCutFraction: Double = 0.35
    ) {
        self.channelHeight = channelHeight
        self.characterHeight = characterHeight
        self.characterWidth = characterWidth
        self.flipDuration = flipDuration
        self.flipFootprint = flipFootprint
        self.mode = mode
        self.impulseFraction = impulseFraction
        self.impulseCutFraction = impulseCutFraction
    }

    /// Avstandet figurens centrum faktiskt kan rora sig mellan ytorna.
    public var usableHeight: Double { channelHeight - characterHeight }

    /// Harledd sa att en korsning fran vila tar exakt `flipDuration`:
    /// h = 1/2 * g * t^2  =>  g = 2h/t^2
    public var gravityMagnitude: Double {
        2 * usableHeight / (flipDuration * flipDuration)
    }

    public var floorY: Double { characterHeight / 2 }
    public var ceilingY: Double { channelHeight - characterHeight / 2 }
    public var scrollSpeed: Double { flipFootprint * channelHeight / flipDuration }

    /// `squareRoot()` ar stdlib och korrekt avrundad. Fria `sqrt()` kommer fran
    /// Foundation, som OMTCore inte far importera. Se CLAUDE.md.
    public var impulseSpeed: Double {
        impulseFraction * (2 * gravityMagnitude * usableHeight).squareRoot()
    }

    public var impulseCutSpeed: Double { impulseSpeed * impulseCutFraction }

    /// Vertikal marginal under vilken en passage raknas som en near-miss.
    public var nearMissClearance: Double { usableHeight * 0.10 }

    /// Validerad genom spel pa enhet 2026-09-13. Se docs/decision-log.md.
    public static let reference = Tuning(
        channelHeight: 100,
        characterHeight: 20,
        characterWidth: 16,
        flipDuration: 0.22,
        flipFootprint: 1.5
    )
}

/// `step` ar sanningen, inte `t`. 1.0/240.0 ar inte exakt representerbart, sa
/// `t += dt` driver. Se CLAUDE.md.
public struct SimState: Sendable {
    public var step: UInt32
    public var x: Double
    public var y: Double
    public var vy: Double
    public var gravity: Sign
    public var alive: Bool

    public init(step: UInt32, x: Double, y: Double, vy: Double, gravity: Sign, alive: Bool) {
        self.step = step
        self.x = x
        self.y = y
        self.vy = vy
        self.gravity = gravity
        self.alive = alive
    }

    public static func initial(tuning: Tuning) -> SimState {
        SimState(step: 0, x: 0, y: tuning.floorY, vy: 0, gravity: .down, alive: true)
    }
}

public enum Simulator {
    public static let stepsPerSecond: Double = 240
    public static let dt: Double = 1.0 / 240.0

    public static func step(
        _ state: SimState,
        tuning: Tuning,
        flip: Bool,
        holding: Bool = false,
        obstacles: [Obstacle] = []
    ) -> StepResult {
        var s = state
        guard s.alive else { return StepResult(state: s, events: []) }

        var events: [RunEvent] = []

        if flip {
            switch tuning.mode {
            case .gravityFlip:
                s.gravity = s.gravity.flipped
                events.append(.flipped(step: s.step, direction: s.gravity))
            case .impulse:
                // Hastigheten satts, inte adderas: det ar hela skillnaden.
                s.vy = tuning.impulseSpeed
                events.append(.flipped(step: s.step, direction: .up))
            }
        }

        // Mario-kapning: impulsen fyrar med full styrka vid nedtryck, men
        // slapper fingret tidigt kapas farten. Noll extra latens — till skillnad
        // fran ladda-och-slapp, som lagger latens dar spelaren har 150 ms.
        if tuning.mode == .impulse, !holding, s.vy > tuning.impulseCutSpeed {
            s.vy = tuning.impulseCutSpeed
        }

        let x0 = s.x
        let y0 = s.y

        s.vy += s.gravity.acceleration * tuning.gravityMagnitude * dt
        s.y += s.vy * dt
        s.x += tuning.scrollSpeed * dt

        if s.y <= tuning.floorY {
            s.y = tuning.floorY
            s.vy = 0
        } else if s.y >= tuning.ceilingY {
            s.y = tuning.ceilingY
            s.vy = 0
        }

        let hw = tuning.characterWidth / 2
        let hh = tuning.characterHeight / 2

        for obstacle in obstacles {
            let raw = obstacle.box(channelHeight: tuning.channelHeight)
            let box = raw.expanded(byHalfWidth: hw, halfHeight: hh)

            if Sweep.hits(box: box, fromX: x0, fromY: y0, toX: s.x, toY: s.y) {
                s.alive = false
                s.x = x0
                s.y = y0
                events.append(
                    .died(
                        step: s.step,
                        cause: obstacle.surface == .floor ? .floorObstacle : .ceilingObstacle
                    )
                )
                return StepResult(state: s, events: events)
            }

            // Near-miss nar figurens bakkant passerar hindrets bakkant: ett val
            // definierat ogonblick per hinder, och ratt tidpunkt for aterkoppling.
            if x0 - hw <= raw.maxX, s.x - hw > raw.maxX {
                let clearance = obstacle.surface == .floor
                    ? (s.y - hh) - raw.maxY
                    : raw.minY - (s.y + hh)
                if clearance >= 0, clearance <= tuning.nearMissClearance {
                    events.append(.nearMiss(step: s.step, clearance: clearance))
                }
            }
        }

        s.step += 1
        return StepResult(state: s, events: events)
    }
}
