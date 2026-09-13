// OMTCore — simulering. Importerar ingenting. Se CLAUDE.md.

/// Gravitationens riktning. Bin\u{e4}rt tillst\u{e5}nd — det \u{e4}r hela po\u{e4}ngen med mekaniken.
public enum Sign: Sendable {
    case down, up

    public var flipped: Sign { self == .down ? .up : .down }
    var acceleration: Double { self == .down ? -1 : 1 }
}

/// Trimkonstanter. Det justerbara v\u{e4}rdet \u{e4}r `flipFootprint` — hur l\u{e5}ngt figuren
/// f\u{e4}rdas horisontellt under en full kanalkorsning, m\u{e4}tt i kanalh\u{f6}jder.
/// `flipDuration` och scrollhastigheten h\u{e4}rleds ur den. Se spec \u{a7}15.
public struct Tuning: Sendable {
    public var channelHeight: Double
    public var characterHeight: Double
    public var characterWidth: Double
    public var flipDuration: Double
    public var flipFootprint: Double

    public init(
        channelHeight: Double,
        characterHeight: Double,
        characterWidth: Double,
        flipDuration: Double,
        flipFootprint: Double
    ) {
        self.channelHeight = channelHeight
        self.characterHeight = characterHeight
        self.characterWidth = characterWidth
        self.flipDuration = flipDuration
        self.flipFootprint = flipFootprint
    }

    /// Accelerationens storlek, h\u{e4}rledd s\u{e5} att en korsning fr\u{e5}n vila tar exakt
    /// `flipDuration`: h = \u{bd}\u{b7}g\u{b7}t\u{b2}  =>  g = 2h/t\u{b2}
    public var gravityMagnitude: Double {
        2 * usableHeight / (flipDuration * flipDuration)
    }

    /// Avst\u{e5}ndet figurens centrum faktiskt kan r\u{f6}ra sig mellan ytorna.
    public var usableHeight: Double { channelHeight - characterHeight }

    public var floorY: Double { characterHeight / 2 }
    public var ceilingY: Double { channelHeight - characterHeight / 2 }

    public var scrollSpeed: Double { flipFootprint * channelHeight / flipDuration }

    public static let reference = Tuning(
        channelHeight: 100,
        characterHeight: 20,
        characterWidth: 16,
        flipDuration: 0.22,
        flipFootprint: 1.5
    )
}

/// `step` \u{e4}r sanningen, inte `t`. 1.0/240.0 \u{e4}r inte exakt representerbart, s\u{e5}
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
        obstacles: [Obstacle] = []
    ) -> SimState {
        var s = state
        guard s.alive else { return s }

        if flip { s.gravity = s.gravity.flipped }

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
            let box = obstacle
                .box(channelHeight: tuning.channelHeight)
                .expanded(byHalfWidth: hw, halfHeight: hh)
            if Sweep.hits(box: box, fromX: x0, fromY: y0, toX: s.x, toY: s.y) {
                s.alive = false
                s.x = x0
                s.y = y0
                break
            }
        }

        s.step += 1
        return s
    }
}
