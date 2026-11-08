# nullptr Workstation — test report

Last full verification: 2026-11-08, commit `8ef03e4`,
[GitHub Actions run 42428608367](https://github.com/chrisaladams/NullPtrWorkstation/actions/runs/42428608367).
**129 checks passed, 0 failed** on a fresh installation of the ISO. Earlier verified builds:
`b559437` 94/94, `1f76f16` 106/106, `e82775d` 116/116, `0c2fd8e` 123/123. This run adds Firefox
ESR on workspace 2 (no second window; the docs bookmarks toolbar read back from a fresh profile)
and moves the other workspaces up one: 3 libresprite, 4 tiled, 5 blender, 6 game, 7 tools.

## ISO

| | |
|---|---|
| File | `nullptr-workstation-amd64.iso`, 2.2 GB, hybrid (USB/DVD, UEFI + BIOS) |
| SHA-256 | `5d933637cec4f6e51caeed3eecc7fe20dec0e9cfb00b40d5ac89306f857d642d` |
| Built by | `./build-iso.sh --docker` (live-build in `debian:trixie`) in GitHub Actions |
| Where | the `iso` artifact of the run above (not stored in the repository) |

## How it was verified

`.github/workflows/build-iso.yml` runs three stages; the evidence is in
[`tests/vm-results/`](vm-results/):

1. **Build** the ISO from this repository. The preflight checks every package name against
   the Debian 13 archive and every pinned download. All components install with
   hash/commit checks.
2. **Install** it in a QEMU/KVM virtual machine with **UEFI** (OVMF), 8 GB RAM and a blank
   40 GB virtio disk, using Debian's installer from the ISO. To run unattended, the test
   serves a **test-only** preseed (`tests/ci/ci-preseed.cfg`: test password, automatic
   partitioning) over QEMU's virtual network. It is never part of the ISO; the ISO itself
   asks for the password and for partitioning confirmation.
3. **Use** the installed system like a person (`tests/ci/vm-test.sh`): wait for the login
   prompt, type `nullptr` and the password on **tty1** with the virtual keyboard, wait for the
   graphical session, switch to tmux window 2 with `Ctrl+b 2`, and run
   `tests/ci/guest-tests.sh` there. That runs system checks, the workflow suite, the
   raylib and Game Boy debugger tests, and screenshots of the VM screen. Then `Ctrl+Alt+F2`,
   log in on tty2, and check that it stays a text console.

## Non-negotiable tests

| # | Test | Result | Evidence |
|---|---|---|---|
| 1 | ISO boots and installer works | **PASS** | debian-installer from the ISO installed the system on a UEFI VM (unattended test preseed) and it booted to a login prompt (`vm-results/screens/vm-00-tty1-login-prompt.png`). The *interactive* installer screens (password prompts, partitioning confirmation) were not clicked through by a person. |
| 2 | User `nullptr` is created and can set a password | **PASS** | Installer-created user `nullptr`, home `/home/nullptr`, in group `sudo`; `sudo` asks for the password (no NOPASSWD); the password set at install time works at the tty1 and tty2 logins. |
| 3 | Graphical session opens after authenticated login | **PASS** | Typed login on tty1 → Xorg on tty1 → i3 → kitty (`nullptr-dev`, fullscreen on workspace 1) → tmux `dev` with windows 1–5 → AstroVim dashboard (`vm-01-after-login.png`). |
| 4 | AstroVim starts successfully inside tmux | **PASS** | AstroVim listening in tmux window 1 and showing the dashboard; plugins and parsers pre-installed (works offline). |
| 5 | File explorer and project selector work | **PASS** | Workflow suite (project selection, AstroVim buffer switches update the active project) plus the dashboard/picker checks from the development tests. |
| 6 | Both Hello World projects compile | **PASS** | Starter and newly created projects build (raylib Debug/Release with `compile_commands.json`; GBDK Debug/Release ROMs with `.cdb` C line records). |
| 7 | raylib window opens | **PASS** | `run-game` on the installed system (`vm-02-raylib-running.png`). |
| 8 | Game Boy ROM runs in Emulicious | **PASS** | `gb-run` opens Emulicious with the ROM (`vm-03-gameboy-emulicious.png`). |
| 9 | GDB C breakpoint works for raylib | **PASS** | GDB 16.3 through AstroVim's nvim-dap config: breakpoint on `frameCount++;`, `frameCount` read, step, continue (`tests/dap/raylib-dap-test.sh`). |
| 10 | C source-level debugging for GBDK | **PASS** | Emulicious debug adapter, both through a raw DAP client and **through AstroVim's nvim-dap config**: breakpoint on `keys = joypad();` verified and hit, `keys` read (`unsigned char`, Locals), step → next line, continue → stops again. Backend: **Emulicious DAP via nvim-dap** (primary path). |
| 11 | LibreSprite launches | **PASS** | Workspace `3: libresprite`, no duplicates (`vm-04-libresprite.png`). Firefox on `2: firefox` (`vm-09-firefox-workspace.png`), Tiled on `4: tiled` (`vm-08-tiled-workspace.png`) and Blender on `5: blender`; a Blender-exported `.glb` loads in raylib (`vm-07-blender-workspace.png`). |
| 12 | Build/run commands select the correct project | **PASS** | Workflow suite on the installed system, including the refuse-on-conflict case. |
| 13 | TTY recovery if X11 fails | **PASS** | tty2 login is a plain text console with no second X server (`vm-06-tty2-text-console.png`). A failing `startx` on tty1 leaves a working shell with recovery hints (simulated failure, workflow suite). |

All 129 lines are in [`vm-results/results.log`](vm-results/results.log), and the complete
guest output is in [`vm-results/guest.log`](vm-results/guest.log).

## Hardware-dependent (no matching hardware)

| Test | Result |
|---|---|
| Drawing tablet (**Huion Inspiroy H640P**): stylus input, mapping, pen buttons, express keys, pressure | **NOT TESTED** on hardware (no tablet; the VM kernel lacks `uinput`, so no virtual one either). Support confirmed in primary sources (Linux 6.12 `hid-uclogic`, libwacom `huion-h640p.tablet`, xf86-input-wacom). `tests/tablet/simulate-h640p.sh` checks every command `tablet-setup` issues against simulated wacom and libinput drivers: **15/15 PASS**. |
| Battery display | **NOT TESTED** (no battery; i3status/tmux segments are hidden when there is none) |
| Suspend/resume, lid | **NOT TESTED** |
| Wi-Fi (NetworkManager, nmtui, iwlwifi firmware) | **NOT TESTED** |
| Intel GPU (i915/iris), brightness keys, audio keys | **NOT TESTED** |
| Screen lock (`Super+L`, i3lock, PAM) | **NOT TESTED** (not exercised in the VM test) |

## Other verified items

| Item | Result |
|---|---|
| Upstream installer: every SHA-256 and git commit checked (Neovim 0.12.6, GBDK 4.5.0, lazygit 0.66.2, Nerd Font 3.5.1, tree-sitter 0.27.1, raylib 5.5) | PASS (`logs/host-install-upstream.log`) |
| LibreSprite v1.3 | rejected: needs CMake ≥ 4.1, but Debian 13 has 3.31. v1.2 builds. |
| AstroNvim: 49 plugins installed exactly at `lazy-lock.json` commits | PASS |
| 23 treesitter parsers compiled from git at pinned revisions (no GitHub archive downloads) | PASS (`logs/host-install-workstation.log`) |
| clangd attaches to C files; clang-format via none-ls; treesitter highlight active | PASS |
| clangd understands GBDK headers (`.clangd` in the Game Boy template), 0 errors | PASS |
| Documented key mappings exist in AstroNvim v6.1.1 | PASS (Gitsigns keys are buffer-local and appear in tracked files) |
| tmux session survives closing kitty and killing X; reattach creates no duplicate | PASS |
| `new-raylib` / `new-gameboy`: create, build, refuse existing names (files untouched), reject unsafe names | PASS |
| Workflow suite `tests/workflow-tests.sh` | **45/45 PASS**, twice in a row |
| shellcheck (all shell scripts), Lua syntax, Python compile | PASS |
| Package names in `packages/*.list` exist in trixie | PASS (build preflight against the Debian 13 archive) |
| `lb config` / `lb build` with `config/live/auto/config` | PASS (Debian 13 live-build in CI) |

## Defects found and fixed during testing

1. **Game hangs at start when debugging.** GLFW blocks in `InitWindow()` until the window is
   visible, and the debugged game opened behind the fullscreen editor. Fix: nvim-dap listeners
   show workspace 3 while the program runs and return to the editor when it stops.
2. **GDB 15 breakpoint race.** GDB 15 starts the inferior on `launch`, so nvim-dap's breakpoints
   arrive late (`notStopped`). GDB 16 (Debian 13) defers `launch` until `configurationDone`.
   Verified on 16.3; documented as a requirement.
3. **Dashboard upper-case keys** (`P`) ran Vim's paste command. Fix: aliases are created
   after Snacks builds its keymaps (`User SnacksDashboardUpdatePost`).
4. **clangd errors on GBDK headers** (SDCC keywords). Fixed in the template `.clangd`.
5. **Treesitter parser installs** failed when GitHub archive downloads are unavailable.
   Parsers now come from git at the exact pinned revisions.
6. **Workspace switching broke after restarting X** while tmux kept running: tmux kept the
   dead i3's `I3SOCK`, so `run-game` couldn't switch to workspace 3 and the game hung behind
   the editor. All i3 calls now ignore `I3SOCK` and find the live socket through X (verified
   in exactly that state).
7. The in-editor build split stopped following output once focus returned to the code (so
   `✔ Built` was off-screen), and could fail to reopen after a plugin reload (stale buffer
   name). Both fixed.
8. **Found by installing the ISO in a VM** (first run: 83/93):
   - `projects use`/`new-raylib` exited non-zero on a brand-new system (no project history yet + `pipefail`).
   - The installer kept `live-boot`/`live-config`, and **removed VSCodium** (debian-installer drops packages added after live-build's main pass). Live packages are now a live-only list; VSCodium ships via `packages.chroot`.
   - `tests/workflow-tests.sh` was not executable in git.
9. **Emulicious blocked the debugger on first start** with a modal "Update Behaviour" dialog.
   The workstation now ships `Emulicious.ini` with `Update=0` (never check: no dialog, and it
   stays on the tested version; update with `sudo nullptr-install-emulicious`).
10. LuaJIT syntax error (`//`) in the help module; `.xinitrc` sourced a file twice; Emulicious
   settings would have been written into `/opt`. All fixed.

## Known test-environment artifacts (not workstation defects)

- During development (before the VM test existed), kitty stopped repainting after being
  unmapped under Xvfb + llvmpipe, so `screenshots/03-…` was rendered from the live tmux pane.
- ALSA warnings in logs: the VMs have no sound card.

## Still to verify on the X1 Carbon

```bash
/usr/local/src/nullptr-workstation/tests/workflow-tests.sh
/usr/local/src/nullptr-workstation/tests/dap/raylib-dap-test.sh
/usr/local/src/nullptr-workstation/tests/dap/gameboy-dap-test.sh
tablet-info && tablet-setup        # with the Huion H640P plugged in
```

Plus by hand: Wi-Fi (`nmtui`), battery in the bar, lid suspend/resume, `Super+L`, and the
brightness and volume keys.
