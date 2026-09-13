import OMTCore
import SwiftUI

/// Lagets palett. Bytet maste bara pa figurens utseende, paletten *och* ljudets
/// tonhojd samtidigt — ett av tre racker inte, for lagesforvirring ar portalens
/// enda allvarliga risk. Se docs/decision-log.md 2026-09-13, fjarde passet.
private struct Palette {
    var channel: Color
    var surface: Color
    var character: Color
    var portal: Color

    static let gravityFlip = Palette(
        channel: Color(white: 0.13),
        surface: Color(white: 0.30),
        character: Color(red: 0.36, green: 0.85, blue: 0.72),
        portal: Color(red: 0.42, green: 0.68, blue: 0.98),
    )

    static let impulse = Palette(
        channel: Color(red: 0.16, green: 0.12, blue: 0.19),
        surface: Color(red: 0.38, green: 0.31, blue: 0.35),
        character: Color(red: 0.98, green: 0.72, blue: 0.32),
        portal: Color(red: 0.80, green: 0.44, blue: 0.95),
    )

    static func `for`(_ mode: ControlMode) -> Palette {
        mode == .impulse ? .impulse : .gravityFlip
    }
}

/// Fara byter aldrig farg med laget. Paletten bar vilket lage som ar aktivt, och
/// om hindren fargades om skulle spelaren behova omtolka "rott" vid varje portal.
private let dangerColor = Color(red: 0.85, green: 0.24, blue: 0.33)

struct ContentView: View {
    @State private var model = GameModel()
    @State private var showDebug = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()

            Canvas(rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size)
            }
            .ignoresSafeArea()

            GameHost(
                onFrame: { model.frame(at: $0) },
                onTap: { model.tap(atUptime: $0) },
                onRelease: { model.release(atUptime: $0) },
            )
            .ignoresSafeArea()

            hud
            if showDebug {
                debugPanel
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.feedback.start() }
    }

    // MARK: - Rendering

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let t = model.tuning
        let palette = Palette.for(model.state.mode)
        let scale = size.height * 0.78 / t.channelHeight
        let originY = (size.height - t.channelHeight * scale) / 2
        let lookBehind = size.width * 0.28
        let camX = model.state.x - lookBehind / scale

        func point(_ wx: Double, _ wy: Double) -> CGPoint {
            CGPoint(
                x: (wx - camX) * scale,
                y: originY + (t.channelHeight - wy) * scale,
            )
        }

        func rect(x: Double, y: Double, w: Double, h: Double) -> CGRect {
            let topLeft = point(x, y + h)
            return CGRect(x: topLeft.x, y: topLeft.y, width: w * scale, height: h * scale)
        }

        // Kanalen
        context.fill(
            Path(rect(x: camX, y: 0, w: size.width / scale, h: t.channelHeight)),
            with: .color(palette.channel),
        )

        // Ytorna
        let surfaceThickness = t.channelHeight * 0.02
        for y in [0.0, t.channelHeight - surfaceThickness] {
            context.fill(
                Path(rect(x: camX, y: y, w: size.width / scale, h: surfaceThickness)),
                with: .color(palette.surface),
            )
        }

        // Portaler. Ritas fore hindren: en portal ar bakgrund, aldrig nagot man
        // kan krocka med, och far inte kunna forvaxlas med geometri.
        for portal in model.portals {
            drawPortal(portal, in: &context, tuning: t, scale: scale, rect: rect, point: point)
        }

        // Hinder
        for obstacle in model.obstacles {
            let y = obstacle.surface == .floor ? 0 : t.channelHeight - obstacle.height
            context.fill(
                Path(rect(x: obstacle.x, y: y, w: obstacle.width, h: obstacle.height)),
                with: .color(dangerColor),
            )
        }

        // Figuren
        let body = rect(
            x: model.state.x - t.characterWidth / 2,
            y: model.state.y - t.characterHeight / 2,
            w: t.characterWidth,
            h: t.characterHeight,
        )
        context.fill(
            Path(body),
            with: .color(model.state.alive ? palette.character : Color(white: 0.45)),
        )

        // Bekraftelse pa att *du* bytte lage, i ~0,15 s. Lokal och lagkontrast
        // istallet for en helskarmsblixt: karnloopen ar snabb dod och omstart
        // vid 120 Hz, vilket redan ar en anfallsriskprofil. Se CLAUDE.md.
        if !reduceMotion,
           let changed = model.feedback.lastModeChangeStep,
           model.state.step >= changed,
           model.state.step - changed < 36 {
            let age = Double(model.state.step - changed) / 36
            context.stroke(
                Path(body.insetBy(dx: -2 * scale, dy: -2 * scale)),
                with: .color(palette.character.opacity(0.55 * (1 - age))),
                lineWidth: 0.45 * scale,
            )
        }
    }

    /// Portalen bars av *form*, inte bara farg: uppatriktade sparrar betyder
    /// "ett tap kastar dig uppat", dubbelriktade betyder "ett tap vander vart
    /// nedat ar". Aven en spelare som inte skiljer paletterna las bytet.
    private func drawPortal(
        _ portal: Portal,
        in context: inout GraphicsContext,
        tuning t: Tuning,
        scale: Double,
        rect: (Double, Double, Double, Double) -> CGRect,
        point: (Double, Double) -> CGPoint,
    ) {
        let palette = Palette.for(portal.mode)
        let bandWidth = 16.0

        context.fill(
            Path(rect(portal.x - bandWidth / 2, 0, bandWidth, t.channelHeight)),
            with: .color(palette.portal.opacity(0.22)),
        )
        for x in [portal.x - bandWidth / 2, portal.x + bandWidth / 2 - 1.5] {
            context.fill(
                Path(rect(x, 0, 1.5, t.channelHeight)),
                with: .color(palette.portal),
            )
        }

        // Fem sparrar jamnt over kanalen. I impulslaget pekar alla uppat; i
        // gravitationslaget varannan uppat och varannan nedat.
        let count = 5
        var glyphs = Path()
        for i in 0 ..< count {
            let cy = t.channelHeight * (Double(i) + 0.5) / Double(count)
            let up = portal.mode == .impulse ? true : i.isMultiple(of: 2)
            let tip = cy + (up ? 5 : -5)
            let base = cy + (up ? -3 : 3)
            glyphs.move(to: point(portal.x - 5, base))
            glyphs.addLine(to: point(portal.x, tip))
            glyphs.addLine(to: point(portal.x + 5, base))
        }
        context.stroke(glyphs, with: .color(palette.portal), lineWidth: 0.5 * scale)
    }

    // MARK: - HUD

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(model.state.x)) m")
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                    Text("bäst \(Int(model.bestDistance))")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    // Aktivt lage i text ar en trimhjalp, inte en spelfunktion.
                    // Bar bytet inte pa figur, palett och ljud ensamt sa ar det
                    // designen som ar fel, inte HUD:en som saknar en etikett.
                    Text(model.state.mode == .impulse ? "impuls" : "vänd tecken")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.for(model.state.mode).character)
                }
                Spacer()
                Button(showDebug ? "dölj" : "trim") { showDebug.toggle() }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer()

            if !model.state.alive {
                Text("TAP")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, 28)
            }
        }
        .allowsHitTesting(showDebug || !model.state.alive)
        .foregroundStyle(.white)
    }

    private var debugPanel: some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                Picker("", selection: $model.tuning.mode) {
                    Text("vänd tecken").tag(ControlMode.gravityFlip)
                    Text("impuls").tag(ControlMode.impulse)
                }
                .pickerStyle(.segmented)

                // Bindningen ar `tuning.mode`, alltsa *startlaget*. Det aktiva
                // laget bor i `SimState` och byts av portaler, sa valet slar
                // igenom forst vid nasta omstart.
                Toggle(isOn: $model.portalsEnabled) {
                    Text("portaler").font(.system(size: 11, design: .monospaced))
                }
                .toggleStyle(.switch)
                if model.portalsEnabled {
                    slider("portalperiod", $model.portalPeriod, 1.5 ... 12)
                }
                if model.state.mode == .impulse || model.portalsEnabled {
                    slider("impulsstyrka", $model.tuning.impulseFraction, 0.25 ... 0.9)
                    slider("hoppkapning", $model.tuning.impulseCutFraction, 0.05 ... 1.0)
                }
                slider("flipp-avtryck", $model.tuning.flipFootprint, 0.6 ... 3.0)
                slider("flipDuration", $model.tuning.flipDuration, 0.10 ... 0.40)
                slider("svårighet", $model.difficulty, 0 ... 1)
                HStack {
                    Text("hastighet \(Int(model.tuning.scrollSpeed))")
                    Spacer()
                    Text("\(Int(model.frameRate)) fps")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.black.opacity(0.75), in: .rect(cornerRadius: 12))
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
    }

    private func slider(
        _ label: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 92, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 42, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}
