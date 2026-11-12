import MarginCore
import SwiftUI

struct TopicList: View {
    @Environment(LibraryModel.self) private var library
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            Section("Topics") {
                ForEach(library.topics) { topic in
                    let notes = library.notes(for: topic.id)
                    let fresh = notes.contains { library.isRecentlyChanged($0.meta.id) }
                    Label {
                        HStack {
                            Text(topic.title)
                            Spacer()
                            if fresh {
                                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text("\(notes.count)").foregroundStyle(.tertiary).monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: "folder")
                    }
                    .tag(topic.id)
                }
            }
        }
        .animation(.spring(duration: 0.35), value: library.recentlyChanged)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .overlay {
            if library.topics.isEmpty {
                EmptyState(symbol: "sparkles", text: "Ask Claude to save something to Margin")
            }
        }
    }
}
