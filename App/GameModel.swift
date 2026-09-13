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

    private(set) var state: SimState
    private(set) var obstacles: [Obstacle] = []
    private(set) var bestDistance: Double = 0
    private(set) var lastDistance: Double = 0
    private(set) var frameRate: Double = 0

    let feedback = Feedback()

    private var accumulator: Double = 0
    private var lastFrameTime: CFTimeInterval?
    private var runStartUptime: CFTimeInterval = 0
    private var pendingTapSteps: [UInt32] = []
    private var nextSpawnX: Double = 500
    private var rngState: UInt64 = 0x9E37_79B9_7F4A_7C15

    init() {
        state = SimState.initial(tuning: Tuning.reference)
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
        if elapsed > 0 { frameRate = 1 / elapsed }

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
        let raw = (uptime - runStartUptime) * Simulator.stepsPerSecond
        let touchStep = UInt32(max(0, raw.rounded(.down)))
        // Klampa framat: en touch kan ha en tidsstampel tidigare an steg
        // vi redan simulerat.
        pendingTapSteps.append(max(touchStep, state.step))
    }

    func restart() {
        lastDistance = state.x
        bestDistance = max(bestDistance, state.x)
        state = SimState.initial(tuning: tuning)
        obstacles.removeAll()
        pendingTapSteps.removeAll()
        nextSpawnX = 500
        rngState = 0x9E37_79B9_7F4A_7C15
        accumulator = 0
        runStartUptime = lastFrameTime ?? 0
    }

    private func advanceOneStep() {
        guard state.alive else { return }

        var flip = false
        while let first = pendingTapSteps.first, first <= state.step {
            pendingTapSteps.removeFirst()
            flip = true
        }

        generateAhead()
        let result = Simulator.step(state, tuning: tuning, flip: flip, obstacles: obstacles)
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

    private func generateAhead() {
        let horizon = state.x + 1400
        while nextSpawnX < horizon {
            let onFloor = (nextRandom() & 1) == 0
            let height = tuning.usableHeight * (0.30 + 0.30 * difficulty)
            obstacles.append(
                Obstacle(
                    surface: onFloor ? .floor : .ceiling,
                    x: nextSpawnX,
                    width: 34,
                    height: height
                )
            )
            nextSpawnX += 460 - 190 * difficulty
        }
        obstacles.removeAll { $0.x + $0.width < state.x - 300 }
    }
}
