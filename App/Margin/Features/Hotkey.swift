import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A key combination stored in UserDefaults ("keyCode:carbonModifiers").
struct KeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier flags

    static let `default` = KeyCombo(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | optionKey))
    static let defaultsKey = "quickCaptureHotkey"

    static var saved: KeyCombo? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return .default }
            if raw == "off" { return nil }
            let parts = raw.split(separator: ":").compactMap { UInt32($0) }
            return parts.count == 2 ? KeyCombo(keyCode: parts[0], modifiers: parts[1]) : .default
        }
        set { UserDefaults.standard.set(newValue.map { "\($0.keyCode):\($0.modifiers)" } ?? "off", forKey: defaultsKey) }
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        var m: UInt32 = 0
        if event.modifierFlags.contains(.command) { m |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { m |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { m |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { m |= UInt32(shiftKey) }
        // Require at least one of ⌘ ⌥ ⌃ so plain typing never triggers it.
        guard m & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: m)
    }

    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    static func keyName(_ code: UInt32) -> String {
        let special: [Int: String] = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋"]
        if let s = special[Int(code)] { return s }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let layout = unsafeBitCast(ptr, to: CFData.self)
        var dead: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var len = 0
        let data = CFDataGetBytePtr(layout)!
        data.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { kl in
            _ = UCKeyTranslate(kl, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &len, &chars)
        }
        return String(utf16CodeUnits: chars, count: len).uppercased()
    }
}

/// Registers one global hotkey with Carbon (works without Accessibility permission).
@MainActor
final class GlobalHotkey {
    static let shared = GlobalHotkey()
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    func register(_ combo: KeyCombo?) {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        guard let combo else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotkey.shared.action?() } }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x4D52474E), id: 1) // 'MRGN'
        RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }
}

/// Click, then press the new combination. Esc cancels, Delete turns it off.
struct HotkeyRecorder: View {
    @State private var combo = KeyCombo.saved
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? String(localized: "Press keys…") : (combo?.display ?? String(localized: "Off")))
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(minWidth: 90)
        }
        .buttonStyle(.bordered)
        .tint(recording ? Color(palette: Palette.accent) : nil)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            if event.keyCode == UInt16(kVK_Delete) { save(nil); return nil }
            if let new = KeyCombo(event: event) { save(new) }
            return nil
        }
    }

    private func save(_ new: KeyCombo?) {
        combo = new
        KeyCombo.saved = new
        GlobalHotkey.shared.register(new)
        stop()
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
