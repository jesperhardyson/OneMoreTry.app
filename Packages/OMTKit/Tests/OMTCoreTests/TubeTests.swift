@testable import OMTCore
import Testing

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

    while s.theta < 1, s.step < 10000 {
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

    while s.theta < 2, s.step < 10000 {
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

@Test func `collision wraps across wall zero`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = Angle.wrap(-0.02) // precis under vagg 0
    s.downWall = 0
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)

    let result = Simulator.step(s, tuning: t, flip: false, wallObstacles: [wall0])
    #expect(!result.state.alive)
    #expect(result.events.contains(.died(step: result.state.step, cause: .wallObstacle)))
}

@Test func `far side of the tube is never hit`() {
    // Slutgranskning 2026-09-14: `hitsWall` wrappade forut d0 och d1 var for
    // sig mot vaggen. `Angle.wrappedDelta` ar diskontinuerlig exakt vid
    // vaggens antipod (theta = 2 for vagg 0): en figur som korsar den punkten
    // under ett steg fick d0 ≈ +1.999 men d1 ≈ -2.0 (independent wrap), och
    // sveptestet interpolerade da ett segment pa nara 4 kvartsvarv — rakt
    // igenom den riktiga traffzonen [-0.6, 0.6] — trots att figuren i
    // verkligheten aldrig var narmare vagg 0 an sin egen antipod.
    //
    // Testet ror figuren fran strax under den motsatta vaggen (vagg 2, som
    // geometriskt AR vagg 0:s antipod) och later den landa exakt pa vagg 2 i
    // ett enda integrationssteg, med ett hinder pa vagg 0. En full cirkulation
    // skulle ocksa passera vagg 0:s egen, riktiga traffzon (en korrekt dod,
    // oberoende av buggen) — det har testet isolerar darfor just antipod-
    // korsningen istallet, som ar den punkt buggen paverkar.
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = Angle.wrap(1.999) // strax under vagg 2 = vagg 0:s antipod
    s.vTheta = 10 // tillrackligt for att steget ska na/passera vagg 2
    s.downWall = 2
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)

    let result = Simulator.step(s, tuning: t, flip: false, wallObstacles: [wall0])

    // Klampen mot malvaggen bekraftar att figuren verkligen korsade/landade
    // pa antipoden under steget — annars testar vi inte det vi tror.
    #expect(result.state.theta == 2)
    #expect(result.state.alive)
}

@Test func `corner overlaps both adjacent walls`() {
    // Korrigerad 2026-09-14 efter fardigbranchens slutgranskning: den ursprungliga
    // versionen placerade figuren pa en vaggcentrum (theta = 1.0), inte i ett horn,
    // och lasta darmed den motsatta egenskapen av den spec §3.7 namnger. Se
    // docs/decision-log.md 2026-09-14.
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = 0.5 // hornet mellan vagg 0 och vagg 1: bada ligger inom threshold 0,6
    s.downWall = 0
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)
    let wall1 = WallObstacle(wall: 1, x: s.x, width: 4)

    let hit0 = Sweep.hitsWall(
        wall: 0, angularHalfWidth: t.angularHalfWidth,
        obstacleMinX: wall0.x - wall0.width / 2, obstacleMaxX: wall0.x + wall0.width / 2,
        fromX: s.x, fromTheta: s.theta, toX: s.x, toTheta: s.theta,
    )
    let hit1 = Sweep.hitsWall(
        wall: 1, angularHalfWidth: t.angularHalfWidth,
        obstacleMinX: wall1.x - wall1.width / 2, obstacleMaxX: wall1.x + wall1.width / 2,
        fromX: s.x, fromTheta: s.theta, toX: s.x, toTheta: s.theta,
    )
    // Pa avstand exakt 0,5 kvartsvarv fran bada vaggarna, innanfor 0,5+0,1-zonen.
    #expect(hit0)
    #expect(hit1)
}

@Test func `fast rotation cannot tunnel through a wall obstacle`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = Angle.wrap(-0.03)
    s.downWall = 1 // accelererar bort fran vagg 0, mot vagg 1
    s.vTheta = 12.8 // nara maxfarten (~12,86 kvartsvarv/s), se spec §3.8
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)

    let result = Simulator.step(s, tuning: t, flip: false, wallObstacles: [wall0])
    #expect(!result.state.alive)
}

@Test func `entering tube mode sets down wall to zero`() {
    let t = Tuning.reference
    // Portalen ligger precis vid starten: korsningen sker redan pa forsta
    // steget, sa inget hinner drifta innan mappningen lases av.
    let portal = Portal(x: 0.001, mode: .tube)
    var s = SimState.initial(tuning: t)
    s.y = t.floorY

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .tube)
    #expect(s.downWall == 0)
}

@Test func `portal transitions preserve relative position entering the tube`() {
    let t = Tuning.reference
    let portal = Portal(x: 0.001, mode: .tube)
    var s = SimState.initial(tuning: t)
    s.y = t.ceilingY
    s.vy = -40 // nedat, sa klampen vid taket inte nollar farten samma steg

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .tube)
    // Tak -> vagg 2. Ett enda steg kanalfysik hinner paverka y/vy nagot
    // innan mappningen lases av (tyngdkraften pa -40 ger en liten forskjutning
    // fran exakt taket) — se rakningen i den brief-lankade motiveringen.
    #expect(abs(s.theta - 2) < 0.01)
    #expect(s.vTheta < 0)
    #expect(s.downWall == 0)
}

@Test func `portal transitions preserve relative position leaving the tube`() {
    var t = Tuning.reference
    t.mode = .tube
    let portal = Portal(x: 0.001, mode: .gravityFlip)
    var s = SimState.initial(tuning: t)
    s.theta = 3
    s.downWall = 3 // redan pa vaggen: klampen i tubintegrationen haller
    // theta/vTheta exakt pa 3/0 aven efter ett integrationssteg.

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .gravityFlip)
    // Vagg 3 -> mitten, med nollfart eftersom figuren vilade pa vaggen.
    #expect(abs(s.y - (t.floorY + t.usableHeight / 2)) < 1e-9)
    #expect(s.vy == 0)
    #expect(s.gravity == .down)
}
