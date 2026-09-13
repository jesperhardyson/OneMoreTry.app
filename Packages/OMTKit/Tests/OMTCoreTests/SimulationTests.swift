import Testing
@testable import OMTCore

// y mats till figurens CENTRUM. Kanalens inre ar [0, channelHeight].
// Vilande pa golvet => y == characterHeight/2.
// Vilande i taket   => y == channelHeight - characterHeight/2.

@Test func characterRestingOnFloorStaysOnFloor() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)

    for _ in 0..<240 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    #expect(s.y == t.characterHeight / 2)
    #expect(s.vy == 0)
    #expect(s.alive)
}

@Test func runningIntoAFloorObstacleKills() {
    let t = Tuning.reference
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)

    while s.alive && s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall]).state
    }

    #expect(!s.alive)
    // Dog vid hindrets framkant, inte nagonstans efter det.
    #expect(s.x < wall.x + wall.width)
}

@Test func flippingToTheCeilingClearsAFloorObstacle() {
    let t = Tuning.reference
    // Tillrackligt lagt for att hinna upp: flippa direkt vid start.
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)
    s = Simulator.step(s, tuning: t, flip: true, obstacles: [wall]).state

    while s.alive && s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall]).state
    }

    #expect(s.alive)
    #expect(s.y == t.ceilingY)
}

// --- Fysikkontrakt: testade mot analytisk sanning, inte mot implementationen ---

@Test func flipFromRestCrossesTheChannelInFlipDuration() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)
    s = Simulator.step(s, tuning: t, flip: true).state

    while s.y < t.ceilingY && s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    #expect(s.y == t.ceilingY)
    // Semi-implicit Euler ligger ~1 % fore den kontinuerliga losningen.
    #expect(abs(seconds - t.flipDuration) / t.flipDuration < 0.02)
}

@Test func hoverAmplitudeMatchesTheAnalyticFormula() {
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
    s.vy = -t.gravityMagnitude * T / 2   // periodiskt startvillkor

    var lo = Double.infinity
    var hi = -Double.infinity
    for i in 0..<(40 * halfPeriodSteps) {
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

@Test func sweepDetectsABoxThatBothEndpointsMiss() {
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
@Test func narrowlyClearingAnObstacleReportsANearMiss() {
    let t = Tuning.reference
    // Sa hogt att figuren i taket klarar det med 4 enheters marginal.
    let tall = Obstacle(
        surface: .floor,
        x: 300,
        width: 20,
        height: t.channelHeight - t.characterHeight - 4
    )
    var s = SimState.initial(tuning: t)
    var sawNearMiss = false

    var result = Simulator.step(s, tuning: t, flip: true, obstacles: [tall])
    s = result.state
    while s.alive && s.x < 420 {
        result = Simulator.step(s, tuning: t, flip: false, obstacles: [tall])
        s = result.state
        if result.events.contains(where: { if case .nearMiss = $0 { return true }; return false }) {
            sawNearMiss = true
        }
    }

    #expect(s.alive)
    #expect(sawNearMiss)
}

@Test func comfortablyClearingAnObstacleReportsNoNearMiss() {
    let t = Tuning.reference
    let low = Obstacle(surface: .floor, x: 300, width: 20, height: 25)
    var s = SimState.initial(tuning: t)
    var sawNearMiss = false

    var result = Simulator.step(s, tuning: t, flip: true, obstacles: [low])
    s = result.state
    while s.alive && s.x < 420 {
        result = Simulator.step(s, tuning: t, flip: false, obstacles: [low])
        s = result.state
        if result.events.contains(where: { if case .nearMiss = $0 { return true }; return false }) {
            sawNearMiss = true
        }
    }

    #expect(s.alive)
    #expect(!sawNearMiss)
}

@Test func dyingRecordsWhichSurfaceKilledYou() {
    let t = Tuning.reference
    let wall = Obstacle(surface: .floor, x: 200, width: 20, height: 30)
    var s = SimState.initial(tuning: t)
    var cause: DeathCause?

    while s.alive && s.x < 400 {
        let result = Simulator.step(s, tuning: t, flip: false, obstacles: [wall])
        s = result.state
        for event in result.events {
            if case let .died(_, deathCause) = event { cause = deathCause }
        }
    }

    #expect(cause == .floorObstacle)
}

// --- Impulslage ---
// Tap satter vertikal hastighet direkt istallet for att vanda accelerationens
// tecken. Integrerar en gang istallet for tva, vilket ger exakt sqrt(2) ganger
// billigare svavande. Se docs/decision-log.md.

@Test func impulseModeSetsVelocityRegardlessOfWhatItWas() {
    var t = Tuning.reference
    t.mode = .impulse
    var s = SimState.initial(tuning: t)

    // Fall en stund sa att vy hinner bli kraftigt negativ — men inte sa langt
    // att golvklampningen nollar den at oss och testet blir meningslost.
    s.y = t.channelHeight / 2
    for _ in 0..<20 { s = Simulator.step(s, tuning: t, flip: false).state }
    #expect(s.vy < -100)
    #expect(s.y > t.floorY)

    // ...och ett tap ska nolla ut det helt, inte adderas till det.
    s = Simulator.step(s, tuning: t, flip: true).state
    #expect(abs(s.vy - t.impulseSpeed) < t.gravityMagnitude * Simulator.dt * 1.5)
}

@Test func impulseModeNeverFlipsGravity() {
    var t = Tuning.reference
    t.mode = .impulse
    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2

    for i in 0..<200 {
        s = Simulator.step(s, tuning: t, flip: i % 30 == 0).state
        #expect(s.gravity == .down)
    }
}

@Test func impulseHoverExcursionMatchesTheAnalyticFormula() {
    // Toppexkursion efter en impuls = v0^2 / (2g).
    var t = Tuning.reference
    t.mode = .impulse
    let expected = t.impulseSpeed * t.impulseSpeed / (2 * t.gravityMagnitude)

    var s = SimState.initial(tuning: t)
    s.y = t.channelHeight / 2
    let start = s.y
    s = Simulator.step(s, tuning: t, flip: true).state

    var peak = s.y
    while s.vy > 0 {
        s = Simulator.step(s, tuning: t, flip: false).state
        peak = max(peak, s.y)
    }

    // Semi-implicit Euler slanger over med ungefar v0*dt/2, vilket vid
    // dt = 1/240 ar knappt 4 %. Formeln ar designverktyget, simuleringen ar
    // sanningen — 5 % skiljer dem at utan att slappa igenom en riktig bugg.
    #expect(abs((peak - start) - expected) / expected < 0.05)
}
