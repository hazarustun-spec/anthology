import MarginCore
import SwiftUI

extension ChangeSource {
    var label: LocalizedStringKey { LocalizedStringKey(displayName) }

    var symbol: String { self == .app ? "person" : "sparkles" }

    /// Small per-tool glyph used in the line gutter; nil for the user's own lines (kept unmarked).
    var lineSymbol: String? {
        switch self {
        case .app: nil
        case .claudeCode: "terminal"
        case .cowork: "sparkles"
        case .gemini: "sparkle"
        case .cursor: "cursorarrow"
        case .vscode: "curlybraces"
        case .codex: "hexagon"
        }
    }
}

/// Per-line authorship for the editor, aligned to the editor's current lines.
enum LineAuthors {
    /// Maps saved attribution onto `text`'s lines; lines not in the saved version (fresh typing) get nil.
    static func align(_ attribution: [LineAttribution], to text: String) -> [LineAttribution?] {
        let lines = text.components(separatedBy: "\n")
        guard !attribution.isEmpty, lines.count < 3000, attribution.count < 3000 else {
            return Array(repeating: nil, count: lines.count)
        }
        let matches = MarginStore.lcsMatches(attribution.map(\.text), lines)
        return matches.map { $0.map { attribution[$0] } }
    }

    /// Icon strength fades with age: recent changes stand out, old ones recede.
    static func opacity(for date: Date?, now: Date = .now) -> Double {
        guard let date else { return 0.35 }
        let age = now.timeIntervalSince(date)
        if age < 86_400 { return 0.9 }
        if age < 7 * 86_400 { return 0.6 }
        return 0.35
    }

    static func tooltip(_ a: LineAttribution, now: Date = .now) -> String {
        let who = a.source?.displayName ?? String(localized: "Unknown")
        guard let date = a.date else { return who }
        let when = RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
        return "\(who) · \(when)"
    }
}

extension ChangeSource {
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .cowork: "Cowork"
        case .app: String(localized: "You")
        case .gemini: "Gemini CLI"
        case .cursor: "Cursor"
        case .vscode: "VS Code"
        case .codex: "Codex"
        }
    }
}

struct SourceBadge: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.by.symbol).foregroundStyle(Color(palette: Palette.accent))
            Text(entry.by.label)
            Text("·")
            Text(entry.summary).lineLimit(1)
            Text("·")
            Text(entry.at, format: .relative(presentation: .named))
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(Capsule().fill(Color(palette: Palette.chip)))
    }
}

struct HistoryList: View {
    let entries: [HistoryEntry]
    var canRestore: (Int) -> Bool = { _ in false }
    var onRestore: (Int) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("History").font(.system(size: 13, weight: .semibold)).padding(.bottom, 8)
                ForEach(entries, id: \.rev) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: e.by.symbol).foregroundStyle(Color(palette: e.by == .app ? Palette.secondary : Palette.accent)).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.summary).foregroundStyle(.primary)
                            HStack(spacing: 4) {
                                Text(e.by.label)
                                Text("·")
                                Text(e.at, format: .dateTime.day().month().hour().minute())
                            }
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 6)
                        if e.rev > 1, canRestore(e.rev) {
                            Button("Undo") { onRestore(e.rev) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(palette: Palette.accent))
                                .help("Restore the note as it was before this change")
                        }
                    }
                    .padding(.vertical, 7)
                    Divider().overlay(Color(palette: Palette.hairline))
                }
            }
            .padding(14)
        }
        .font(.system(size: 12))
        .frame(width: 320, height: min(CGFloat(entries.count) * 52 + 50, 360))
        .background(Color(palette: Palette.canvas))
    }
}

/// Strips Markdown markers for one-line previews.
enum NoteText {
    static func plain(_ line: String) -> String {
        var l = line.trimmingCharacters(in: .whitespaces)
        for marker in ["- [ ] ", "- [x] ", "- [X] "] where l.hasPrefix(marker) { l.removeFirst(marker.count) }
        l = l.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        return l.trimmingCharacters(in: CharacterSet(charactersIn: "#-*+_").union(.whitespaces))
    }
}
