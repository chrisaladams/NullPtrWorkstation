# First-use tutorial

Also available on the workstation: `helpme tutorial`, or `H` on the AstroVim dashboard.

```text
nullptr Workstation — first-use tutorial (about 15 minutes)    (q to close)
==========================================================================

 1. Sign in to GitHub (once)
    Ctrl+b 2 (a terminal), type  github-login  and follow it: Firefox opens
    GitHub, you sign in with Google and enter the code it shows.
    Ctrl+b 1 brings you back to AstroVim.

 2. Get a project
    On the dashboard press  G  (or Space m g) and type a repository,
    e.g.  yourname/pong  or any git URL. It is cloned into ~/Projects with
    its submodules and opened. Your own new one: in a terminal
    mkdir ~/Projects/pong && cd ~/Projects/pong && git init, write a
    CMakeLists.txt (or Makefile) and main.c, then  code .

 3. Browse and edit files
    Space e        toggles the explorer. Move with the arrow keys, Enter opens.
    Space f f      type part of a file name and press Enter.
    i  types (Insert mode),  Esc  goes back,  :w  saves.

 4. Build
    Space m b   — a terminal opens at the bottom: CMake + Ninja (Debug) or
    make. Errors? Space x x lists them; Enter jumps to the line.
    Close the build output with  q  (in that window).
    clangd now knows the project's flags (compile_commands.json): K shows
    documentation, g d jumps to a definition.

 5. Run
    Space m r   — a program with a window opens on workspace 6; closing it
    brings you back here. A terminal program prints in the split below.

 6. Debug
    Put the cursor on a line inside a loop and press F9 (red dot).
    Press F5 (or Space m d). It builds, starts the program with LLDB and
    stops on that line with the debugger panels: variables, call stack.
    F10 = next line, F11 = step into, F5 = continue, Shift+F5 = stop.

 7. Teach a project something (optional)
    Space m i shows what AstroVim detected. If a project needs another
    build command, an emulator or a different debugger, put a .nvim.lua or
    .vscode/launch.json in it (helpme, and docs/c-projects.md for GBA,
    SDL3, raylib and Game Boy examples). AstroVim itself never changes.

 8. Commit and push
    Ctrl+b 3 (LazyGit): Space stages a file, c commits, P pushes.

 9. Art and assets
    Super+A LibreSprite, Super+T Tiled, Super+B Blockbench, Super+E files.
    import-assets ~/Downloads/pack.zip unpacks an itch.io pack into the
    project's assets/ and adds the credit line.

10. Switch projects
    Space m p (or the dashboard's numbers). The tmux status bar shows the
    repository and branch you are in.

 Next steps: keys (all shortcuts) · helpme · docs in /usr/local/share/nullptr/docs
```

## The beginner guide (`helpme`)

```text
nullptr Workstation — beginner guide                           (q to close)
==========================================================================

  helpme tutorial   10-step first-use tutorial      keys   all shortcuts
  helpme recovery   what to do if graphics fail

 How the screen is organised
 --------------------------------------------------------------------------
  After you log in on the first console, i3 starts and opens ONE fullscreen
  terminal (kitty) on workspace 1. Inside it runs tmux, a "terminal window
  manager" with a persistent session called  dev :

     Ctrl+b 1  editor   AstroVim (Neovim) — where you write code
     Ctrl+b 2  build    a shell for build / run commands
     Ctrl+b 3  lazygit  Git with a friendly UI
     Ctrl+b 4  shell    a spare shell
     Ctrl+b 5  btop     CPU / memory / processes

  tmux keeps running if you close kitty or leave the graphical session.
  Type  dev  in any terminal to get back to it.  Ctrl+b d  detaches.

  Super+2 shows Firefox (web), Super+3 LibreSprite (art), Super+4 Tiled
  (tiles), Super+5 Blockbench (3d), Super+6 the program you run, Super+7 is
  for anything else.
  A workspace is dark until its program runs: switching never starts
  anything. Super+W (Firefox), Super+A (LibreSprite), Super+T (Tiled) and
  Super+B (Blockbench) start the program, or jump to it if it is open.
  A program with a window that you start from the editor or its terminals
  opens on workspace 6; when it closes you are back in the editor.
  Super+1 brings you back to the editor.

 Projects
 --------------------------------------------------------------------------
  A project is a folder in ~/Projects, usually a git repository. There
  are no templates: you set up CMake or Make the way you want.
     Space m g    clone from GitHub (owner/repo or URL, with submodules)
     Space m p    open a project          (or the dashboard: P, G, 1-9)
     Space m b    build: CMake (Ninja, Debug) or Make, detected
     Space m r    build + run             Space m d / F5   build + debug
     Space m i    how this project is built and debugged
  A project can change all of that from its own files:
     .vscode/launch.json   debug configurations (LLDB or GDB)
     .nvim.lua             return { build = "...", run = "...", debug = {...} }
  clang is the default compiler (cc, c++, CMake, make).
  Details and examples (raylib/SDL3 in the project, GBA, Game Boy):
     /usr/local/share/nullptr/docs/c-projects.md

 Commands
 --------------------------------------------------------------------------
  dev                 attach the tmux workspace (creates it if needed)
  code PATH           open a file or folder in AstroVim
  web [URL]           Firefox on workspace 2 (C docs bookmarks in its toolbar)
  files [DIR]         file manager over the current workspace (Super+E)
  import-assets ZIP   unpack an itch.io pack into assets/ + CREDITS.md
  art [FILE]          LibreSprite on workspace 3
  tiles [FILE.tmx]    Tiled map editor on workspace 4
  3d [FILE.bbmodel]   Blockbench on workspace 5 (export .glb / .obj)
  gh repo clone owner/repo ~/Projects/repo     clone in a terminal
  tablet-info  tablet-setup                     drawing tablets
  nmtui               Wi-Fi and network settings (text UI)
  keys                shortcut cheat sheet

 Getting unstuck in AstroVim
 --------------------------------------------------------------------------
  Press Esc a couple of times, then type :q and Enter to close a window.
  Lost? Space h goes to the dashboard. Space ? opens the cheat sheet.
  Typed something wrong? u undoes it.

 System
 --------------------------------------------------------------------------
  GitHub:    github-login     (once: sign in with Google in the browser)
  Updates:   nullptr-update   (workstation from GitHub; --dry-run first)
  Reinstall: nullptr-iso      (GitHub-built ISO; --write /dev/sdX for a USB stick)
             sudo apt update && sudo apt upgrade   (Debian security updates)
  Wi-Fi:     nmtui → "Activate a connection"
  Volume:    the laptop's volume keys, or  pulsemixer  in a terminal
  Lock:      Super+L      Suspend: close the lid
```
