# OpenCode — Omarchy Bar Plugin

A native Omarchy bar panel to manage your [OpenCode](https://opencode.ai)
sessions from the desktop: lists active/recent sessions, shows token usage and
daily cost, and lets you pick a model, start new sessions, export conversations
and delete sessions.

<img width="420" height="406" alt="image" src="https://github.com/user-attachments/assets/bb52fe91-6e1c-4ed0-82a5-2adb7f09b33e" />


## Features

- **Session list**: click a session to resume it in an `org.omarchy.agent`
  terminal on the active workspace.
- **Model selector**: dropdown with the available models (`opencode models`).
- **New session**: `+` button that opens `opencode -m <model>` on the active
  workspace.
- **Exports folder**: folder button that opens the folder where conversations
  are exported.
- **Action icons**: per-session download (export) and delete buttons on hover
  or keyboard selection.
- **Daily indicator**: sessions, tokens and cost of today in the panel.
- **Active vs. closed**: session directories are checked to mark which sessions
  are still open.

## Requirements

- [Omarchy](https://omarchy.org) (Arch + Hyprland)
- [OpenCode](https://opencode.ai) installed and reachable as `opencode`
- `python3` and standard `less`/`find`

## Installation

With `omarchy plugin add` (recommended):

```bash
# 1. Install the plugin from git
omarchy plugin add https://github.com/FidelVillaRod/opencode-omarchy-plugin --enable

# 2. Install the helper scripts (the panel calls them by name)
install -m755 ~/.config/omarchy/plugins/opencode.core/bin/omarchy-opencode-* ~/.local/bin/

# 3. Restart the shell to apply it
omarchy restart shell
```

Manual install (cloning the repo):

```bash
git clone https://github.com/FidelVillaRod/opencode-omarchy-plugin
cp -r opencode-omarchy-plugin ~/.config/omarchy/plugins/opencode.core
install -m755 opencode-omarchy-plugin/bin/omarchy-opencode-* ~/.local/bin/
omarchy restart shell
```

> Note: the `omarchy-opencode-*` programs must stay in `~/.local/bin/` (or on
> the PATH), because the panel invokes them by name.

## Configuration

The widget exposes two options tunable from the bar editor:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `refreshIntervalSec` | integer | 300 | Panel refresh interval (30–3600 s) |
| `maxSessions` | integer | 20 | Maximum sessions to show (5–50) |

## Usage

- Click a session → opens it on the active workspace and closes the panel.
- The `+` icon → new session with the selected model.
- The **Exports** button → opens the exports folder.
- The model selector persists the last selection.
- **Search box**: type while the panel is open — printable characters go
  straight into the search box and filter the list as you type by matching the
  session title, the model id, or the provider name. `Esc` clears the search
  and returns to the list.
- When there are more than ~7 sessions, the list scrolls (via the mouse wheel
  or by moving the keyboard cursor).
- The action icons **appear on hover** over a session (or on keyboard
  selection):
  - **Download** icon → exports the conversation to the downloads folder's
    `opencode` subdirectory (Markdown + JSON) and opens that folder. The
    exported files are named `<title>_<model>_YYYYMMDD-HHMMSS`.
  - **Trash** icon → deletes the session. If it is open, it warns that it is
    in use and lets you close and delete it; if closed, it only asks to confirm.
- **Keyboard navigation** (with the panel focused):
  - `↑`/`↓` → move the cursor between sessions and the header controls (folder
    button on top, then `+`, then the model dropdown).
  - `→`/`←` → focus a session's icons (export/delete).
  - `Enter` → activate (resume the session, run an action, open the model
    dropdown, or start a new session / open the exports folder).
  - Inside the model dropdown: `Enter`/`↓` opens, `↑`/`↓` choose, `Enter` confirms
    and closes the list.
  - `Del` → open the delete dialog for the selected session.
  - In the confirmation dialog: `←`/`→` or `Tab` choose (Cancel/Delete),
    `Enter` confirms, `Esc` cancels.
  - `Esc` → close the panel (or clear the search when the search box is active).
- When deleting a session, its row shows **"Deleting…"** until the
  conversation disappears from the list.

## Structure

```
opencode.core/
├── manifest.json        # Metadata and widget schema for Omarchy
├── Panel.qml            # Panel UI and QML logic (includes ConfirmDialog)
├── collector.py         # Collects sessions, models and stats from opencode.db/CLI
└── bin/
    ├── omarchy-opencode-resume   # Resumes a session on the active workspace
    ├── omarchy-opencode-new      # Opens a new session (with optional model)
    ├── omarchy-opencode-check    # Reports whether a session is open or closed
    ├── omarchy-opencode-delete   # Closes (if applicable) and deletes a session
    ├── omarchy-opencode-export   # Exports the conversation to Markdown/JSON and opens the folder
    └── omarchy-opencode-exports  # Opens the exports folder
```

For maintainers: see [docs/TECHNICAL.md](docs/TECHNICAL.md) for the tech
reference, QML mechanics, and security notes.

## License

MIT
