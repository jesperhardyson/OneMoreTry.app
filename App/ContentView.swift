import OMTCore
import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()
    @State private var showDebug = false

    var body: some View {
        ZStack {
            Color(white: 0.07).ignoresSafeArea()

            Canvas(rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size)
            }
            .ignoresSafeArea()

            GameHost(
                onFrame: { model.frame(at: $0) },
                onTap: { model.tap(atUptime: $0) }
            )
            .ignoresSafeArea()

            hud
            if showDebug { debugPanel }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Rendering

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let t = model.tuning
        let scale = size.height * 0.78 / t.channelHeight
        let originY = (size.height - t.channelHeight * scale) / 2
        let lookBehind = size.width * 0.28
        let camX = model.state.x - lookBehind / scale

        func point(_ wx: Double, _ wy: Double) -> CGPoint {
            CGPoint(
                x: (wx - camX) * scale,
                y: originY + (t.channelHeight - wy) * scale
            )
        }

        func rect(x: Double, y: Double, w: Double, h: Double) -> CGRect {
            let topLeft = point(x, y + h)
            return CGRect(x: topLeft.x, y: topLeft.y, width: w * scale, height: h * scale)
        }

        // Kanalen
        context.fill(
            Path(rect(x: camX, y: 0, w: size.width / scale, h: t.channelHeight)),
            with: .color(Color(white: 0.13))
        )

        // Ytorna
        let surfaceThickness = t.channelHeight * 0.02
        for y in [0.0, t.channelHeight - surfaceThickness] {
            context.fill(
                Path(rect(x: camX, y: y, w: size.width / scale, h: surfaceThickness)),
                with: .color(Color(white: 0.30))
            )
        }

        // Hinder
        for obstacle in model.obstacles {
            let y = obstacle.surface == .floor ? 0 : t.channelHeight - obstacle.height
            context.fill(
                Path(rect(x: obstacle.x, y: y, w: obstacle.width, h: obstacle.height)),
                with: .color(Color(red: 0.85, green: 0.24, blue: 0.33))
            )
        }

        // Figuren
        let body = rect(
            x: model.state.x - t.characterWidth / 2,
            y: model.state.y - t.characterHeight / 2,
            w: t.characterWidth,
            h: t.characterHeight
        )
        context.fill(
            Path(body),
            with: .color(model.state.alive
                ? Color(red: 0.36, green: 0.85, blue: 0.72)
                : Color(white: 0.45))
        )
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
                slider("flipp-avtryck", $model.tuning.flipFootprint, 0.6...3.0)
                slider("flipDuration", $model.tuning.flipDuration, 0.10...0.40)
                slider("svårighet", $model.difficulty, 0...1)
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
        _ range: ClosedRange<Double>
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
