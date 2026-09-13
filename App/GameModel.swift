import OMTCore
import QuartzCore

/// M1-prototyp. Avsiktligt slang-och-glom: den finns for att svara pa
/// "kanns gravitationsvandningen bra?" och inget annat. Se spec §13.
@MainActor
@Observable
final class GameModel {
    var tuning = Tuning.reference
    /// Den enda svarighetsratten.
    var difficulty: Double = 0.35
    /// Portaler av/pa, sa trimpasset kan jamforas mot ett enda lage.
    var portalsEnabled = true
    /// Sekunder mellan portaler, jitter oraknat. Sekunder och inte varldsenheter
    /// darfor att det spelaren upplever ar takten, och den ar oberoende av
    /// scrollhastigheten.
    var portalPeriod: Double = 4.5

    private(set) var state: SimState
    private(set) var obstacles: [Obstacle] = []
    private(set) var portals: [Portal] = []
    private(set) var bestDistance: Double = 0
    private(set) var lastDistance: Double = 0
    private(set) var frameRate: Double = 0

    let feedback = Feedback()

    private var accumulator: Double = 0
    private var lastFrameTime: CFTimeInterval?
    private var runStartUptime: CFTimeInterval = 0
    private var pendingPressSteps: [UInt32] = []
    private var pendingReleaseSteps: [UInt32] = []
    private var isHolding = false
    private var nextSpawnX: Double = firstSpawnX
    private var nextPortalX: Double = 0
    private var lastPlannedMode: ControlMode = .gravityFlip
    private var rngState: UInt64 = seedState

    private static let firstSpawnX: Double = 500
    private static let seedState: UInt64 = 0x9E37_79B9_7F4A_7C15
    private static let obstacleWidth: Double = 34
    /// Sa langt fram hinder genereras. Portalhorisonten ligger med marginal
    /// bortom den: ett hinder som ska prova sin sakerhetszon maste kunna se
    /// portalen som zonen tillhor, aven nar zonen ar frikostig.
    private static let obstacleHorizon: Double = 1400
    private static let portalHorizon: Double = 3200

    init() {
        state = SimState.initial(tuning: Tuning.reference)
        resetGeneration()
    }

    // MARK: - Loop

    func frame(at now: CFTimeInterval) {
        guard let last = lastFrameTime else {
            lastFrameTime = now
            runStartUptime = now
            return
        }
        // Ackumulatorklamp: utan den simuleras tiotusentals steg i en frame
        // vid aterkomst fran bakgrunden. Se CLAUDE.md.
        let elapsed = min(now - last, 0.25)
        lastFrameTime = now
        if elapsed > 0 {
            frameRate = 1 / elapsed
        }

        accumulator += elapsed
        while accumulator >= Simulator.dt {
            accumulator -= Simulator.dt
            advanceOneStep()
        }
    }

    /// `uptime` maste komma fran `UITouch.timestamp` — samma klockbas som
    /// `CADisplayLink.timestamp`. Aldrig en `Date`. Se CLAUDE.md.
    func tap(atUptime uptime: CFTimeInterval) {
        guard state.alive else {
            restart()
            return
        }
        pendingPressSteps.append(quantise(uptime))
    }

    /// Slapp. Kapar hoppet i impulslaget — se `Tuning.impulseCutSpeed`.
    func release(atUptime uptime: CFTimeInterval) {
        pendingReleaseSteps.append(quantise(uptime))
    }

    /// Samma klampningsregel for bada: en touch kan ha en tidsstampel tidigare
    /// an steg vi redan simulerat, och replayen lagrar det klampade steget.
    private func quantise(_ uptime: CFTimeInterval) -> UInt32 {
        let raw = (uptime - runStartUptime) * Simulator.stepsPerSecond
        return max(UInt32(max(0, raw.rounded(.down))), state.step)
    }

    func restart() {
        lastDistance = state.x
        bestDistance = max(bestDistance, state.x)
        state = SimState.initial(tuning: tuning)
        pendingPressSteps.removeAll()
        pendingReleaseSteps.removeAll()
        isHolding = false
        accumulator = 0
        runStartUptime = lastFrameTime ?? 0
        feedback.reset()
        resetGeneration()
    }

    /// Omstart ror ingen GPU-resurs och inget annat an det som beskriver banan.
    /// Samma frosadd varje gang: en omstart ska ge samma bana, annars kan
    /// spelaren inte lara sig den. Se spec §3.
    private func resetGeneration() {
        obstacles.removeAll()
        portals.removeAll()
        nextSpawnX = Self.firstSpawnX
        // Noll och inte `firstSpawnX`: planeraren stegar fram en hel period
        // *innan* den placerar, sa oppningen spelas alltid i startlaget.
        nextPortalX = 0
        lastPlannedMode = tuning.mode
        rngState = Self.seedState
    }

    private func advanceOneStep() {
        guard state.alive else { return }

        var flip = false
        while let first = pendingPressSteps.first, first <= state.step {
            pendingPressSteps.removeFirst()
            flip = true
            isHolding = true
        }
        // Slapp konsumeras efter nedtryck, sa ett tryck kortare an ett steg
        // registreras som ett omedelbart slapp — kortast mojliga hopp.
        while let first = pendingReleaseSteps.first, first <= state.step {
            pendingReleaseSteps.removeFirst()
            isHolding = false
        }

        generateAhead()
        let result = Simulator.step(
            state, tuning: tuning, flip: flip, holding: isHolding,
            obstacles: obstacles, portals: portals,
        )
        state = result.state
        for event in result.events {
            feedback.emit(event)
        }
    }

    // MARK: - Procedurell bana

    private func nextRandom() -> UInt64 {
        rngState = rngState &+ 0x9E37_79B9_7F4A_7C15
        var z = rngState
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Ett slumptal i [0,1). `>> 11` och `0x1p-53`, aldrig
    /// `Double.random(in:using:)` — se CLAUDE.md.
    private func nextUnitRandom() -> Double {
        Double(nextRandom() >> 11) * 0x1p-53
    }

    private func generateAhead() {
        // Portaler forst: deras sakerhetszon far knuffa `nextSpawnX` framat, och
        // det maste hinna ske innan hindren pa den stracken placeras.
        planPortals(upTo: state.x + Self.portalHorizon)
        planObstacles(upTo: state.x + Self.obstacleHorizon)

        obstacles.removeAll { $0.x + $0.width < state.x - 300 }
        portals.removeAll { $0.x < state.x - 300 }
    }

    private func planPortals(upTo horizon: Double) {
        guard portalsEnabled else { return }
        while nextPortalX < horizon {
            // Jitter sa att takten inte blir metronomisk; portalen ska lasas fran
            // skarmen, inte forutsagas ur rytmen.
            let jitter = 0.8 + 0.4 * nextUnitRandom()
            nextPortalX += tuning.scrollSpeed * portalPeriod * jitter

            // Portalerna alternerar. Tva portaler till samma lage i rad vore en
            // no-op i karnan — den hoppar over en portal till redan aktivt lage.
            let mode: ControlMode = lastPlannedMode == .impulse ? .gravityFlip : .impulse
            lastPlannedMode = mode
            portals.append(Portal(x: nextPortalX, mode: mode))
        }
    }

    private func planObstacles(upTo horizon: Double) {
        while nextSpawnX < horizon {
            // Zonen provas vid *placeringen*, inte nar portalen planeras.
            // `nextSpawnX` kryper framat over hundratals frames och kan glida in
            // i en zon langt efter att portalen lades till.
            if let blocking = portals.first(where: { overlapsGuardZone(nextSpawnX, $0) }) {
                // Strikt framatgaende, sa loopen alltid terminerar.
                nextSpawnX = blocking.x + guardZone(for: blocking.mode).after
                continue
            }

            let onFloor = (nextRandom() & 1) == 0
            let height = tuning.usableHeight * (0.30 + 0.30 * difficulty)
            obstacles.append(
                Obstacle(
                    surface: onFloor ? .floor : .ceiling,
                    x: nextSpawnX,
                    width: Self.obstacleWidth,
                    height: height,
                ),
            )
            nextSpawnX += 460 - 190 * difficulty
        }
    }

    private func overlapsGuardZone(_ spawnX: Double, _ portal: Portal) -> Bool {
        let zone = guardZone(for: portal.mode)
        return spawnX + Self.obstacleWidth > portal.x - zone.before
            && spawnX < portal.x + zone.after
    }

    /// Tom bana fore och efter en portal, i varldsenheter.
    ///
    /// Det har ar portalens hela rattvisefraga. Ett hinder precis fore portalen
    /// tvingar spelaren att lasa geometri och lagesbyte i samma ogonblick; ett
    /// hinder precis efter kraver ett korrekt tap i ett lage hen just fick.
    /// Samtidigt ar tom bana dott tempo, och `difficulty` ska kunna ata zonen.
    ///
    /// TODO: satt policyn. Platshallaren nedan ar en symmetrisk halvsekund —
    /// medvetet naiv.
    private func guardZone(for mode: ControlMode) -> (before: Double, after: Double) {
        let seconds = 0.5
        return (before: tuning.scrollSpeed * seconds, after: tuning.scrollSpeed * seconds)
    }
}
