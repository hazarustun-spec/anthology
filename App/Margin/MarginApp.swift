import SwiftUI

@main
struct MarginApp: App {
    @State private var library: LibraryModel
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system

    init() {
        let library = LibraryModel()
        _library = State(initialValue: library)
        if let snap = Snapshot.request {
            DispatchQueue.main.async { Snapshot.run(library: library, to: snap.url, after: snap.delay) }
        }
    }

    var body: some Scene {
        Window("Margin", id: "library") {
            LibraryView()
                .environment(library)
                .frame(minWidth: 900, minHeight: 560)
                .preferredColorScheme(appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Note") { if let t = library.selectedTopicID { library.createNote(in: t) } }
                    .keyboardShortcut("n")
            }
        }

        MenuBarExtra("Margin", systemImage: "text.append") {
            MenuBarView().environment(library).preferredColorScheme(appearance.colorScheme)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(library).preferredColorScheme(appearance.colorScheme)
        }
    }
}
