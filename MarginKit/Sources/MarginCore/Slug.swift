import Foundation

/// URL/file-safe slug with Turkish transliteration. Never empty.
public func slugify(_ s: String) -> String {
    let turkish: [Character: String] = [
        "İ": "i", "I": "i", "ı": "i", "Ç": "c", "ç": "c", "Ğ": "g", "ğ": "g",
        "Ö": "o", "ö": "o", "Ş": "s", "ş": "s", "Ü": "u", "ü": "u",
    ]
    let mapped = s.map { turkish[$0] ?? String($0) }.joined()
    let folded = mapped
        .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
    var out = ""
    var lastWasDash = false
    for scalar in folded.unicodeScalars {
        if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
            out.unicodeScalars.append(scalar)
            lastWasDash = false
        } else if !lastWasDash, !out.isEmpty {
            out.append("-")
            lastWasDash = true
        }
    }
    while out.hasSuffix("-") { out.removeLast() }
    if out.count > 40 {
        out = String(out.prefix(40))
        while out.hasSuffix("-") { out.removeLast() }
    }
    return out.isEmpty ? "topic" : out
}

/// "career-notes" → "Career notes", "kariyer" → "Kariyer".
func prettifyFolderName(_ name: String) -> String {
    let spaced = name
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .joined(separator: " ")
    guard let first = spaced.first else { return "Inbox" }
    return first.uppercased() + spaced.dropFirst()
}
