import SwiftUI

/// "Ambient glass" backdrop (Hazar's pick, direction A): a soft sage / amber / sky mesh that
/// Liquid Glass surfaces refract. Drifts very slowly; still when Reduce Motion is on.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Color(palette: Palette.canvas)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                MeshGradient(width: 3, height: 3, points: points(t), colors: colors)
                    .overlay(scheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.0))
            }
        }
    }

    private func points(_ t: Double) -> [SIMD2<Float>] {
        func w(_ speed: Double, _ phase: Double, _ amp: Float = 0.06) -> Float { Float(sin(t * speed + phase)) * amp }
        return [
            [0, 0], [0.5 + w(0.07, 0), 0], [1, 0],
            [0, 0.5 + w(0.05, 1)], [0.5 + w(0.06, 2), 0.5 + w(0.08, 3)], [1, 0.5 + w(0.05, 4)],
            [0, 1], [0.5 + w(0.07, 5), 1], [1, 1],
        ]
    }

    private var colors: [Color] {
        func c(_ hex: UInt32) -> Color { Color(palette: PlatformColor(hex: hex)) }
        if scheme == .dark {
            return [c(0x1E4A35), c(0x0F1A14), c(0x13324A),
                    c(0x10201A), c(0x2A5A3F), c(0x0E1713),
                    c(0x4A3812), c(0x12241C), c(0x1B3D2C)]
        }
        return [c(0x93C28C), c(0xDCEAD6), c(0x9CC6DA),
                c(0xD2E6CB), c(0xB4D7AA), c(0xF3EBD6),
                c(0xEDC27A), c(0xD9EAD2), c(0xA9D0A0)]
    }
}

extension View {
    /// A content panel floating on the ambient backdrop: Liquid Glass with a light fill for legibility.
    func glassPanel(cornerRadius: CGFloat = 22, fill: Double = 0.55, tint: Color? = nil) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color(palette: Palette.card).opacity(fill)))
            .glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: .rect(cornerRadius: cornerRadius))
    }
}
