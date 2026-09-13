import Testing
@testable import OMTCore

// y mats till figurens CENTRUM. Kanalens inre ar [0, channelHeight].
// Vilande pa golvet => y == characterHeight/2.
// Vilande i taket   => y == channelHeight - characterHeight/2.

@Test func characterRestingOnFloorStaysOnFloor() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)

    for _ in 0..<240 {
        s = Simulator.step(s, tuning: t, flip: false)
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
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall])
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
    s = Simulator.step(s, tuning: t, flip: true, obstacles: [wall])

    while s.alive && s.x < 400 {
        s = Simulator.step(s, tuning: t, flip: false, obstacles: [wall])
    }

    #expect(s.alive)
    #expect(s.y == t.ceilingY)
}

// --- Fysikkontrakt: testade mot analytisk sanning, inte mot implementationen ---

@Test func flipFromRestCrossesTheChannelInFlipDuration() {
    let t = Tuning.reference
    var s = SimState.initial(tuning: t)
    s = Simulator.step(s, tuning: t, flip: true)

    while s.y < t.ceilingY && s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false)
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
        s = Simulator.step(s, tuning: t, flip: flip)
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
