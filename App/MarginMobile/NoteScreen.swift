import MarginCore
import SwiftUI
import UIKit

/// UITextView on a TextKit 1 stack so the shared layout manager can draw checkboxes and bullets.
final class MobileMarkdownTextView: UITextView {
    var onToggle: (() -> Void)?

    @objc func handleTap(_ g: UITapGestureRecognizer) {
        let point = g.location(in: self)
        guard let pos = closestPosition(to: point) else { return }
        let index = offset(from: beginningOfDocument, to: pos)
        let text = self.text as NSString
        for candidate in [index, index - 1] where candidate >= 0 {
            if let r = MarkdownStyler.checkboxToggleRange(in: text, at: candidate) {
                let next = text.substring(with: r) == " " ? "x" : " "
                textStorage.replaceCharacters(in: r, with: next)
                delegate?.textViewDidChange?(self)
                Haptics.tap()
                onToggle?()
                return
            }
        }
    }
}

struct MobileNoteEditor: UIViewRepresentable {
    @Binding var text: String
    var freshLines: Set<String>
    var onEdit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MobileMarkdownTextView {
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let view = MobileMarkdownTextView(frame: .zero, textContainer: container)
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 120, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.tintColor = Palette.accent
        view.autocorrectionType = .default
        view.smartQuotesType = .no
        view.smartDashesType = .no
        context.coordinator.styler.bodyFont = .systemFont(ofSize: 17)
        storage.delegate = context.coordinator.styler
        view.typingAttributes = context.coordinator.styler.baseAttributes
        view.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: view, action: #selector(MobileMarkdownTextView.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.load(text, fresh: freshLines)
        return view
    }

    func updateUIView(_ view: MobileMarkdownTextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text || context.coordinator.styler.freshLines != freshLines {
            context.coordinator.load(text, fresh: freshLines)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: MobileNoteEditor
        let styler = MarkdownStyler()
        weak var view: MobileMarkdownTextView?
        private var loading = false

        init(_ parent: MobileNoteEditor) { self.parent = parent }

        func load(_ text: String, fresh: Set<String>) {
            guard let view else { return }
            loading = true
            let selection = view.selectedRange
            styler.freshLines = fresh
            if view.text != text {
                view.textStorage.replaceCharacters(in: NSRange(location: 0, length: view.textStorage.length), with: text)
            }
            styler.styleAll(view.textStorage)
            let length = (text as NSString).length
            view.selectedRange = NSRange(location: min(selection.location, length), length: 0)
            loading = false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !loading else { return }
            parent.text = textView.text
            parent.onEdit()
        }

        /// Only take the tap when it lands on a checkbox; otherwise let UITextView place the caret.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let view, let pos = view.closestPosition(to: g.location(in: view)) else { return false }
            let index = view.offset(from: view.beginningOfDocument, to: pos)
            let text = view.text as NSString
            return [index, index - 1].contains { $0 >= 0 && MarkdownStyler.checkboxToggleRange(in: text, at: $0) != nil }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { false }
    }
}

struct NoteScreen: View {
    @Environment(LibraryModel.self) private var library
    let noteID: String

    @State private var text = ""
    @State private var title = ""
    @State private var baseRevision = 0
    @State private var dirty = false
    @State private var saveTask: Task<Void, Never>?
    @State private var conflictRevision: Int?
    @State private var showHistory = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        let note = library.note(noteID)
        VStack(alignment: .leading, spacing: 10) {
            if conflictRevision != nil { banner }
            TextField("Title", text: $title, axis: .vertical)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(palette: Palette.text))
                .focused($titleFocused)
                .onSubmit(commitTitle)
                .onChange(of: titleFocused) { _, f in if !f { commitTitle() } }
            if let last = library.lastChange(for: noteID) {
                Button { showHistory = true } label: { SourceBadge(entry: last) }.buttonStyle(.plain)
            }
            MobileNoteEditor(text: $text, freshLines: library.freshLines[noteID] ?? []) { scheduleSave() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .glassPanel(cornerRadius: 32, fill: 0.42)
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .background(AmbientBackground().ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let note {
                        Button("Copy as Markdown", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = "# \(note.meta.title)\n\n\(text)"
                            Haptics.success()
                        }
                        ShareLink(item: "# \(note.meta.title)\n\n\(text)") { Label("Share", systemImage: "square.and.arrow.up") }
                        Button("History", systemImage: "clock.arrow.circlepath") { showHistory = true }
                    }
                } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryList(entries: library.history(for: noteID), canRestore: { library.hasVersion(noteID: noteID, revision: $0 - 1) }) { rev in
                    library.restore(noteID: noteID, revision: rev - 1)
                    showHistory = false
                    load()
                    Haptics.success()
                }
                .navigationTitle("History").navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear(perform: load)
        .onChange(of: note?.meta.revision) { _, _ in externalChange() }
        .onDisappear(perform: flush)
        .task(id: library.freshLines[noteID]) {
            guard library.freshLines[noteID] != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            library.clearFreshLines(noteID)
        }
    }

    private var banner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Claude updated this note while you were typing.", systemImage: "sparkles").font(.footnote)
            HStack {
                Button("Show Claude's version") { load(); conflictRevision = nil }
                Button("Keep mine") {
                    if let rev = conflictRevision { baseRevision = rev }
                    conflictRevision = nil
                    save()
                }
            }
            .buttonStyle(.glass).font(.footnote)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func load() {
        title = library.note(noteID)?.meta.title ?? ""
        text = library.body(for: noteID)
        baseRevision = library.note(noteID)?.meta.revision ?? 0
        dirty = false
    }

    private func commitTitle() {
        let current = library.note(noteID)?.meta.title ?? ""
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { title = current; return }
        guard trimmed != current else { return }
        flush()
        library.renameNote(noteID, to: trimmed)
        baseRevision = library.note(noteID)?.meta.revision ?? baseRevision
    }

    private func externalChange() {
        guard let rev = library.note(noteID)?.meta.revision, rev != baseRevision else { return }
        if dirty { conflictRevision = rev } else { load(); Haptics.select() }
    }

    private func scheduleSave() {
        dirty = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func flush() {
        guard dirty else { return }
        saveTask?.cancel()
        save()
    }

    private func save() {
        guard conflictRevision == nil else { return }
        switch library.save(noteID: noteID, baseRevision: baseRevision, body: text) {
        case .saved(let rev): baseRevision = rev; dirty = false
        case .stale(let rev): conflictRevision = rev
        case .failed: break
        }
    }
}

struct CaptureSheet: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var topicID: String?
    @AppStorage("quickCaptureTopic") private var lastTopic = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Write a note…", text: $text, axis: .vertical)
                    .font(.title3).lineLimit(3...8).focused($focused)
                Picker("Topic", selection: $topicID) {
                    ForEach(library.topics) { t in Label(t.title, systemImage: t.icon ?? "folder").tag(Optional(t.id)) }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(20)
            .navigationTitle("Quick note").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, let topic = topicID ?? library.ensureInbox() else { return }
                        lastTopic = topic
                        library.quickCapture(trimmed, topicID: topic)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                topicID = library.topics.first { $0.id == lastTopic }?.id ?? library.topics.first?.id
                focused = true
            }
        }
    }
}

struct MobileSettings: View {
    @Environment(LibraryModel.self) private var library
    @Environment(MobileLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @AppStorage("lockAfterMinutes") private var lockAfter = 5
    @State private var lockOn = UserDefaults.standard.bool(forKey: "lockEnabled")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: library.location == .iCloud ? "icloud.fill" : "iphone")
                            .foregroundStyle(Color(palette: Palette.accent))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(library.location == .iCloud ? "Syncing with iCloud" : "Saved on this iPhone only")
                            Text(library.location == .iCloud ? "Signed in with your Apple ID. Notes appear on all your devices." : "Turn on iCloud Drive in Settings to sync with your Mac.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceChoice.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Privacy") {
                    Toggle("Lock with Face ID", isOn: Binding(get: { lockOn }, set: { new in
                        lock.setEnabled(new) { ok in lockOn = ok ? new : lockOn }
                    }))
                    if lockOn {
                        Picker("Lock after", selection: $lockAfter) {
                            Text("Immediately").tag(0); Text("1 minute").tag(1); Text("5 minutes").tag(5); Text("15 minutes").tag(15); Text("1 hour").tag(60)
                        }
                    }
                }
                Section {
                    Text("To save from chat, connect Claude in Margin for Mac. Your notes are plain Markdown files in iCloud Drive › Margin.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
