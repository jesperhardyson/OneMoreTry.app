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
    /// Steget da laget senast byttes, sa renderaren kan blanka portalen. Ett
    /// steg, inte en tid: `SimState.step` ar sanningen. Se CLAUDE.md.
    private(set) var lastModeChangeStep: UInt32?

    func start() {
        audio.start()
        haptics.start()
    }

    /// Stegen nollstalls vid omstart, sa ett kvarlamnat steg fran forra korningen
    /// ligger i framtiden och skulle lasas som "nyss".
    func reset() {
        lastNearMissStep = nil
        lastModeChangeStep = nil
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

        // Lagesforvirring ar portalens hela risk: en spelare som dor for att hen
        // trodde fel lage var aktivt skyller pa spelet, och premissen ar att
        // doden alltid ar ditt fel. Darfor bar bytet pa tre sinnen samtidigt —
        // ljud har, palett och figurfarg i ContentView.
        case let .modeChanged(step, mode):
            lastModeChangeStep = step
            audio.play(mode == .impulse ? .portalImpulse : .portalGravity)
            haptics.doubleTransient(intensity: 0.85, sharpness: 0.45)
        }
    }
}
