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
