# VM verification: 94 passed, 0 failed

```
RESULT PASS unattended installation finished (debian-installer, UEFI, 40 GB virtio disk)
RESULT PASS installed system boots to a login prompt
RESULT PASS running as user nullptr
RESULT PASS home is /home/nullptr
RESULT PASS nullptr is in group sudo
RESULT PASS sudo asks for a password (no NOPASSWD)
RESULT PASS no live-boot/live-config left in the installed system
RESULT PASS ~/Projects starter projects present
RESULT PASS ~/Projects owned by nullptr and writable
RESULT PASS NetworkManager running (nmtui available)
RESULT PASS TLP enabled, power-profiles-daemon absent
RESULT PASS PipeWire running for the user
RESULT PASS Xorg running on tty1
RESULT PASS i3 running
RESULT PASS kitty (nullptr-dev) running
RESULT PASS tmux session dev with windows 1-5
RESULT PASS AstroVim running in window 1
RESULT PASS AstroVim shows the dashboard
RESULT PASS kitty is fullscreen on workspace 1
RESULT PASS command gcc
RESULT PASS command clang
RESULT PASS command clangd
RESULT PASS command clang-format
RESULT PASS command clang-tidy
RESULT PASS command gdb
RESULT PASS command cmake
RESULT PASS command ninja
RESULT PASS command make
RESULT PASS command pkg-config
RESULT PASS command git
RESULT PASS command nvim
RESULT PASS command lazygit
RESULT PASS command tree-sitter
RESULT PASS command libresprite
RESULT PASS command emulicious
RESULT PASS command codium
RESULT PASS command java
RESULT PASS GDB version >= 16
RESULT PASS raylib 5.5 via pkg-config
RESULT PASS GBDK 4.5.0 lcc
RESULT PASS Emulicious installed
RESULT PASS JetBrainsMono Nerd Font installed
RESULT PASS AstroNvim plugins pre-installed (offline)
RESULT PASS treesitter parsers pre-compiled
RESULT PASS workflow: new-raylib creates project
RESULT PASS workflow: new-raylib project builds
RESULT PASS workflow: raylib Debug binary exists
RESULT PASS workflow: compile_commands.json linked
RESULT PASS workflow: build --release works
RESULT PASS workflow: Release binary exists
RESULT PASS workflow: new-raylib refuses existing name
RESULT PASS workflow: existing project left untouched
RESULT PASS workflow: invalid project name rejected
RESULT PASS workflow: new-gameboy creates project
RESULT PASS workflow: gb-build builds the ROM
RESULT PASS workflow: Debug ROM + .cdb exist
RESULT PASS workflow: .cdb has C line records
RESULT PASS workflow: ROM header title set
RESULT PASS workflow: gb-build --release
RESULT PASS workflow: gb-clean removes build/
RESULT PASS workflow: gb-build rejects raylib project
RESULT PASS workflow: new projects are git repositories
RESULT PASS workflow: projects use raylib-hello
RESULT PASS workflow: build (from ~) uses active raylib project
RESULT PASS workflow: projects use gameboy-hello
RESULT PASS workflow: build (from ~) follows switch to Game Boy
RESULT PASS workflow: conflict (cwd A, active B) refuses instead of guessing
RESULT PASS workflow: explicit project name wins
RESULT PASS workflow: projects list shows active (*)
RESULT PASS workflow: AstroVim file switch updates active project
RESULT PASS workflow: shell build follows AstroVim's project
RESULT PASS workflow: autostart: local login on tty1 starts X
RESULT PASS workflow: autostart: tty2 stays text (recovery console)
RESULT PASS workflow: autostart: never for SSH
RESULT PASS workflow: autostart: never inside tmux
RESULT PASS workflow: autostart: never for nested shells
RESULT PASS workflow: autostart: not when X already running
RESULT PASS workflow: autostart: ~/.config/nullptr/no-autostart disables X
RESULT PASS workflow: X failure falls back to text console with recovery hints
RESULT PASS workflow: GBDK_HOME exported by /etc/profile.d
RESULT PASS workflow: lcc on PATH for login shells
RESULT PASS workflow: tablet-info runs without a tablet
RESULT PASS workflow: keys prints the cheat sheet
RESULT PASS workflow: helpme prints the guide
RESULT PASS workflow: art launches LibreSprite
RESULT PASS workflow: LibreSprite window appears
RESULT PASS workflow: LibreSprite lands on workspace 2
RESULT PASS workflow: art again focuses, no duplicate
RESULT PASS workflow: tablet-setup handles no tablet gracefully
RESULT PASS raylib C breakpoint, variables, step, continue (GDB + nvim-dap)
RESULT PASS Game Boy C breakpoint, variables, step, continue (Emulicious DAP)
RESULT PASS Game Boy C breakpoint via AstroVim's nvim-dap (Emulicious adapter)
RESULT PASS Emulicious window opens with the ROM
RESULT PASS tty2 login stays a text console (no second X server)
```
