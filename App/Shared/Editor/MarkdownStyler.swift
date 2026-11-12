#if os(macOS)
import AppKit
typealias TextStorageEditActions = NSTextStorageEditActions
#else
import UIKit
typealias TextStorageEditActions = NSTextStorage.EditActions
#endif

/// Live Markdown styling for the note editor. Restyles only the paragraphs that changed.
@MainActor
final class MarkdownStyler: NSObject, NSTextStorageDelegate {
    var bodyFont = Palette.sans(15)
    var freshLines: Set<String> = []

    private static let heading = try! NSRegularExpression(pattern: "^(#{1,3})\\s+.*$", options: [.anchorsMatchLines])
    private static let bullet = try! NSRegularExpression(pattern: "^(\\s*)([-*+]|\\d+\\.)\\s", options: [.anchorsMatchLines])
    private static let checkbox = try! NSRegularExpression(pattern: "^(\\s*)[-*+]\\s\\[( |x|X)\\]\\s", options: [.anchorsMatchLines])
    private static let bold = try! NSRegularExpression(pattern: "\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*")
    private static let italic = try! NSRegularExpression(pattern: "(?<![*\\w])\\*(?![*\\s])(.+?)(?<![*\\s])\\*(?![*\\w])|(?<![_\\w])_(?![_\\s])(.+?)(?<![_\\s])_(?![_\\w])")
    private static let code = try! NSRegularExpression(pattern: "`[^`\\n]+`")

    var paragraphStyle: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 5
        return p
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: Palette.body, .paragraphStyle: paragraphStyle]
    }

    nonisolated func textStorage(_ storage: NSTextStorage, didProcessEditing mask: TextStorageEditActions, range: NSRange, changeInLength delta: Int) {
        guard mask.contains(.editedCharacters) else { return }
        // Text storage delegate callbacks arrive on the main thread for an NSTextView-owned storage.
        nonisolated(unsafe) let storage = storage
        MainActor.assumeIsolated {
            let text = storage.string as NSString
            style(storage, in: text.paragraphRange(for: range))
        }
    }

    func styleAll(_ storage: NSTextStorage) {
        style(storage, in: NSRange(location: 0, length: storage.length))
    }

    func style(_ storage: NSTextStorage, in range: NSRange) {
        guard range.length > 0 else { return }
        let text = storage.string as NSString
        storage.setAttributes(baseAttributes, range: range)

        Self.heading.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            let level = m.range(at: 1).length
            let font: PlatformFont
            let color: PlatformColor
            switch level {
            case 1: font = Palette.sans(22, weight: .semibold); color = Palette.text
            case 2: font = Palette.sans(14, weight: .semibold); color = Palette.accent
            default: font = Palette.sans(13, weight: .semibold); color = Palette.secondary
            }
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 4
            p.paragraphSpacingBefore = level == 1 ? 6 : 8
            p.paragraphSpacing = 4
            storage.addAttributes([.font: font, .foregroundColor: color, .paragraphStyle: p], range: m.range)
            storage.addAttribute(.foregroundColor, value: Palette.tertiary.withAlphaComponent(0.6), range: m.range(at: 1))
        }
        Self.bullet.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            let marker = m.range(at: 2)
            if marker.length == 1 {
                storage.addAttributes([.foregroundColor: PlatformColor.clear, .marginBullet: true], range: marker)
            } else {
                storage.addAttribute(.foregroundColor, value: Palette.accent, range: marker)
            }
            hangingIndent(storage, line: text.lineRange(for: m.range), prefix: m.range)
        }
        Self.checkbox.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            let checked = text.substring(with: m.range(at: 2)).lowercased() == "x"
            let marker = NSRange(location: m.range.location + m.range(at: 1).length, length: m.range.length - m.range(at: 1).length)
            storage.removeAttribute(.marginBullet, range: marker)
            storage.addAttributes([.foregroundColor: PlatformColor.clear, .font: PlatformFont.monospacedSystemFont(ofSize: 11, weight: .regular)], range: marker)
            storage.addAttribute(.marginCheckbox, value: checked, range: NSRange(location: marker.location + 2, length: 3))
            hangingIndent(storage, line: text.lineRange(for: m.range), prefix: NSRange(location: m.range.location, length: m.range.length))
            if checked {
                let line = text.lineRange(for: m.range)
                let rest = NSRange(location: NSMaxRange(m.range), length: max(0, NSMaxRange(line) - NSMaxRange(m.range)))
                storage.addAttributes([.foregroundColor: Palette.tertiary, .strikethroughStyle: NSUnderlineStyle.single.rawValue], range: rest)
            }
        }
        Self.bold.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            let font = (storage.attribute(.font, at: m.range.location, effectiveRange: nil) as? PlatformFont) ?? bodyFont
            storage.addAttribute(.font, value: font.adding(bold: true), range: m.range)
            dimMarkers(storage, m.range, 2)
        }
        Self.italic.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            let font = (storage.attribute(.font, at: m.range.location, effectiveRange: nil) as? PlatformFont) ?? bodyFont
            storage.addAttribute(.font, value: font.adding(italic: true), range: m.range)
            dimMarkers(storage, m.range, 1)
        }
        Self.code.enumerateMatches(in: storage.string, range: range) { m, _, _ in
            guard let m else { return }
            storage.addAttributes([
                .font: PlatformFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .backgroundColor: Palette.codeBG, .foregroundColor: Palette.text,
            ], range: m.range)
        }
        if !freshLines.isEmpty {
            text.enumerateSubstrings(in: range, options: .byLines) { line, lineRange, _, _ in
                if let line, self.freshLines.contains(line) {
                    storage.addAttribute(.backgroundColor, value: Palette.accentWash, range: lineRange)
                }
            }
        }
    }

    /// Wrapped lines of a list item start under its text, not under the marker.
    private func hangingIndent(_ storage: NSTextStorage, line: NSRange, prefix: NSRange) {
        let width = storage.attributedSubstring(from: prefix).size().width
        let p = (paragraphStyle.mutableCopy() as! NSMutableParagraphStyle)
        p.headIndent = ceil(width)
        storage.addAttribute(.paragraphStyle, value: p, range: line)
    }

    private func dimMarkers(_ storage: NSTextStorage, _ range: NSRange, _ width: Int) {
        guard range.length > width * 2 else { return }
        let faint: [NSAttributedString.Key: Any] = [
            .foregroundColor: Palette.tertiary.withAlphaComponent(0.45),
            .font: Palette.sans(bodyFont.pointSize * 0.8),
        ]
        storage.addAttributes(faint, range: NSRange(location: range.location, length: width))
        storage.addAttributes(faint, range: NSRange(location: NSMaxRange(range) - width, length: width))
    }

    /// If `index` falls on a checkbox marker, returns the range of the character between the brackets.
    static func checkboxToggleRange(in text: NSString, at index: Int) -> NSRange? {
        guard index < text.length else { return nil }
        let line = text.lineRange(for: NSRange(location: index, length: 0))
        guard let m = checkbox.firstMatch(in: text as String, range: line) else { return nil }
        let markerStart = m.range.location + m.range(at: 1).length
        guard index >= markerStart, index < NSMaxRange(m.range) else { return nil }
        return m.range(at: 2)
    }
}


extension PlatformFont {
    func adding(bold: Bool = false, italic: Bool = false) -> PlatformFont {
        #if os(macOS)
        var traits = fontDescriptor.symbolicTraits
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        return PlatformFont(descriptor: fontDescriptor.withSymbolicTraits(traits), size: pointSize) ?? self
        #else
        var traits = fontDescriptor.symbolicTraits
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard let d = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return PlatformFont(descriptor: d, size: pointSize)
        #endif
    }
}
