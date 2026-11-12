import LocalAuthentication
import SwiftUI

@main
struct MarginMobileApp: App {
    @State private var library = LibraryModel()
    @State private var lock = MobileLock()
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(lock)
                .tint(Color(palette: Palette.accent))
                .preferredColorScheme(appearance.colorScheme)
                .overlay { if lock.isLocked { MobileLockView().environment(lock).transition(.opacity) } }
                .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
                .onChange(of: phase) { _, new in lock.scenePhaseChanged(new) }
        }
    }
}

/// Face ID / passcode lock, mirrors the Mac setting key so behaviour matches.
@MainActor @Observable
final class MobileLock {
    var isLocked = UserDefaults.standard.bool(forKey: "lockEnabled")
    private var backgroundedAt: Date?
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: "lockEnabled") }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background: backgroundedAt = Date()
        case .active:
            let minutes = UserDefaults.standard.object(forKey: "lockAfterMinutes") as? Int ?? 5
            if isEnabled, let at = backgroundedAt, Date().timeIntervalSince(at) > Double(minutes * 60) { isLocked = true }
            backgroundedAt = nil
        default: break
        }
    }

    func unlock() {
        LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "unlock your notes")) { ok, _ in
            Task { @MainActor in if ok { self.isLocked = false; Haptics.success() } }
        }
    }

    func setEnabled(_ on: Bool, done: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard on else { UserDefaults.standard.set(false, forKey: "lockEnabled"); done(true); return }
        LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "turn on the lock")) { ok, _ in
            Task { @MainActor in
                if ok { UserDefaults.standard.set(true, forKey: "lockEnabled") }
                done(ok)
            }
        }
    }
}

struct MobileLockView: View {
    @Environment(MobileLock.self) private var lock
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "faceid").font(.system(size: 52, weight: .light)).foregroundStyle(Color(palette: Palette.accent))
                .symbolEffect(.pulse, options: .repeating)
            Text("Margin is locked").font(.title3.weight(.semibold))
            Button("Unlock") { lock.unlock() }.buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { lock.unlock() }
    }
}
