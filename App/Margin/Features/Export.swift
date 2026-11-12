import AppKit
import MarginCore
import UniformTypeIdentifiers

/// Copy as Markdown, export to PDF, reveal in Finder.
@MainActor
enum NoteExport {
    static func copyMarkdown(title: String, body: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("# \(title)\n\n\(body)", forType: .string)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func exportPDF(title: String, body: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? pdfData(title: title, body: body).write(to: url)
    }

    /// Renders the note with the editor's styling, always in light colors, on A4 pages.
    static func pdfData(title: String, body: String) -> Data {
        let page = NSSize(width: 595, height: 842)
        let margin: CGFloat = 56
        let styler = MarkdownStyler()
        let storage = NSTextStorage(string: body)
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance { styler.styleAll(storage) }
        let titleAttr = NSMutableAttributedString(string: title + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: NSColor.black,
        ])
        titleAttr.append(storage)
        // Resolve dynamic colors to their light variants for print.
        titleAttr.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: titleAttr.length)) { value, range, _ in
            guard let c = value as? NSColor else { return }
            var resolved = c
            NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance { resolved = c.usingColorSpace(.sRGB) ?? c }
            titleAttr.addAttribute(.foregroundColor, value: resolved == .clear ? NSColor.clear : resolved, range: range)
        }
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: page.width - margin * 2, height: 10))
        textView.textStorage?.setAttributedString(titleAttr)
        textView.textContainerInset = .zero
        textView.sizeToFit()
        let info = NSPrintInfo()
        info.paperSize = page
        info.topMargin = margin; info.bottomMargin = margin; info.leftMargin = margin; info.rightMargin = margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        let data = NSMutableData()
        let op = NSPrintOperation.pdfOperation(with: textView, inside: textView.bounds, to: data, printInfo: info)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        op.run()
        return data as Data
    }
}
