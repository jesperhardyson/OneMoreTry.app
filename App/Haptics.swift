import CoreHaptics

/// Core Haptics med transienter. For ett spel dar tummen bara far visuell
/// aterkoppling ar en 10 ms transient oproportionerligt mycket kansla.
///
/// Kritisk fallgrop: motorn stoppar vid avbrott. Utan `resetHandler` och
/// `stoppedHandler` dor haptiken tyst efter forsta telefonsamtalet. Se spec §7.
@MainActor
final class Haptics {
    private var engine: CHHapticEngine?
    private var supported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func start() {
        guard supported, engine == nil else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true

        engine?.resetHandler = { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { try? self.engine?.start() }
        }
        engine?.stoppedHandler = { _ in }

        try? engine?.start()
    }

    func transient(intensity: Float, sharpness: Float) {
        guard supported, let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        guard
            let pattern = try? CHHapticPattern(events: [event], parameters: []),
            let player = try? engine.makePlayer(with: pattern)
        else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}
