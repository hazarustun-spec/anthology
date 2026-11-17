import AppKit
import SwiftUI

/// "See-through" Mac window: the desktop and windows behind Anthology show through, blurred,
/// with a faint ambient tint so the app keeps its colour and text stays legible.
enum WindowLook {
    static let transparentKey = "transparentWindow"
}

/// Behind-window blur (what Finder's sidebar uses), filling the whole window.
struct BehindWindowBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) { view.material = material }
}

/// Makes the hosting window non-opaque so the behind-window blur can show the desktop.
struct WindowConfigurator: NSViewRepresentable {
    var transparent: Bool

    func makeNSView(context: Context) -> ConfiguratorView { ConfiguratorView() }

    func updateNSView(_ view: ConfiguratorView, context: Context) {
        view.transparent = transparent
        view.apply()
    }

    final class ConfiguratorView: NSView {
        var transparent = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }
        func apply() {
            guard let window else { return }
            // Always clear: the backdrop view (opaque ambient or see-through blur) paints the window.
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }
}

/// The window backdrop: transparent (desktop blur + faint ambient tint) or the opaque ambient mesh.
struct WindowBackdrop: View {
    @AppStorage(WindowLook.transparentKey) private var transparent = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if transparent && !reduceTransparency {
            BehindWindowBlur()
        } else {
            Color(palette: Palette.canvas)
        }
    }
}
