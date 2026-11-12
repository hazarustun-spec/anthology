import AppKit
import LocalAuthentication
import Observation

/// Optional Touch ID / password lock. Locks on launch and after the app has been in the background a while.
@MainActor @Observable
final class AppLock {
    static let enabledKey = "lockEnabled"
    static let timeoutKey = "lockAfterMinutes"

    private(set) var isLocked: Bool
    private(set) var failed = false
    private var resignedAt: Date?

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var timeoutMinutes: Int { UserDefaults.standard.object(forKey: Self.timeoutKey) as? Int ?? 5 }

    init() {
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey)
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resignedAt = Date() }
        }
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkTimeout() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockNow() }
        }
    }

    static var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    func lockNow() { if isEnabled { isLocked = true } }

    private func checkTimeout() {
        guard isEnabled, let resignedAt else { return }
        if Date().timeIntervalSince(resignedAt) > Double(timeoutMinutes * 60) { isLocked = true }
        self.resignedAt = nil
    }

    func unlock() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = String(localized: "Use Password")
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "unlock your notes")) { ok, _ in
            Task { @MainActor in
                self.failed = !ok
                if ok { self.isLocked = false }
            }
        }
    }

    /// Turning the lock on requires proving it works first.
    func setEnabled(_ on: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard on else {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            isLocked = false
            completion(true)
            return
        }
        LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "turn on the lock")) { ok, _ in
            Task { @MainActor in
                if ok { UserDefaults.standard.set(true, forKey: Self.enabledKey) }
                completion(ok)
            }
        }
    }
}
