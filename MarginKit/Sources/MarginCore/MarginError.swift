import Foundation

public enum MarginError: Error, Equatable, LocalizedError {
    case malformedNote(String)
    case topicNotFound(String)
    case noteNotFound(String)
    case staleRevision(expected: Int, actual: Int)
    case ambiguousTopic([String])
    case conflict(String)
    case busy

    public var errorDescription: String? {
        switch self {
        case .malformedNote(let why): "Malformed note: \(why)"
        case .topicNotFound(let id): "Topic not found: \(id)"
        case .noteNotFound(let id): "Note not found: \(id)"
        case .staleRevision(let expected, let actual):
            "Note changed since it was read (expected revision \(expected), now \(actual))."
        case .ambiguousTopic(let titles): "Several topics match: \(titles.joined(separator: ", "))"
        case .conflict(let path): "Note has unresolved iCloud conflict versions: \(path)"
        case .busy: "Margin is busy saving from another window or chat. Try again in a moment."
        }
    }
}
