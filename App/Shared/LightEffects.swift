import SwiftUI

/// Thin static glass edge: a little brighter at the top, so panels read as glass without any glare.
struct GlassRim<S: InsettableShape>: View {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        shape.strokeBorder(
            LinearGradient(colors: [.white.opacity(dark ? 0.28 : 0.75), .white.opacity(dark ? 0.08 : 0.25)],
                           startPoint: .top, endPoint: .bottom),
            lineWidth: 1)
            .allowsHitTesting(false)
    }
}

/// Soft drifting light spots on the backdrop, so glass edges have something to bend.
struct Caustics: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let dark = scheme == .dark
                let spots: [(Double, Double, Double, Double, Color)] = [
                    (0.18, 0.22, 0.30, 0.11, .white),
                    (0.72, 0.18, 0.22, 0.07, dark ? Color(red: 0.55, green: 0.8, blue: 0.6) : .white),
                    (0.55, 0.62, 0.34, 0.05, dark ? Color(red: 0.9, green: 0.7, blue: 0.35) : Color(red: 1, green: 0.93, blue: 0.75)),
                    (0.12, 0.82, 0.26, 0.09, dark ? Color(red: 0.4, green: 0.65, blue: 0.85) : .white),
                    (0.88, 0.78, 0.20, 0.06, .white),
                ]
                ForEach(spots.indices, id: \.self) { i in
                    let s = spots[i]
                    let x = (s.0 + sin(t * s.3 + Double(i) * 1.7) * 0.08) * w
                    let y = (s.1 + cos(t * s.3 * 0.8 + Double(i)) * 0.07) * h
                    let size = s.2 * max(w, h) * (dark ? 1 : 0.7)
                    Ellipse()
                        .fill(s.4.opacity(dark ? 0.16 : 0.32))
                        .frame(width: size, height: size * 0.7)
                        .rotationEffect(.degrees(sin(t * 0.05 + Double(i)) * 25))
                        .position(x: x, y: y)
                        .blur(radius: size * 0.12)
                }
            }
        }
        .blendMode(scheme == .dark ? .plusLighter : .normal)
        .allowsHitTesting(false)
    }
}

/// Sun / moon glass button that flips between light and dark (Settings still offers "Match system").
struct AppearanceToggle: View {
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            appearance = scheme == .dark ? .light : .dark
            Haptics.select()
        } label: {
            Label(scheme == .dark ? "Light Mode" : "Dark Mode",
                  systemImage: scheme == .dark ? "sun.max.fill" : "moon.fill")
                .contentTransition(.symbolEffect(.replace.downUp))
        }
        .help(scheme == .dark ? "Switch to light mode" : "Switch to dark mode")
    }
}
