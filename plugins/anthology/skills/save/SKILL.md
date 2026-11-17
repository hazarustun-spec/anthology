---
name: save
description: Save the useful outcome of this conversation (decisions, lists, next steps) into the user's Anthology notes.
argument-hint: "[what to save, optional]"
disable-model-invocation: true
---
Save to Anthology now; the user's command is the consent.

1. If the user gave text after the command, save that. Otherwise distill this conversation into what is worth keeping: decisions and why, lists, open questions, next steps. Skip chatter and code that already lives in the repo.
2. Call `list_topics`, then prefer updating a fitting note (`get_note` → merge → `update_note` with `base_revision`) over creating a near-duplicate with `save_note`.
3. Pass `project_path` = the current working directory. Write in the user's language, as clean Markdown (short headings, bullets, `- [ ]` for to-dos).
4. Reply with one line: `<Topic> › <Note>`.

$ARGUMENTS
