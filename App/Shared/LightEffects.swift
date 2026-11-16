import SwiftUI
#if os(iOS)
import CoreMotion
#endif

/// Where the "light" sits for glass highlights. On iPhone it follows device tilt; on Mac each panel
/// follows the pointer while hovered and rests at the top-left otherwise.
@MainActor @Observable
final class LightSource {
    static let shared = LightSource()
    /// Unit point of the light in panel space (0,0 top-left … 1,1 bottom-right).
    var point = UnitPoint(x: 0.2, y: 0.0)

    #if os(iOS)
    private let motion = CMMotionManager()
    func startTilt() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let g = data?.gravity else { return }
            // Tilting the phone moves the highlight across the glass.
            let x = min(max(0.5 + g.x * 0.9, -0.2), 1.2)
            let y = min(max(0.15 + (g.y + 0.6) * 0.9, -0.2), 1.2)
            MainActor.assumeIsolated { self?.point = UnitPoint(x: x, y: y) }
        }
    }
    #endif
}

/// Light position for a panel: pointer while hovered (Mac), else the shared light (tilt on iPhone).
@MainActor private enum LightPoint {
    static func resolve(hover: UnitPoint?, reduceMotion: Bool) -> UnitPoint {
        reduceMotion ? UnitPoint(x: 0.2, y: 0) : (hover ?? LightSource.shared.point)
    }
}

/// Broad sheen where light hits the glass; sits under the content.
struct SpecularSheen<S: InsettableShape>: View {
    let shape: S
    var hover: UnitPoint?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let p = LightPoint.resolve(hover: hover, reduceMotion: reduceMotion)
            let dark = scheme == .dark
            shape.fill(
                RadialGradient(
                    colors: [.white.opacity(dark ? 0.20 : 0.65), .white.opacity(0)],
                    center: p, startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.7)
            )
            .blendMode(dark ? .plusLighter : .softLight)
            .animation(.spring(duration: 0.5), value: hover)
        }
        .allowsHitTesting(false)
    }
}

/// Bright rim nearest the light plus a thin inner caustic; drawn on top, but only at the edges.
struct SpecularRim<S: InsettableShape>: View {
    let shape: S
    var hover: UnitPoint?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let p = LightPoint.resolve(hover: hover, reduceMotion: reduceMotion)
        let opposite = UnitPoint(x: 1 - p.x, y: 1 - p.y)
        let dark = scheme == .dark
        ZStack {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(dark ? 0.6 : 1), .white.opacity(0.06), .white.opacity(dark ? 0.2 : 0.45)],
                               startPoint: p, endPoint: opposite),
                lineWidth: 1.3)
            shape.inset(by: 2.5).strokeBorder(
                LinearGradient(colors: [.white.opacity(dark ? 0.28 : 0.6), .clear], startPoint: p, endPoint: .center),
                lineWidth: 0.8)
        }
        .animation(.spring(duration: 0.5), value: hover)
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
