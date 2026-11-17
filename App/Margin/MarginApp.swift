import SwiftUI

@main
struct MarginApp: App {
    @State private var library: LibraryModel
    @State private var lock = AppLock()
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @AppStorage("onboarded") private var onboarded = false

    init() {
        let library = LibraryModel()
        _library = State(initialValue: library)
        QuickCaptureController.shared.library = library
        Notifier.shared.library = library
        GlobalHotkey.shared.action = { QuickCaptureController.shared.toggle() }
        GlobalHotkey.shared.register(KeyCombo.saved)
        if let snap = Snapshot.request {
            DispatchQueue.main.async { Snapshot.run(library: library, to: snap.url, after: snap.delay) }
        } else {
            Notifier.shared.setUp()
        }
    }

    var body: some Scene {
        Window("Anthology", id: "library") {
            LibraryView()
                .environment(library)
                .environment(lock)
                .frame(minWidth: 900, minHeight: 560)
                .tint(Color(palette: Palette.accent))
                .overlay { if lock.isLocked { LockView(lock: lock).transition(.opacity) } }
                .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
                .sheet(isPresented: Binding(get: { !onboarded && !lock.isLocked && Snapshot.request == nil }, set: { if !$0 { onboarded = true } })) {
                    OnboardingView().environment(lock)
                }
                .preferredColorScheme(appearance.colorScheme)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Note") { if let t = library.selectedTopicID { library.createNote(in: t) } }
                    .keyboardShortcut("n")
                Button("Quick Note") { QuickCaptureController.shared.show() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .textEditing) {
                Button("Search Notes") { library.showSearch.toggle() }
                    .keyboardShortcut("k")
            }
            CommandGroup(replacing: .help) {
                Button("Welcome Tour") { onboarded = false }
            }
            CommandGroup(after: .appSettings) {
                Button("Lock Anthology") { lock.lockNow() }
                    .keyboardShortcut("l", modifiers: [.command, .control])
                    .disabled(!lock.isEnabled)
            }
        }

        MenuBarExtra("Anthology", systemImage: "text.append") {
            Group {
                if lock.isLocked {
                    VStack(spacing: 10) {
                        Text("Anthology is locked").font(.system(size: 13, weight: .medium))
                        Button("Unlock") { lock.unlock() }
                    }
                    .padding(20).frame(width: 240)
                } else {
                    MenuBarView().environment(library)
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(library).environment(lock).preferredColorScheme(appearance.colorScheme)
        }
    }
}
