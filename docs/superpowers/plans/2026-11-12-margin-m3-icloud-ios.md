# Margin M3 — iCloud sync + iPhone app · Plan

> Executed inline. Core logic TDD; UI verified in the iOS Simulator and on Hazar's devices.

**Goal:** Notes live in Margin's iCloud Drive container and appear on the iPhone app within seconds;
the iPhone app has the same Blocks design with editing, checkboxes, haptics and search.
**Spec:** `docs/superpowers/specs/2026-11-12-margin-design.md` (§6.1, §6.4, §6.5, §9 risk 2)

## Decisions (Claude's calls)
- Container `iCloud.com.marginnotes.Margin`, iCloud Documents (not CloudKit): notes stay plain files,
  visible in Finder/Files as "Margin". Same bundle id on iOS and macOS (universal purchase later).
- Team id lives in `App/Local.xcconfig` (git-ignored); `Local.sample.xcconfig` documents it for
  contributors. Nothing personal in the repo.
- Mac app moves existing local notes into iCloud once (copy, verify, keep the old folder renamed).
  margin-mcp keeps finding the container by path (it has no entitlements); verify that files it
  writes sync (risk 2).
- iOS downloads placeholders with an `NSMetadataQuery` and refreshes the library when items change.
- Shared code: `MarginCore` (store) + `App/Shared` (palette, Markdown styler, library model).
  Platform UI in `App/Margin` (macOS) and `App/MarginMobile` (iOS).
- Conflicts (two devices editing the same note): detected via `NSFileVersion`; both apps show
  "Two versions of this note" with Keep this / Keep other / Keep both.

## Tasks
1. Core builds for iOS (macOS-only config editing behind `#if os(macOS)`); conflict API + tests.
2. Xcode project: shared sources, iOS target, iCloud entitlements, Local.xcconfig signing.
3. Mac: iCloud root + one-time migration; status line in Settings ("Syncing with iCloud").
4. iOS app: topics → notes → editor (TextKit 1 styler port, tappable checkboxes, haptics), search,
   quick note, pull-free live updates, Face ID lock, Settings.
5. Verify: simulator screenshots; device install; Mac→iPhone sync of a note Claude writes.
