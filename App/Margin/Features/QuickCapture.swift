import AppKit
import MarginCore
import SwiftUI

/// Floating Spotlight-style panel: type a note, pick a topic, press Return.
@MainActor
final class QuickCaptureController {
    static let shared = QuickCaptureController()
    private var panel: NSPanel?
    weak var library: LibraryModel?

    func toggle() {
        if let panel, panel.isVisible { close(); return }
        show()
    }

    func show() {
        guard let library else { return }
        let panel = self.panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: QuickCaptureView(library: library) { [weak self] in self?.close() })
        panel.center()
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY + 140))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
        self.panel = panel
    }

    func close() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; panel.animator().alphaValue = 0 }) {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 172),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        return panel
    }
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { QuickCaptureController.shared.close() }
}

struct QuickCaptureView: View {
    let library: LibraryModel
    let dismiss: () -> Void
    @State private var text = ""
    @State private var topicID: String?
    @State private var saved = false
    @FocusState private var focused: Bool
    @AppStorage("quickCaptureTopic") private var lastTopic = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: saved ? "checkmark.circle.fill" : "text.append")
                    .foregroundStyle(Color(palette: Palette.accent))
                    .contentTransition(.symbolEffect(.replace))
                Text(saved ? "Saved" : "Quick note").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $topicID) {
                    ForEach(library.topics) { t in Text(t.title).tag(Optional(t.id)) }
                }
                .labelsHidden().frame(width: 180)
            }
            TextField("Write a note… (Return to save, ⇧Return for a new line)", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .lineLimit(1...4)
                .focused($focused)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) { return .ignored }
                    save()
                    return .handled
                }
            Text("\(library.topics.first { $0.id == topicID }?.title ?? "") › \(MarginTools.quickNoteTitle)")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 560)
        .background(Color(palette: Palette.card))
        .onAppear {
            topicID = library.topics.first { $0.id == lastTopic }?.id ?? library.selectedTopicID ?? library.topics.first?.id
            focused = true
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { dismiss(); return }
        let topic = topicID ?? library.ensureInbox()
        guard let topic else { return }
        lastTopic = topic
        library.quickCapture(trimmed, topicID: topic)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        withAnimation(.spring(duration: 0.3)) { saved = true }
        Task { try? await Task.sleep(for: .milliseconds(450)); dismiss() }
    }
}
