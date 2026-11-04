# tmux for beginners

tmux keeps your terminal programs running in a **session** that survives closing kitty, leaving
the graphical session, or a broken X server. The workstation's session is named **`dev`**.

## The prefix: `Ctrl+b`

Every tmux shortcut is **two steps**: press `Ctrl+b`, release both keys, then press the
command key. "`Ctrl+b 2`" means `Ctrl+b`, release, `2`.

## Windows (the tabs in the bottom bar)

| Window | Opens with | Contents |
|---|---|---|
| 1 | `Ctrl+b 1` | AstroVim (quitting it shows *[Enter] reopen / [s] shell*; the window stays) |
| 2 | `Ctrl+b 2` | build terminal: `build`, `run-game`, `gb-build` … |
| 3 | `Ctrl+b 3` | LazyGit for the active project (quitting offers a restart) |
| 4 | `Ctrl+b 4` | a spare shell |
| 5 | `Ctrl+b 5` | btop system monitor |

`Ctrl+b n` / `Ctrl+b p` go to the next/previous window. `Ctrl+b c` creates a new one, and
`exit` closes it.

## Panes (splitting a window)

| Keys | Action |
|---|---|
| `Ctrl+b \|` (or `%`) | split left/right |
| `Ctrl+b -` (or `"`) | split top/bottom |
| `Ctrl+b` + arrow | move to the pane in that direction |
| `Ctrl+b z` | zoom the current pane to full size and back |
| `Ctrl+b x` | close the pane (asks first) |

The mouse also works: click a pane to focus it, drag a border to resize.

## Detach and attach

| Keys / command | Action |
|---|---|
| `Ctrl+b d` | **detach**: the session keeps running in the background |
| `dev` | **attach** (creates the session if it doesn't exist; never nests inside tmux) |
| `tmux ls` | list sessions |

Closing kitty only detaches, so everything inside keeps running. Run `dev` or press
`Super+Shift+Enter` to get back to it.

## Scrolling and copying

`Ctrl+b [` enters scroll mode (arrows, PgUp/PgDn, `/` to search, `q` to leave). The mouse
wheel scrolls too. Selecting text with the mouse copies it to tmux's buffer, and tmux forwards
it to kitty and the system clipboard (`set-clipboard on`, OSC 52). Paste with `Ctrl+Shift+V`
in kitty, or `Ctrl+b ]` inside tmux.

## Help

`Ctrl+b ?` opens the workstation cheat sheet. `Ctrl+b P` opens the project picker.
