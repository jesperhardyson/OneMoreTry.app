import SwiftUI
import UIKit

/// Varden for speltappet och frame-loopen.
///
/// Bade `CADisplayLink.timestamp` och `UITouch.timestamp` ar uptime-baserade och
/// delar klockbas. SwiftUI:s `DragGesture.Value.time` ar en `Date` — vaggklocka,
/// fel bas — och far darfor inte anvandas for speltappet. Se CLAUDE.md.
struct GameHost: UIViewRepresentable {
    let onFrame: (CFTimeInterval) -> Void
    let onTap: (CFTimeInterval) -> Void

    func makeUIView(context: Context) -> GameHostUIView {
        let view = GameHostUIView()
        view.onFrame = onFrame
        view.onTap = onTap
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        return view
    }

    func updateUIView(_ view: GameHostUIView, context: Context) {
        view.onFrame = onFrame
        view.onTap = onTap
    }
}

final class GameHostUIView: UIView {
    var onFrame: ((CFTimeInterval) -> Void)?
    var onTap: ((CFTimeInterval) -> Void)?

    private var link: CADisplayLink?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        link?.invalidate()
        link = nil

        guard let scene = window?.windowScene else { return }
        let fps = Float(scene.screen.maximumFramesPerSecond)

        let displayLink = CADisplayLink(target: self, selector: #selector(handleFrame(_:)))
        // Las bildfrekvensen: min == max. Ett intervall ger variabel takt, och da
        // emitterar ackumulatorn 2,3,2,3 steg per frame vilket lases som stutter.
        displayLink.preferredFrameRateRange =
            CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    @objc private func handleFrame(_ link: CADisplayLink) {
        MainActor.assumeIsolated { onFrame?(link.timestamp) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        onTap?(touch.timestamp)
    }
}
