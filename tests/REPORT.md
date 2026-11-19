# nullptr Workstation — test report

Last full verification: 2026-11-19, commit `26aa18e`,
[GitHub Actions run 44460301401](https://github.com/chrisaladams/NullPtrWorkstation/actions/runs/44460301401).
**131 checks passed, 0 failed** on a fresh installation of the ISO.

This is the first verified build of the **plain C station**: raylib, GBDK-2020, Emulicious,
VSCodium, Blender, the starter projects and the project commands are gone; clang is the default
compiler; AstroVim builds, runs and debugs any repository; Blockbench is on workspace 5.
Earlier builds (with the raylib/Game Boy layer) were verified at `b559437` 94/94, `1f76f16`
106/106, `e82775d` 116/116, `0c2fd8e` 123/123, `8ef03e4` 129/129 and `bf29a4e` 146/146.

## ISO

| | |
|---|---|
| File | `nullptr-workstation-amd64.iso`, 2.0 GB, hybrid (USB/DVD, UEFI + BIOS) |
| SHA-256 | `548b8b5e46a00dae49679e9cc51feebf3e983feee61d785d7614a425f7b7f04e` |
| Built by | `./build-iso.sh --docker` (live-build in `debian:trixie`) in GitHub Actions |
| Where | the `iso` artifact of the run above (not stored in the repository; kept 14 days) |
| Versions seen in the VM | Debian clang 19.1.7, lldb 19.1.7, GDB 16.3, Blockbench 5.2.2, Tiled 1.11, Neovim 0.12.6 |

## How it was verified

`.github/workflows/build-iso.yml` runs three stages; the evidence is in
[`tests/vm-results/`](vm-results/):

1. **Build** the ISO from this repository. The preflight checks every package name against
   the Debian 13 archive and every pinned download; every component is hash/commit checked.
2. **Install** it in a QEMU/KVM virtual machine with **UEFI** (OVMF), 8 GB RAM and a blank
   40 GB disk, with Debian's installer from the ISO. A **test-only** preseed
   (`tests/ci/ci-preseed.cfg`: test password, automatic partitioning, fixed hostname) is
   served over QEMU's network; it is never part of the ISO, which asks for the password and
   for partitioning confirmation.
3. **Use** the installed system like a person (`tests/ci/vm-test.sh`): type the login on
   **tty1**, wait for the graphical session, switch to tmux window 2 and run
   `tests/ci/guest-tests.sh` there: system checks, the workflow suite (with the AstroVim
   editor suite), AstroVim driven live in tmux window 1, and screenshots. Then log in on tty2
   and check that it stays a text console.

## Results

| Area | Result | Evidence |
|---|---|---|
| Installer, user `nullptr`, sudo asks for the password, no live packages left | **PASS** | `results.log`, `vm-00-tty1-login-prompt.png` |
| tty1 login → Xorg → i3 → fullscreen kitty → tmux `dev` (windows 1–5) → AstroVim dashboard | **PASS** | `vm-01-after-login.png`, `vm-01-editor-after-login.png` |
| clang is the default: `cc`/`c++` are clang, CMake identifies Clang | **PASS** | workflow suite |
| lldb-dap, GDB ≥ 16, gdb-multiarch, bear present | **PASS** | workflow suite |
| Removed: `build`, `run-game`, `debug-game`, `projects`, `new-*`, `gb-build`, `lcc`, `emulicious`, `codium`, `blender`, system raylib | **PASS** (none present) | workflow suite |
| A repository cloned with `git clone --recurse-submodules` builds with plain CMake | **PASS** | workflow suite |
| AstroVim, plain **CMake** repo: build (Ninja, `compile_commands.json`), clangd attached, F5 → **LLDB**: breakpoint, variable, step, continue | **PASS** | `tests/editor/` (editor suite) |
| AstroVim, plain **Make** repo: build through `bear` (`compile_commands.json`), clangd, F5 → LLDB | **PASS** | editor suite |
| AstroVim, repo with its own **`.vscode/launch.json`** (GDB): its configuration is used | **PASS** | editor suite |
| AstroVim, repo with its own **`.nvim.lua`**: its build command and GDB configuration are used | **PASS** | editor suite |
| The running AstroVim in tmux: `:NullptrBuild`, then `F9`/`F5` stops at the breakpoint (LLDB) | **PASS** ("debugger stopped at line 9") | `vm-03-debugger-breakpoint.png` |
| A program window opened from workspace 1 goes to `6: run` and is shown; closing it returns to the editor | **PASS** | workflow suite |
| Tools follow the project open in AstroVim; tmux status shows repository and branch | **PASS** | workflow suite |
| LibreSprite (ws 3), Firefox (ws 2, docs toolbar from the policy), Tiled (ws 4), Blockbench (ws 5): open on their workspace, no second window | **PASS** | `vm-04`, `vm-09`, `vm-08`, `vm-07` screenshots |
| Thunar floats on the current workspace, sidebar, thumbnails | **PASS** | `vm-10-file-manager.png` |
| `import-assets`: unpack, flatten, never overwrite, paths kept inside `assets/`, `CREDITS.md`, uses the repository you are in | **PASS** | workflow suite |
| Tiled exports a TMX map to JSON and CSV (checked cell by cell) | **PASS** | `tests/tiled/export-test.sh` |
| `github-login` configures git to use the GitHub CLI sign-in (dummy token, no real account) | **PASS** | guest tests |
| Login autostart rules (tty1 only, never SSH/tmux/nested), X failure leaves a working shell with hints | **PASS** | workflow suite |
| tty2 is a plain text console (recovery) | **PASS** | `vm-06-tty2-text-console.png` |

All 131 lines are in [`vm-results/results.log`](vm-results/results.log), and the complete
guest output (including each editor-suite report) is in [`vm-results/guest.log`](vm-results/guest.log).

## Not tested

| Item | Why |
|---|---|
| Drawing tablet (Huion Inspiroy H640P), Wi-Fi, battery, suspend/resume, Intel GPU, brightness/volume keys, screen lock | needs the X1 Carbon; nothing to test in a VM |
| `nullptr-update` removing the retired components on your laptop | checked in a dry run against a system that had them (it lists exactly the leftovers and asks); the real removal runs on your machine |
| Real GitHub sign-in through the browser | needs your account; the VM uses a dummy token |
| The GBA, SDL3, raylib and Game Boy examples in `docs/c-projects.md` | they need toolchains the workstation deliberately doesn't install; the mechanisms they use (`.nvim.lua` build/debug, `launch.json`, gdb-multiarch, clangd `--query-driver`) are what the editor suite tests |

## Defects found and fixed while testing this version

1. **LLDB 18 reported the wrong line** after a step followed by continue (intermittently line 9
   instead of 8). Found in the development container (Ubuntu, LLDB 18); LLDB 19 (Debian 13) was
   correct 5/5 and in every VM run. The installer now links the **newest** `lldb-dap` when
   several LLVM versions are installed.
2. **GDB 15 breakpoint race** reappeared in the development container (1 in ~7 runs of the
   launch.json case); GDB 16 in Debian 13 doesn't have it (all VM runs passed).
3. **Duplicate i3 startup line** from a config edit (the helper was started twice). Fixed.
4. **VM test harness issues** (not workstation defects), each fixed and re-run:
   - the check that reads the running editor's debugger line used `nvim --remote-expr`, whose
     answer goes to stderr and, inside tmux, comes wrapped in terminal escape codes; it now
     uses `nvim --headless --remote-expr` and polls (the screenshots showed the debugger at
     the breakpoint in every run);
   - the Debian installer in the test VM once took its hostname from the CI network's reverse
     DNS (`ip-10-0-2-15`), so the "login prompt" wait never matched; the test preseed now forces
     the hostname.

## Known test-environment artifacts

- cppreference.com showed a Cloudflare bot check to the VM in the Firefox screenshot; the
  toolbar bookmarks (what is tested) are correct.
- The build screenshot shows the project open with clangd attached, not the build output: the
  small test project builds in under 3 seconds and the build split closes on success.
- ALSA warnings in logs: the VMs have no sound card.

## Still to verify on the X1 Carbon

```bash
/usr/local/src/nullptr-workstation/tests/workflow-tests.sh
tablet-info && tablet-setup        # with the Huion H640P plugged in
```

Plus by hand: Wi-Fi (`nmtui`), battery in the bar, lid suspend/resume, `Super+L`, and the
brightness and volume keys.
