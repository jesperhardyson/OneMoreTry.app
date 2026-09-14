import Testing
@testable import OMTCore

@Test func `theta wrap is exact in both directions`() {
    #expect(Angle.wrap(0.5) == 0.5)
    #expect(Angle.wrap(4.5) == 0.5)
    #expect(Angle.wrap(-0.5) == 3.5)
    #expect(Angle.wrap(4.0) == 0.0)
    #expect(Angle.wrap(0.0) == 0.0)

    // Adversarial: theta so close to 0 from below that a naive `theta + 4.0`
    // rounds to exactly 4.0, one full ulp outside [0, 4). Se spec §3.6 och
    // beslutsloggen. Invarianten far korrigeras, men far aldrig brytas.
    let tinyNegative = -0x1p-53
    let wrapped = Angle.wrap(tinyNegative)
    #expect(wrapped >= 0)
    #expect(wrapped < 4)
}

@Test func `wrapped delta finds the shortest signed distance to a wall`() {
    #expect(Angle.wrappedDelta(0.5, 0) == 0.5)
    #expect(Angle.wrappedDelta(3.5, 0) == -0.5)
    // 0.125/3.875/0.25 ar exakt representerbara i binart flyttal (2^-3, 31/8,
    // 2^-2), sa testet paverkas inte av flyttalsbrus fran subtraktionen —
    // 0.1/3.9 skulle inte vara det.
    #expect(Angle.wrappedDelta(0.125, 3.875) == 0.25)
    // Symmetriskt intrade: alltid -2, aldrig +2, oavsett argumentordning.
    // Se spec §4.2.
    #expect(Angle.wrappedDelta(2, 0) == -2)
    #expect(Angle.wrappedDelta(0, 2) == -2)
}

@Test func `a quarter turn from rest takes flip duration`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.downWall = 1

    while s.theta < 1, s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    #expect(s.theta == 1)
    #expect(abs(seconds - t.flipDuration) / t.flipDuration < 0.02)
}

@Test func `opposite wall traverse takes sqrt two flip durations`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.downWall = 2 // motsatt vagg fran theta = 0: symmetriskt intrade

    while s.theta < 2, s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    let expected = t.flipDuration * 2.0.squareRoot()
    #expect(s.theta == 2)
    #expect(abs(seconds - expected) / expected < 0.02)
}

@Test func `symmetric entry falls in tap direction`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = 2
    s.downWall = 0

    s = Simulator.step(s, tuning: t, flip: false).state
    #expect(s.theta > 2)
}

@Test func `orbital hold amplitude matches the analytic formula`() {
    var t = Tuning.reference
    t.mode = .tube
    let tapsPerSecond = 16.0 // val over tubens tröskel (~11,3/s), se spec §3.5
    let halfPeriod = 1 / tapsPerSecond
    let halfPeriodSteps = Int((halfPeriod / Simulator.dt).rounded())
    // `downWall` avancerar ett steg per tap (`(downWall+1)%4`), inte ett
    // 2-vagsbyte — att komma tillbaka till samma relativa fas mot vaggen tar
    // darfor 4 tap, inte 2. Den naturliga svangningsperioden ar `4*halfPeriod`,
    // dubbelt den period en 2-lages-modell skulle ge. Amplituden under
    // bang-bang-acceleration skalar med periodens kvadrat, sa den dubbla
    // perioden ger exakt 4x amplituden en 2-lages-harledning skulle forutsaga
    // (`halfPeriod^2 / (2*flipDuration^2)`). Se beslutsloggen 2026-09-14.
    let expectedAmplitude = t.alphaMagnitude * halfPeriod * halfPeriod

    // Startpunkt vid vila, symmetriskt intrade mot motsatt vagg — samma
    // konfiguration som `opposite wall traverse`. Verifierad numeriskt att
    // detta konvergerar till den stabila svangningen inom toleransen.
    var s = SimState.initial(tuning: t)
    s.theta = 0
    s.downWall = 2
    s.vTheta = 0

    var lo = Double.infinity
    var hi = -Double.infinity
    for i in 0 ..< (40 * halfPeriodSteps) {
        let flip = i > 0 && i % halfPeriodSteps == 0
        s = Simulator.step(s, tuning: t, flip: flip).state
        if i > 30 * halfPeriodSteps {
            lo = min(lo, s.theta)
            hi = max(hi, s.theta)
        }
    }

    let measured = hi - lo
    #expect(abs(measured - expectedAmplitude) / expectedAmplitude < 0.05)
}

@Test func `orbital hold collapses below the directional threshold`() {
    var t = Tuning.reference
    t.mode = .tube
    let tapsPerSecond = 8.0 // under tubens tröskel (~11,3/s): cirkulerar istallet
    let halfPeriodSteps = Int((1 / tapsPerSecond / Simulator.dt).rounded())

    var s = SimState.initial(tuning: t)
    var totalTravel = 0.0
    var previousTheta = s.theta

    for i in 0 ..< (20 * halfPeriodSteps) {
        let flip = i > 0 && i % halfPeriodSteps == 0
        s = Simulator.step(s, tuning: t, flip: flip).state
        totalTravel += abs(Angle.wrappedDelta(s.theta, previousTheta))
        previousTheta = s.theta
    }

    // Havallning skulle ge en total forflyttning i storleksordningen amplituden
    // (< 4). Cirkulation varvar hela slingan flera ganger.
    #expect(totalTravel > 8)
}
