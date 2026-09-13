import AVFoundation

/// Ljuden syntetiseras i kod. Skalet ar inte renlarighet: ett publikt repo
/// distribuerar varje committad fil, sa noll ljudfiler betyder noll
/// licensfragor — och tonhojd och avklingning blir justerbara konstanter
/// istallet for nagot man maste hitta en ny fil for.
///
/// `AVAudioEngine` med forladdade buffertar, inte `AVAudioPlayer` (per fil,
/// hog latens, allokering vid uppspelning). Se spec §7.
@MainActor
final class AudioEngine {
    enum Voice: CaseIterable {
        case flipUp, flipDown, nearMiss, death
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    private var players: [Voice: AVAudioPlayerNode] = [:]
    private var buffers: [Voice: AVAudioPCMBuffer] = [:]
    private var started = false

    func start() {
        guard !started else { return }

        let session = AVAudioSession.sharedInstance()
        // .ambient + mixWithOthers: spelet tystar aldrig anvandarens musik.
        // Ratt for ett pick-up-spel. ~5 ms IO-buffert ger ~10-20 ms latens till
        // inbyggd hogtalare; Bluetooth lagger till 40-70 ms, vilket ar skalet
        // att ljud aldrig far vara en timingreferens. Se spec §7.
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(0.005)
        try? session.setActive(true)

        for voice in Voice.allCases {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players[voice] = player
            buffers[voice] = render(voice)
        }

        engine.prepare()
        guard (try? engine.start()) != nil else { return }
        players.values.forEach { $0.play() }
        started = true
    }

    func play(_ voice: Voice) {
        guard started, let player = players[voice], let buffer = buffers[voice] else { return }
        // .interrupts: en ny flipp ska klippa den forra, inte koas bakom den.
        // Vid 8 tap/s och 45 ms ljud skulle en ko slapa efter direkt.
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: - Syntes

    private func render(_ voice: Voice) -> AVAudioPCMBuffer {
        switch voice {
        case .flipUp:
            tone(duration: 0.045, from: 520, to: 880, gain: 0.22, curve: 18)
        case .flipDown:
            tone(duration: 0.045, from: 440, to: 260, gain: 0.22, curve: 18)
        case .nearMiss:
            tone(duration: 0.030, from: 1900, to: 1900, gain: 0.10, curve: 60)
        case .death:
            tone(duration: 0.220, from: 300, to: 70, gain: 0.30, curve: 9, noise: 0.35)
        }
    }

    private func tone(
        duration: Double,
        from startFreq: Double,
        to endFreq: Double,
        gain: Double,
        curve: Double,
        noise: Double = 0
    ) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        var phase = 0.0
        var rng: UInt64 = 0x2545_F491_4F6C_DD1D

        for i in 0..<Int(frames) {
            let t = Double(i) / Double(frames)
            let freq = startFreq + (endFreq - startFreq) * t
            phase += 2 * Double.pi * freq / sampleRate

            // Exponentiell avklingning — perkussivt, inte utdraget.
            let envelope = exp(-curve * t)

            var sample = sin(phase)
            if noise > 0 {
                rng ^= rng << 13
                rng ^= rng >> 7
                rng ^= rng << 17
                let white = Double(Int64(bitPattern: rng)) / Double(Int64.max)
                sample = sample * (1 - noise) + white * noise
            }

            channel[i] = Float(sample * envelope * gain)
        }
        return buffer
    }
}
