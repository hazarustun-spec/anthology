import SwiftUI

@main
struct MarginApp: App {
    @State private var library = LibraryModel()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    if let snap = Snapshot.request { Snapshot.run(library: library, to: snap.url, after: snap.delay) }
                }
        }
        .windowToolbarStyle(.unified)
    }
}
