import AppKit
import MarginCore
import SwiftUI

/// NSTextView with clickable Markdown checkboxes.
final class MarkdownTextView: NSTextView {
    var onToggle: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let text = string as NSString
        for candidate in [index, index - 1] where candidate >= 0 {
            if let r = MarkdownStyler.checkboxToggleRange(in: text, at: candidate) {
                let next = text.substring(with: r) == " " ? "x" : " "
                if shouldChangeText(in: r, replacementString: next) {
                    textStorage?.replaceCharacters(in: r, with: next)
                    didChangeText()
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    onToggle?()
                }
                return
            }
        }
        super.mouseDown(with: event)
    }
}

/// Editable, live-styled Markdown body of a note.
struct NoteEditor: NSViewRepresentable {
    @Binding var text: String
    var freshLines: Set<String>
    var attribution: [LineAttribution] = []
    var onEdit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        // TextKit 1 stack with a custom layout manager that draws checkboxes and bullets.
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let textView = MarkdownTextView(frame: .zero, textContainer: container)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.insertionPointColor = Palette.accent
        textView.selectedTextAttributes = [.backgroundColor: Palette.selection]
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        storage.delegate = context.coordinator.styler
        textView.typingAttributes = context.coordinator.styler.baseAttributes
        textView.delegate = context.coordinator
        scroll.documentView = textView
        let gutter = AttributionGutter(scrollView: scroll)
        gutter.clientView = textView
        scroll.verticalRulerView = gutter
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.gutter = gutter
        context.coordinator.textView = textView
        context.coordinator.load(text, fresh: freshLines)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text || context.coordinator.styler.freshLines != freshLines {
            context.coordinator.load(text, fresh: freshLines)
        }
        if context.coordinator.attribution != attribution {
            context.coordinator.attribution = attribution
            context.coordinator.realignAuthors()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor
        let styler = MarkdownStyler()
        weak var textView: MarkdownTextView?
        weak var gutter: AttributionGutter?
        var attribution: [LineAttribution] = []
        private var loading = false

        init(_ parent: NoteEditor) { self.parent = parent }

        func load(_ text: String, fresh: Set<String>) {
            guard let textView, let storage = textView.textStorage else { return }
            loading = true
            let selection = textView.selectedRanges
            styler.freshLines = fresh
            if textView.string != text {
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            }
            styler.styleAll(storage)
            let length = (text as NSString).length
            textView.selectedRanges = selection.map { NSValue(range: NSRange(location: min($0.rangeValue.location, length), length: 0)) }
            loading = false
            realignAuthors()
        }

        func realignAuthors() {
            guard let textView else { return }
            gutter?.authors = LineAuthors.align(attribution, to: textView.string)
        }

        func textDidChange(_ notification: Notification) {
            guard !loading, let textView else { return }
            parent.text = textView.string
            parent.onEdit(textView.string)
            realignAuthors()
        }
    }
}
