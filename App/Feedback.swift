import OMTCore

/// Enda konsumenten av `RunEvent` i lager 1. Simuleringen vet inte att den finns.
///
/// `emit` ar `nonisolated` for att uppfylla protokollet i OMTCore, men anropas
/// alltid fran main — darav `assumeIsolated`, som ar synkron och inte kostar
/// ett hopp. Ett `AsyncStream` hade lagt en frame eller tva pa ett flippljud i
/// ett spel vars hela identitet ar responsivitet. Se CLAUDE.md.
@MainActor
final class Feedback: RunEventSink {
    private let audio = AudioEngine()
    private let haptics = Haptics()
    private(set) var lastNearMissStep: UInt32?

    func start() {
        audio.start()
        haptics.start()
    }

    nonisolated func emit(_ event: RunEvent) {
        MainActor.assumeIsolated { handle(event) }
    }

    private func handle(_ event: RunEvent) {
        switch event {
        case let .flipped(_, direction):
            audio.play(direction == .up ? .flipUp : .flipDown)
            haptics.transient(intensity: 0.45, sharpness: 0.75)

        case let .nearMiss(step, _):
            lastNearMissStep = step
            audio.play(.nearMiss)
            haptics.transient(intensity: 0.30, sharpness: 1.0)

        case .died:
            audio.play(.death)
            haptics.transient(intensity: 1.0, sharpness: 0.25)
        }
    }
}
