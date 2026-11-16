import AppKit
import MarginCore

/// Narrow left gutter that marks lines an AI tool wrote with that tool's small glyph.
/// The user's own lines stay unmarked; older marks fade. Hover shows "Cursor · 3 days ago".
final class AttributionGutter: NSRulerView {
    static let width: CGFloat = 26

    var authors: [LineAttribution?] = [] { didSet { needsDisplay = true } }
    private var marks: [(rect: NSRect, tip: String)] = []

    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        ruleThickness = Self.width
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // No background or separator: the gutter should read as page margin.
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        removeAllToolTips()
        marks.removeAll()
        guard let textView = clientView as? NSTextView,
              let layout = textView.layoutManager, let container = textView.textContainer else { return }
        let text = textView.string as NSString
        let visible = textView.visibleRect
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let chars = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        // Line index = number of newlines before the first visible paragraph.
        var index = text.paragraphRange(for: NSRange(location: min(chars.location, text.length), length: 0)).location
        var line = 0
        for i in 0..<index where text.character(at: i) == 10 { line += 1 }

        let end = NSMaxRange(chars)
        let now = Date()
        repeat {
            let para = text.paragraphRange(for: NSRange(location: index, length: 0))
            if line < authors.count, let a = authors[line], let symbol = a.source?.lineSymbol,
               !text.substring(with: para).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let glyph = layout.glyphIndexForCharacter(at: para.location)
                var lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                lineRect.origin.y += textView.textContainerOrigin.y
                let y = convert(NSPoint(x: 0, y: lineRect.midY), from: textView).y
                let iconRect = NSRect(x: 5, y: y - 6.5, width: 13, height: 13)
                draw(symbol: symbol, in: iconRect, opacity: LineAuthors.opacity(for: a.date, now: now))
                let hit = iconRect.insetBy(dx: -4, dy: -3)
                marks.append((hit, LineAuthors.tooltip(a, now: now)))
                addToolTip(hit, owner: self, userData: nil)
            }
            line += 1
            index = NSMaxRange(para)
        } while index < end && index < text.length
    }

    private func draw(symbol: String, in rect: NSRect, opacity: Double) {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            .applying(.init(paletteColors: [Palette.accent.withAlphaComponent(opacity)]))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let size = image.size
        let target = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        image.draw(in: target)
    }
}

extension AttributionGutter: NSViewToolTipOwner {
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        marks.first { $0.rect.contains(point) }?.tip ?? ""
    }
}
