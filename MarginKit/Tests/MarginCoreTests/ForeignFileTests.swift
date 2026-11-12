import Foundation
import Testing
@testable import MarginCore

struct ForeignFileTests {
    @Test func preservesUnknownFrontMatter() throws {
        let text = "---\nid: 01ABC\ntitle: \"Skills\"\ntags: [career, growth]\ncreated: 2026-11-12T10:00:00Z\nupdated: 2026-11-12T10:00:00Z\nrevision: 2\naliases: Yetenekler\n---\nbody\n"
        let note = try NoteFile.parse(text)
        let out = note.serialize()
        #expect(out.contains("tags: [career, growth]\n"))
        #expect(out.contains("aliases: Yetenekler\n"))
        #expect(try NoteFile.parse(out) == note)
    }

    @Test func acceptsCRLFAndBOM() throws {
        let text = "\u{FEFF}---\r\nid: 01ABC\r\ntitle: \"Win\"\r\ncreated: 2026-11-12T10:00:00Z\r\nupdated: 2026-11-12T10:00:00Z\r\nrevision: 1\r\n---\r\n- a\r\n- b\r\n"
        let note = try NoteFile.parse(text)
        #expect(note.meta.title == "Win")
        #expect(note.body == "- a\n- b\n")
    }

    @Test func plainMarkdownBecomesNote() throws {
        let store = try makeStore()
        let topic = try store.createTopic(title: "Imported", source: nil)
        let url = store.root.appendingPathComponent("\(topic.directoryName)/Reading list.md")
        try "# Books\n- Dune\n".write(to: url, atomically: true, encoding: .utf8)

        let notes = try store.listNotes(topicID: topic.id)
        #expect(notes.count == 1)
        #expect(notes[0].meta.title == "Reading list")
        #expect(notes[0].meta.revision == 0)
        let id = notes[0].meta.id
        #expect(try store.listNotes(topicID: topic.id)[0].meta.id == id) // stable across reads

        let updated = try store.appendToNote(id: id, text: "- Hyperion", by: .claudeCode, summary: "add", project: nil)
        #expect(updated.meta.revision == 1)
        #expect(updated.meta.id == id)
        #expect(try store.findNote(id: id).1.body == "# Books\n- Dune\n\n\n- Hyperion")
    }
}
