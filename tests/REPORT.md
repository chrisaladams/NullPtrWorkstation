# nullptr Workstation — test report

Date: 2026-11-04. Commit: see `git log`.

## Test environment

Read this first. It determines what could and could not be tested.

| | |
|---|---|
| Machine | cloud VM, 4 vCPU, 15 GB RAM, **no KVM**, **no GPU**, no sound card, no USB devices |
| Host OS | Ubuntu 24.04 (the sandbox's OS, not the target) |
| Display | Xvfb 1920×1080 + Mesa llvmpipe (software OpenGL 4.5) |
| Debian 13 userland | `mcr.microsoft.com/devcontainers/cpp:trixie` container: Debian **13.7**, Debian's own **GDB 16.3-1** and CMake 3.31.6 |
| Network policy | **blocked:** `deb.debian.org`, `security.debian.org`, `salsa/sources/packages.debian.org`, all other Debian mirrors, **`emulicious.net`**, `open-vsx.org`, GitHub source-archive downloads. **Allowed:** git clones of public GitHub repos, GitHub release assets, Ubuntu archive, Docker Hub/MCR, PyPI, npm |

Consequences:

1. **The ISO could not be built here.** live-build needs a Debian archive and every Debian
   mirror was blocked. **No `nullptr-workstation-amd64.iso` and no checksum exist yet.**
   `build-iso.sh` must be run on a machine with normal internet access.
2. **Emulicious could not be downloaded (HTTP 403)**, so nothing involving Emulicious ran.
3. Everything else was tested by installing the workstation layer (the same scripts the ISO
   hooks run) onto the sandbox, creating a real `nullptr` user from the generated `/etc/skel`,
   and running the real session chain under Xvfb. Debian-13-specific behaviour (GDB 16.3) was
   tested in a Debian 13.7 container.

## Non-negotiable tests

| # | Test | Result | Evidence / notes |
|---|---|---|---|
| 1 | ISO boots and installer works | **NOT TESTED** | ISO could not be built (Debian mirrors blocked). `tests/qemu/smoke-test.sh` and `tests/qemu/install-test.sh` are ready for the first build. |
| 2 | User `nullptr` is created and can set a password | **NOT TESTED** (installer) | `installer/preseed.cfg` fixes the username and leaves both password questions unpreseeded. Not executed in d-i. The `nullptr` account itself, created from the generated `/etc/skel`, was used for all tests below. |
| 3 | Graphical session opens after authenticated login | **PARTIAL** | PASS: i3 → `dev-terminal` → kitty (fullscreen, ws 1) → `dev` → tmux `dev` with 5 windows → AstroVim dashboard (`screenshots/01-session-dashboard.png`). PASS: the `.bash_profile` autostart decision with simulated ttys (7 cases, `results/workflow-tests.txt`). NOT TESTED: a real getty login on a VT. |
| 4 | AstroVim starts successfully inside tmux | **PASS** | Dashboard renders as specified, no startup errors. All 7 dashboard actions (P F N E R H Q, upper and lower case) and the project shortcuts 1/2 were exercised. |
| 5 | File explorer and project selector work | **PASS** | Neo-tree opens with the project, Oil and pickers are mapped, `[P]`/`Space m p`/`projects` pick a project and update the active project and tmux status. |
| 6 | Both Hello World projects compile | **PASS** | raylib-hello: CMake + Ninja, Debug and Release, `compile_commands.json`. gameboy-hello: GBDK 4.5.0 `lcc -debug`, Debug and Release ROM, `.cdb` with C line records. |
| 7 | raylib window opens | **PASS** | `Space m r` from AstroVim, "Hello, raylib!" at 60 FPS on workspace 3 (`screenshots/02-raylib-hello-running.png`). |
| 8 | Game Boy ROM runs in Emulicious | **NOT TESTED** | Emulicious blocked (403). The ROM **does** boot and run (text, A-button counter) in **mGBA**, a different emulator (`screenshots/04-gameboy-hello-rom-mgba.png`). `gb-run` correctly reports that Emulicious is missing. |
| 9 | GDB C breakpoint works for raylib | **PASS** | Debian 13.7 / GDB 16.3 / nvim-dap / the workstation's own AstroNvim config: stopped at `main.c:19` (reason `breakpoint`), `frameCount = 0 (int, Locals)`, step → line 22, continue → line 19 again (`results/raylib-nvim-dap-gdb16-debian13.json`, `screenshots/03-raylib-gdb-breakpoint-astrovim.png`). |
| 10 | C source-level debugging for GBDK | **NOT TESTED** | Needs Emulicious. Configured: nvim-dap `emulicious` server adapter (design taken from the Emulicious Debugger extension's source), VSCodium + extension fallback, Emulicious's built-in debugger. Run `tests/dap/gameboy-dap-test.sh` on the machine. |
| 11 | LibreSprite launches | **PASS** | LibreSprite 1.2 built from source, opens on workspace `2: art`, and a second `art` focuses it instead of starting a duplicate (`screenshots/05-libresprite-workspace2.png`). |
| 12 | Build/run commands select the correct project | **PASS** | 9 tests: active project from `projects use`, from AstroVim buffer switches, explicit names. A cwd/active conflict **refuses** (exit 2) instead of guessing. |
| 13 | TTY recovery if X11 fails | **PASS (simulated)** | With a failing `startx`, the tty1 login ends in a working shell with recovery instructions. tty2–6, SSH, tmux and nested shells never start X. `no-autostart` file and `nullptr.nox` boot flag exist. Real VT: NOT TESTED. |

## Hardware-dependent (no matching hardware)

| Test | Result |
|---|---|
| Drawing tablet (**Huion Inspiroy H640P**): stylus input, mapping, pen buttons, express keys, pressure | **NOT TESTED** on hardware (no tablet; the VM kernel lacks `uinput`, so no virtual one either). Support confirmed in primary sources (Linux 6.12 `hid-uclogic`, libwacom `huion-h640p.tablet`, xf86-input-wacom). `tests/tablet/simulate-h640p.sh` checks every command `tablet-setup` issues against simulated wacom and libinput drivers: **15/15 PASS**. |
| Battery display | **NOT TESTED** (no battery; i3status/tmux segments are hidden when there is none) |
| Suspend/resume, lid | **NOT TESTED** |
| Wi-Fi (NetworkManager, nmtui, iwlwifi firmware) | **NOT TESTED** |
| Intel GPU (i915/iris), brightness keys, audio keys | **NOT TESTED** |
| Screen lock (`Super+L`, i3lock, PAM) | **NOT TESTED** (needs a password and a real session; xss-lock needs logind, which the sandbox lacks) |

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
| Package names in `packages/*.list` exist in trixie | **NOT VERIFIED** (no archive access). `build-iso.sh` checks them all before building. |
| `lb config` accepts the options in `config/live/auto/config` | **NOT VERIFIED** (no trixie live-build available) |

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
8. LuaJIT syntax error (`//`) in the help module; `.xinitrc` sourced a file twice; Emulicious
   settings would have been written into `/opt`. All fixed.

## Known test-environment artifacts (not workstation defects)

- kitty stopped repainting after its window was unmapped/remapped under Xvfb + llvmpipe,
  so screenshot 03 was rendered from the live tmux pane (`tmux capture-pane -e` →
  `tests/tools/ansi2html.py` → Chromium). The text and colours are exactly what was on the
  pane.
- ALSA errors in logs: the VM has no sound card.

## How to finish verification on real hardware

```bash
sudo ./build-iso.sh                       # on a networked Debian 13 machine
tests/qemu/smoke-test.sh out/nullptr-workstation-amd64.iso
tests/qemu/install-test.sh out/nullptr-workstation-amd64.iso   # interactive install
# on the installed laptop, in the graphical session:
/usr/local/src/nullptr-workstation/tests/workflow-tests.sh
/usr/local/src/nullptr-workstation/tests/dap/raylib-dap-test.sh
/usr/local/src/nullptr-workstation/tests/dap/gameboy-dap-test.sh
```
