@testable import OMTCore
import Testing

// y mats till figurens CENTRUM. Kanalens inre ar [0, channelHeight].
// Vilande pa golvet => y == characterHeight/2.
// Vilande i taket   => y == channelHeight - characterHeight/2.

@Test func `character resting on floor stays on floor`() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)

    for _ in 0 ..< 240 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    #expect(s.y == t.characterHeight / 2)
    #expect(s.vy == 0)
    #expect(s.alive)
}

@Test func `running into A floor obstacle kills`() {
    let t = Tuning.reference
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)

    while s.alive, s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall]).state
    }

    #expect(!s.alive)
    // Dog vid hindrets framkant, inte nagonstans efter det.
    #expect(s.x < wall.x + wall.width)
}

@Test func `flipping to the ceiling clears A floor obstacle`() {
    let t = Tuning.reference
    // Tillrackligt lagt for att hinna upp: flippa direkt vid start.
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)
    s = Simulator.step(s, tuning: t, flip: true, obstacles: [wall]).state

    while s.alive, s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall]).state
    }

    #expect(s.alive)
    #expect(s.y == t.ceilingY)
}

// --- Fysikkontrakt: testade mot analytisk sanning, inte mot implementationen ---

@Test func `flip from rest crosses the channel in flip duration`() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)
    s = Simulator.step(s, tuning: t, flip: true).state

    while s.y < t.ceilingY, s.step < 10000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    #expect(s.y == t.ceilingY)
    // Semi-implicit Euler ligger ~1 % fore den kontinuerliga losningen.
    #expect(abs(seconds - t.flipDuration) / t.flipDuration < 0.02)
}

@Test func `hover amplitude matches the analytic formula`() {
    // A = h\u{b7}T\u{b2}/(2\u{b7}t_f\u{b2})  dar h = usableHeight, T = inter-tap-intervall.
    // Den har formeln satter taket for hur trang en svavkorridor kan vara
    // och kopplar flipDuration till tap-takstaket. Se spec \u{a7}1.
    let t = Tuning.reference
    let tapsPerSecond = 8.0
    let T = 1 / tapsPerSecond
    let halfPeriodSteps = Int((T / Simulator.dt).rounded())

    let expected = t.usableHeight * T * T / (2 * t.flipDuration * t.flipDuration)

    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2
    s.gravity = .up
    s.vy = -t.gravityMagnitude * T / 2 // periodiskt startvillkor

    var lo = Double.infinity
    var hi = -Double.infinity
    for i in 0 ..< (40 * halfPeriodSteps) {
        let flip = i > 0 && i % halfPeriodSteps == 0
        s = Simulator.step(s, tuning: t, flip: flip).state
        if i > 30 * halfPeriodSteps {
            lo = min(lo, s.y)
            hi = max(hi, s.y)
        }
    }

    let measured = hi - lo
    #expect(abs(measured - expected) / expected < 0.03)
    // Sanity: vid 8 tap/s ar korridoren ~16 % av anvandbar hojd.
    #expect(abs(measured / t.usableHeight - 0.161) < 0.01)
}

@Test func `sweep detects A box that both endpoints miss`() {
    // Skalet till att kollisionen ar svept och inte ett punkttest: bada
    // andpunkterna ligger utanfor ladan, men vagen gar rakt igenom den.
    let box = AABB(minX: 4, maxX: 6, minY: 4, maxY: 6)
    #expect(Sweep.hits(box: box, fromX: 0, fromY: 0, toX: 10, toY: 10))
    #expect(!Sweep.hits(box: box, fromX: 0, fromY: 8, toX: 10, toY: 8))
}

// --- Handelser ---

/// Near-miss rapporteras nar figuren precis passerat ett hinders bakkant, inte
/// medan den ar bredvid det: det ar ett val definierat ogonblick per hinder, och
/// det ar da spelaren ska fa veta att hen klarade sig knappt.
@Test func `narrowly clearing an obstacle reports A near miss`() {
    let t = Tuning.reference
    // Sa hogt att figuren i taket klarar det med 4 enheters marginal.
    let tall = Obstacle(
        surface: .floor,
        x: 300,
        width: 20,
        height: t.channelHeight - t.characterHeight - 4,
    )
    var s = SimState.initial(tuning: t)
    var sawNearMiss = false

    var result = Simulator.step(s, tuning: t, flip: true, obstacles: [tall])
    s = result.state
    while s.alive, s.x < 420 {
        result = Simulator.step(s, tuning: t, flip: false, obstacles: [tall])
        s = result.state
        if result.events.contains(where: {
            if case .nearMiss = $0 {
                return true
            }; return false
        }) {
            sawNearMiss = true
        }
    }

    #expect(s.alive)
    #expect(sawNearMiss)
}

@Test func `comfortably clearing an obstacle reports no near miss`() {
    let t = Tuning.reference
    let low = Obstacle(surface: .floor, x: 300, width: 20, height: 25)
    var s = SimState.initial(tuning: t)
    var sawNearMiss = false

    var result = Simulator.step(s, tuning: t, flip: true, obstacles: [low])
    s = result.state
    while s.alive, s.x < 420 {
        result = Simulator.step(s, tuning: t, flip: false, obstacles: [low])
        s = result.state
        if result.events.contains(where: {
            if case .nearMiss = $0 {
                return true
            }; return false
        }) {
            sawNearMiss = true
        }
    }

    #expect(s.alive)
    #expect(!sawNearMiss)
}

@Test func `dying records which surface killed you`() {
    let t = Tuning.reference
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)
    var cause: DeathCause?

    while s.alive, s.x < 400 {
        let result = Simulator.step(s, tuning: t, flip: false, obstacles: [wall])
        s = result.state
        for event in result.events {
            if case let .died(_, deathCause) = event {
                cause = deathCause
            }
        }
    }

    #expect(cause == .floorObstacle)
}

// --- Impulslage ---
// Tap satter vertikal hastighet direkt istallet for att vanda accelerationens
// tecken. Integrerar en gang istallet for tva, vilket ger exakt sqrt(2) ganger
// billigare svavande. Se docs/decision-log.md.

@Test func `impulse mode sets velocity regardless of what it was`() {
    var t = Tuning.reference
    t.mode = .impulse
    var s = SimState.initial(tuning: t)

    // Fall en stund sa att vy hinner bli kraftigt negativ — men inte sa langt
    // att golvklampningen nollar den at oss och testet blir meningslost.
    s.y = t.channelHeight / 2
    for _ in 0 ..< 20 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }
    #expect(s.vy < -100)
    #expect(s.y > t.floorY)

    // ...och ett tap ska nolla ut det helt, inte adderas till det.
    // `holding: true` = fingret nere, alltsa full impuls utan kapning.
    s = Simulator.step(s, tuning: t, flip: true, holding: true).state
    #expect(abs(s.vy - t.impulseSpeed) < t.gravityMagnitude * Simulator.dt * 1.5)
}

@Test func `impulse mode never flips gravity`() {
    var t = Tuning.reference
    t.mode = .impulse
    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2

    for i in 0 ..< 200 {
        s = Simulator.step(s, tuning: t, flip: i % 30 == 0).state
        #expect(s.gravity == .down)
    }
}

@Test func `impulse hover excursion matches the analytic formula`() {
    // Toppexkursion efter en impuls = v0^2 / (2g).
    var t = Tuning.reference
    t.mode = .impulse
    let expected = t.impulseSpeed * t.impulseSpeed / (2 * t.gravityMagnitude)

    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2
    let start = s.y
    s = Simulator.step(s, tuning: t, flip: true, holding: true).state

    // Fingret hals nere hela stigningen: formeln beskriver ett okapat hopp.
    var peak = s.y
    while s.vy > 0 {
        s = Simulator.step(s, tuning: t, flip: false, holding: true).state
        peak = max(peak, s.y)
    }

    // Semi-implicit Euler slanger over med ungefar v0*dt/2, vilket vid
    // dt = 1/240 ar knappt 4 %. Formeln ar designverktyget, simuleringen ar
    // sanningen — 5 % skiljer dem at utan att slappa igenom en riktig bugg.
    #expect(abs((peak - start) - expected) / expected < 0.05)
}

// --- Variabel hopphojd (Mario-kapning) ---
// Impulsen fyrar med full styrka vid nedtryck. Slapper spelaren tidigt kapas
// den uppatriktade hastigheten. Noll extra latens, en analog axel.

private func peakRise(holdSteps: Int, tuning t: Tuning) -> Double {
    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2
    let start = s.y
    var peak = s.y
    var i = 0
    repeat {
        let result = Simulator.step(
            s, tuning: t, flip: i == 0, holding: i < holdSteps, obstacles: [],
        )
        s = result.state
        peak = max(peak, s.y)
        i += 1
    } while s.vy > 0 && i < 5000
    return peak - start
}

@Test func `releasing early produces A lower jump`() {
    var t = Tuning.reference
    t.mode = .impulse

    let tap = peakRise(holdSteps: 1, tuning: t)
    let held = peakRise(holdSteps: 600, tuning: t)

    #expect(tap < held * 0.5)
    #expect(tap > 0)
}

@Test func `holding beyond the decay point adds nothing`() {
    var t = Tuning.reference
    t.mode = .impulse

    // Nar hastigheten fallit under kapningsnivan gor ett slapp ingenting,
    // sa hopphojden ar bunden av gravitationen — ingen timer behovs.
    let long = peakRise(holdSteps: 600, tuning: t)
    let longer = peakRise(holdSteps: 2000, tuning: t)

    #expect(abs(long - longer) < 0.001)
}

@Test func `releasing when already slow does not speed you up`() {
    var t = Tuning.reference
    t.mode = .impulse
    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2
    s.vy = 5 // langsammare an kapningsnivan

    let after = Simulator.step(s, tuning: t, flip: false, holding: false).state
    #expect(after.vy < 5)
}

@Test func `hold has no effect in gravity flip mode`() {
    let t = Tuning.reference // .gravityFlip
    var held = SimState.initial(tuning: t)
    var released = held
    held.y = t.channelHeight / 2
    released.y = t.channelHeight / 2

    held = Simulator.step(held, tuning: t, flip: true, holding: true).state
    released = Simulator.step(released, tuning: t, flip: true, holding: false).state

    #expect(held.vy == released.vy)
}

// --- Portaler ---
// Geometry Dash-modellen: mekaniken byter mitt i korningen. Bytet ar sjalv den
// svaraste fardigheten. Laget bor darfor i SimState, inte i Tuning.

@Test func `crossing A portal changes the active mode`() {
    let t = Tuning.reference // startar i .gravityFlip
    let portal = Portal(x: 300, mode: .impulse)
    var s = SimState.initial(tuning: t)
    #expect(s.mode == .gravityFlip)

    while s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state
    }
    #expect(s.mode == .impulse)
}

@Test func `entering impulse mode forces gravity down`() {
    let t = Tuning.reference
    let portal = Portal(x: 300, mode: .impulse)
    var s = SimState.initial(tuning: t)

    // Flippa till taket forst, sa att gravitationen pekar uppat vid portalen.
    s = Simulator.step(s, tuning: t, flip: true, portals: [portal]).state
    #expect(s.gravity == .up)

    while s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state
    }
    // Impulslaget forutsatter gravitation nedat — annars faller spelaren uppat
    // och ett tap gor motsatsen till vad hen forvantar sig.
    #expect(s.gravity == .down)
}

@Test func `crossing A portal emits an event`() {
    let t = Tuning.reference
    let portal = Portal(x: 300, mode: .impulse)
    var s = SimState.initial(tuning: t)
    var changes: [ControlMode] = []

    while s.x < 400 {
        let result = Simulator.step(s, tuning: t, flip: false, portals: [portal])
        s = result.state
        for event in result.events {
            if case let .modeChanged(_, mode) = event {
                changes.append(mode)
            }
        }
    }
    // Exakt en gang: bytet maste bara pa ljud och haptik, och en portal bakom
    // dig far aldrig fyra igen.
    #expect(changes == [.impulse])
}
