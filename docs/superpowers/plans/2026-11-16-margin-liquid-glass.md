# Margin — Liquid Glass adoption · Plan

Source research (HIG Materials, WWDC25 219/323/356, WWDC26 269, MacStories roundups): glass is for the
navigation/control layer only; content stays non-glass and scrolls underneath. Model apps: Things,
Craft, Fantastical, Day One, Apple Notes.

## Decisions (Claude's calls)
- Deployment targets raised to macOS 26 / iOS 26 (Liquid Glass APIs; OS 27 is current).
- Remove every opaque background behind chrome (sidebar, list column, window canvas); let the system
  sidebar/toolbar glass and scroll edge effects work. Content cards keep their solid card fill.
- Mac window: standard unified toolbar (no hidden title bar). Toolbar: New note, Quick note,
  search (`.searchable` → glass field top-trailing), note actions. `ToolbarSpacer` groups.
- Mac sidebar: native `List(.sidebar)` with colored topic icons (macOS 27 colors sidebar icons again).
- Editor: full-bleed in the detail column (no inner card); soft scroll edge under the toolbar.
- Floating UI (⌘K palette, quick-capture panel, conflict/removal banners): `.glassEffect(.regular)`
  in a concentric rounded rect; rows inside use fills, never glass-on-glass.
- Buttons: one `.glassProminent` primary action per view (tinted sage), others `.glass`.
- iPhone: system glass bars; bottom toolbar = search field + spacer + glass-prominent compose button
  (Notes/Craft pattern) that zoom-morphs into the quick-note sheet; ellipsis without circle variant;
  explicit `.soft` scroll edges (iOS 27 changed `.automatic` to hard).
- Accessibility: rely on system glass (Reduce Transparency / Increase Contrast / the iOS 27 slider).
