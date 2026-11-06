# Updating and reinstalling from GitHub

The workstation is defined entirely by this repository
([chrisaladams/NullPtrWorkstation](https://github.com/chrisaladams/NullPtrWorkstation)).
There are two ways to bring a laptop up to date with it.

| | `nullptr-update` | Fresh install from a new ISO |
|---|---|---|
| Keeps your files and projects | yes | no: the disk is wiped |
| Time | a minute (longer if a pinned tool changed) | ~1 hour plus backup/restore |
| Use for | normal updates | a broken system, a new laptop, starting clean |

## One-time setup

1. **GitHub access over SSH**: the repository is private (steps in the git section of
   `docs/c-projects.md`, or quickly):
   ```bash
   ssh-keygen -t ed25519 -C "x1-carbon"
   ```
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   Add the printed key on github.com → Settings → SSH and GPG keys, then check:
   ```bash
   ssh -T git@github.com
   ```
2. **First update.** On a system installed from an ISO older than `nullptr-update` itself,
   clone once and run it from the clone:
   ```bash
   git clone git@github.com:chrisaladams/NullPtrWorkstation.git ~/src/NullPtrWorkstation
   ```
   ```bash
   ~/src/NullPtrWorkstation/scripts/bin/nullptr-update
   ```
   From then on, `nullptr-update` is a normal command.

## `nullptr-update`

```bash
nullptr-update --dry-run
```
```bash
nullptr-update
```

`--dry-run` shows what would change; the second command updates. Then log out
(`Super+Shift+E`) and in again.

What it does, in order:

1. **Code:** fetches `main` into `~/src/NullPtrWorkstation` (fast-forward only; it stops if
   you have uncommitted edits there).
2. **Debian packages:** installs packages listed in `packages/*.list` that are missing (e.g.
   Blender after it was added). If one can't be installed, it says so and continues.
3. **Pinned tools:** compares the repo's `versions.lock` with the installed one and
   reinstalls only what changed (Neovim, GBDK, raylib, LibreSprite, lazygit, Emulicious, …).
4. **System files:** commands, templates, docs and `/etc` configuration.
5. **Your configuration:** i3, i3status, kitty, tmux, lazygit, btop, AstroVim, `.bash_profile`,
   `.xinitrc`, `.Xresources`. Only files that differ are replaced, and the previous version of
   each goes to `~/.local/state/nullptr/backups/DATE-TIME/` first. Skip this step with
   `--no-dotfiles` if you customise those files yourself.
6. **AstroVim plugins:** synced to the versions pinned in `lazy-lock.json`.

Never touched: `~/Projects` and anything else in your home that the repository doesn't
manage. The installed commit is recorded in `/usr/local/share/nullptr/INSTALLED-COMMIT`.

**Undo a configuration change:** copy the file back from the backup folder, e.g.
```bash
cp ~/.local/state/nullptr/backups/20261106-002544/.config/i3/config ~/.config/i3/config
```

**Go back to an older version** of the whole workstation (commits are listed on GitHub or with
`git -C ~/src/NullPtrWorkstation log --oneline`):
```bash
nullptr-update --at 2e5e61a
```
A later plain `nullptr-update` returns to the latest version.

## Fresh install from a new ISO

1. **Save your work first.** The installer erases the disk. Push your projects to GitHub, or
   copy `~/Projects` to a USB stick.
2. **Get the ISO GitHub built and tested.** Sign in to GitHub once (`gh auth login`, choose
   "Login with a web browser", approve the code on your phone), then:
   ```bash
   nullptr-iso
   ```
   That downloads the ISO from the newest GitHub build that **passed the virtual-machine
   install test** and checks its SHA-256. `nullptr-iso --build` starts a fresh build first and
   waits for it (~40 min). Without the laptop: GitHub → Actions → "Build, install and verify
   the ISO" → a green run → Artifacts → `iso`.
3. **Write it to a USB stick** (find the stick with `lsblk`; this erases it):
   ```bash
   nullptr-iso --write /dev/sdX
   ```
   It refuses the laptop's own disk, partitions and mounted disks, and asks you to retype the
   device name before writing.
4. **Install:** boot from the stick (F12) and follow [installation.md](installation.md).
5. **Restore** your projects into `~/Projects`.

GitHub keeps each build's ISO for 14 days; after that `nullptr-iso` says so, and
`nullptr-iso --build` makes a new one.
