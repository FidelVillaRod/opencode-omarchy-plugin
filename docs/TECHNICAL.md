# OpenCode Omarchy Plugin — Technical Notes

Technical reference for maintaining and extending the `opencode.core` Omarchy
bar plugin. This file is meant to be a persistent, conversation-independent
source of truth so the project can be picked back up at any time.

## Repo & remotes

- Source of truth repo: `~/opencode-plugin`
- Remote: `https://github.com/FidelVillaRod/opencode-omarchy-plugin.git` (public)
  - `git remote -v` should point there; push uses the `gh` auth (`gh auth setup-git`).
- Active install: `~/.config/omarchy/plugins/opencode.core/`
- Helper scripts (installed to PATH): `~/.local/bin/omarchy-opencode-{resume,new,check,delete,export,exports}`
- Pre-rename backup (old `fidelv.opencode` + `shell.json`): `/home/fidelv/opencode-rename-backup-20260828-215625/`

## Environment / conventions

- OS: Omarchy (Arch + Hyprland), user `fidelv`, UI language is English.
- Applying changes (no hot-reload by design):
  1. Edit in `~/opencode-plugin` (source of truth).
  2. `qmllint Panel.qml` (must exit 0).
  3. `cp Panel.qml ~/.config/omarchy/plugins/opencode.core/Panel.qml`
  4. `omarchy plugin validate ~/.config/omarchy/plugins/opencode.core`
  5. `omarchy restart shell` (NOT `omarchy refresh shell` — that resets `shell.json`).
  6. Check the shell log: `ls -t /run/user/1000/quickshell/by-id/*/log.log | head -1`
     then grep for `error|ReferenceError|TypeError|failed|undefined` (exclude `portal`).
- Do NOT modify Omarchy base files under `/usr/share/omarchy/` — only the plugin.

## Structure

```
opencode.core/
├── manifest.json        # widget metadata + schema (id: opencode.core)
├── Panel.qml            # UI + QML logic (uses Omarchy's ConfirmDialog)
├── collector.py         # reads opencode.db (SELECT only)
└── bin/
    ├── omarchy-opencode-resume   # resume a session on the active workspace
    ├── omarchy-opencode-new      # start a new session (optional model)
    ├── omarchy-opencode-check    # report open/closed state ("open" / "closed")
    ├── omarchy-opencode-delete   # close (if open) + delete a session
    ├── omarchy-opencode-export   # export to Markdown+JSON, then open the folder
    └── omarchy-opencode-exports  # open the exports folder
```

## Key QML mechanics

- Panel is `Panel{}` (id `root`); bar widget shown via `KeyboardPanel` (id `panel`)
  whose `focusTarget` is a custom `Item` (id `keyCatcher`).
- **Focus/keys**: `keyCatcher` uses `focus: true` + `Keys.priority: Keys.BeforeItem`.
  - Deliberately does NOT delegate keys to an open dialog; instead it calls
    `deleteConfirm.handleKey(event)` when `root.deleteDialogOpen`.
  - Dropdown popup open → return (let the popup handle keys).
  - Search field active → return (let the field handle keys).
  - Any printable character types straight into the search field.
  - Navigation is arrows + Enter + Del + Esc (the old letter shortcuts j/k/l/h/d/r
    were removed so letters go to search).
- **Header cursor model**: `selectedIndex === -1` means "header". `headerSubIndex`:
  `2` = exports folder button (top), `1` = `+` (new session), `0` = model dropdown.
  `↑`/`↓` arcs folder → `+` → dropdown → sessions.
- **Row hover/click separation** (fixes grey/flicker/resume-on-click):
  - `HoverHandler` (target: row) covers the whole row (text + icons) → drives `showActions`.
  - `MouseArea rowMouse` only resumes; it EXCLUDES the icon zone via
    `anchors.rightMargin: row.actionWidth + 4` so a click on a button never resumes.
  - Buttons are `PanelActionButton`s; never set `enabled` to false (that paints
    them grey) — use `visible`/`opacity` only.
- **Delete flow**: `confirmDelete(id,title)` opens `ConfirmDialog` (z higher than
  the keyCatcher content so the panel rows never draw over it). `checker` Process
  reports state; `deleteProc` (Process, `onExited` — NOT `onExit`) runs the delete
  and `refreshData()` on exit. "Deleting…" persists until the session disappears
  from the list (cleared in the collector read only when the id is gone).
- **Search**: `searchField` (Omarchy `TextField`) → `onTextChanged: root.searchText = text`.
  `visibleSessions` is a reactively-bound property:
  `readonly property var visibleSessions: root.filterVerified(root.sessions || [], root.searchText)`
  (pass sessions+query as arguments so the binding tracks changes; do NOT hide
  reads inside the function or it stops being reactive). Filters by title, model id, or provider.
- **Scroll list**: sessions are a `ListView` (id `sessionList`):
  `height: Math.min(sessionList.contentHeight, root.maxVisibleRowsHeight)`.
  `maxVisibleRowsHeight = Style.space(34) * 7` (~7 rows). DO NOT reference a
  non-existent property here — a typo made the height `undefined` ⇒ height 0 ⇒
  no sessions shown (bug fixed). Scroll on keyboard via
  `onSelectedIndexChanged` → `sessionList.positionViewAtIndex(root.selectedIndex, ListView.Center)`.
- **Export filename**: `<title>_<model>_YYYYMMDD-HHMMSS` (title and model
  sanitized to `[A-Za-z0-9_]`); falls back to opencode slug. NOTE: after editing
  any script, remember to ALSO `cp` it to `~/.local/bin/` — the installed copies
  are what actually run (this was the cause of "export filenames not changing").

## Security posture (audit summary)

- No secrets, no absolute personal paths in HEAD or git history.
- Scripts validate input with strict regex that excludes shell/SQL metacharacters
  (`^[A-Za-z0-9._-]+$` for ids, `^[A-Za-z0-9._/:+-]+$` for models) → no injection.
- `Panel.qml` passes every arg to `bar.run()` through `Util.shellQuote()`.
- `collector.py` is read-only (`SELECT` only); no network; no personal paths.
- Exports write locally to the user's downloads folder only (never uploaded).
- `manifest.json` `author` is the public alias (`Fidel`/GitHub `FidelVillaRod`).

## Design decisions worth remembering

- Read data from `opencode.db` via `collector.py` (fast, robust) instead of
  calling `opencode oc`/`session list` per refresh.
- Refresh on open + every `refreshIntervalSec` (default 300 s, 20 sessions max).
- `omarchy-opencode-delete` uses `opencode session delete` (knows the schema)
  with a DB-free fallback; `check` uses `pgrep -af opencode | grep -- "-s <id>"`.

## Testing / validation checklist

- `qmllint Panel.qml` → exit 0.
- `bash -n bin/omarchy-opencode-*` → syntax ok.
- `omarchy plugin validate ~/.config/omarchy/plugins/opencode.core`.
- `omarchy restart shell`, then confirm clean log.
- Manual: browse sessions, search by title/model, export (check filename),
  delete (watch "Deleting…" persist), keyboard nav, scroll with 8+ sessions.
