import CoreHaptics

/// Core Haptics med transienter. For ett spel dar tummen bara far visuell
/// aterkoppling ar en 10 ms transient oproportionerligt mycket kansla.
///
/// Kritisk fallgrop: motorn stoppar vid avbrott. Utan `resetHandler` och
/// `stoppedHandler` dor haptiken tyst efter forsta telefonsamtalet. Se spec §7.
@MainActor
final class Haptics {
    private var engine: CHHapticEngine?
    private var supported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

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
        play([(0, intensity, sharpness)])
    }

    /// Tva transienter 70 ms isar. En enkel transient ar redan vad en flipp
    /// betyder, sa portalen maste kanna annorlunda i handen och inte bara
    /// starkare — annars ar tummen den enda sinnet som inte far veta om bytet.
    func doubleTransient(intensity: Float, sharpness: Float) {
        play([(0, intensity, sharpness), (0.07, intensity * 0.8, sharpness)])
    }

    private func play(_ events: [(time: Double, intensity: Float, sharpness: Float)]) {
        guard supported, let engine else { return }
        let hapticEvents = events.map { event in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness),
                ],
                relativeTime: event.time,
            )
        }
        guard
            let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []),
            let player = try? engine.makePlayer(with: pattern)
        else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}
