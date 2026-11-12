import Foundation
import Testing
@testable import MarginCore

struct NoteFileTests {
    private func meta(_ title: String) -> NoteMeta {
        NoteMeta(
            id: newID(),
            title: title,
            created: Date(timeIntervalSince1970: 1_762_941_840),
            updated: Date(timeIntervalSince1970: 1_762_947_000),
            revision: 7
        )
    }

    @Test func roundTripTurkish() throws {
        let note = NoteFile(meta: meta("Kazanmak istediğim skiller"), body: "- SQL\n- Sistem tasarımı\n")
        #expect(try NoteFile.parse(note.serialize()) == note)
    }

    @Test func bodyWithDashes() throws {
        let note = NoteFile(meta: meta("Dashes"), body: "a\n---\nb: c\n---\n")
        #expect(try NoteFile.parse(note.serialize()) == note)
    }

    @Test func titleWithQuotesAndColon() throws {
        let note = NoteFile(meta: meta(#"He said: "hi""#), body: "x")
        #expect(try NoteFile.parse(note.serialize()) == note)
    }

    @Test func emptyBody() throws {
        let note = NoteFile(meta: meta("Empty"), body: "")
        #expect(try NoteFile.parse(note.serialize()) == note)
    }

    @Test func malformedThrows() {
        #expect(throws: MarginError.self) { try NoteFile.parse("no front matter") }
    }

    @Test func idsAreUniqueAnd26Chars() {
        let ids = (0..<1000).map { _ in newID() }
        #expect(Set(ids).count == 1000)
        #expect(ids.allSatisfy { $0.count == 26 })
    }
}
