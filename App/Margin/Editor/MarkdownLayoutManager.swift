import AppKit

extension NSAttributedString.Key {
    /// Value: Bool (checked). Marks the `- [ ]` marker; drawn as a checkbox symbol.
    static let marginCheckbox = NSAttributedString.Key("marginCheckbox")
    /// Marks a `-`/`*`/`+` bullet marker; drawn as a dot.
    static let marginBullet = NSAttributedString.Key("marginBullet")
}

/// Draws checkbox and bullet markers as symbols over their (transparent) source characters,
/// so the file stays plain Markdown while the editor looks like a notes app.
final class MarkdownLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        storage.enumerateAttribute(.marginCheckbox, in: chars) { value, range, _ in
            guard let checked = value as? Bool else { return }
            let rect = markerRect(for: range, origin: origin)
            let side: CGFloat = 15
            let box = NSRect(x: rect.minX + 1, y: rect.midY - side / 2 + 1, width: side, height: side)
            let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.75, dy: 0.75), xRadius: 4, yRadius: 4)
            if checked {
                Palette.accent.setFill()
                path.fill()
                let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
                    .applying(.init(paletteColors: [.white]))
                if let tick = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    let size = tick.size
                    tick.draw(in: NSRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height))
                }
            } else {
                Palette.tertiary.setStroke()
                path.lineWidth = 1.3
                path.stroke()
            }
        }
        storage.enumerateAttribute(.marginBullet, in: chars) { value, range, _ in
            guard value != nil else { return }
            let rect = markerRect(for: range, origin: origin)
            let d: CGFloat = 5.5
            Palette.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.minX + 2, y: rect.midY - d / 2 + 1, width: d, height: d)).fill()
        }
    }

    private func markerRect(for range: NSRange, origin: NSPoint) -> NSRect {
        let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard let container = textContainer(forGlyphAt: glyphs.location, effectiveRange: nil) else { return .zero }
        var rect = boundingRect(forGlyphRange: glyphs, in: container)
        let line = lineFragmentUsedRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        rect.origin.y = line.origin.y
        rect.size.height = line.height - (line.height - rect.height) / 2
        return rect.offsetBy(dx: origin.x, dy: origin.y)
    }
}
