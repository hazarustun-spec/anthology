extension MarginTools {
    public static var serverInstructions: String { instructions(settings: .default) }

    /// Sent to Claude as the MCP server `instructions`. Encodes spec §6.3, the consent rule (§6.4.1)
    /// and the user's chat shortcuts.
    public static func instructions(settings: MarginSettings) -> String {
        baseInstructions + """

        Shortcuts
        - A message starting with "\(settings.smartPrefix) " is an explicit save request: save the rest of the \
        message to Margin right away without asking, filing it into the best existing note (or a new one), \
        then reply with one short line saying where it went.
        - A message starting with "\(settings.instantPrefix) " means: call quick_capture with the rest of the \
        message verbatim (no rewriting, no merging), then reply with one short line.
        """
    }

    static let baseInstructions = """
    Margin is the user's personal notes app (Mac + iPhone). Notes are organized as Topic → Notes. \
    A topic normally corresponds to the project folder the user is working in. Each note is a living \
    document that you keep tidy and up to date.

    When to use Margin
    - The user asks to save/note/keep something "in the app", "in Margin", "in my notes" (in any \
    language, e.g. Turkish "app'e kaydet", "Margin'e ekle", "notlarıma yaz"). That request is consent \
    for that save and for follow-up edits to the same note the user asks for in this conversation.
    - If something clearly worth keeping comes up (goals, decisions, lists, ideas the user wants to \
    remember) you may OFFER once: "Want me to add this to your Margin notes?" Save only after the user \
    says yes; that consent covers only that one save. Never save silently.
    - When the user refers to their notes ("based on my skill list…", "what did I note about…"), use \
    search_notes / get_note to read them.

    How to save well
    1. Always pass project_path = the absolute path of the current working/project folder. If you do \
    not know any folder (e.g. some chat surfaces) and the topic is unclear, ask the user which topic \
    on the first save, or propose one from context and confirm. Pass `topic` only when the user names \
    a topic or when you resolved an ambiguity.
    2. Call list_topics to see existing topics and notes. Prefer updating an existing note that fits \
    over creating a near-duplicate.
    3. To change an existing note: get_note → merge the new information into the right place (add to \
    the list, update a line, keep structure and headings) → update_note with base_revision from \
    get_note. If update_note says the note changed, call get_note again, merge again, retry.
    4. To create a new note: save_note with a short, clear note_title and well-structured Markdown.
    5. Write in the language the user is speaking. Keep the user's own wording for their items.
    6. Always give a one-line summary (shown in the note's history), e.g. "Added SQL and system design".
    7. After saving, tell the user briefly where it went: "<Topic> › <Note>".
    Never delete or move notes unless the user asks.
    """
}
