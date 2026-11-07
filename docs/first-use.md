# First-use tutorial

Also available on the workstation: `helpme tutorial`, or `H` on the AstroVim dashboard.

```text
nullptr Workstation — first-use tutorial (about 15 minutes)    (q to close)
==========================================================================

 1. Open a project
    In AstroVim's dashboard press  1  (raylib-hello).
    The file explorer opens on the left and src/main.c on the right.

 2. Browse and edit files
    Space e        toggles the explorer. Move with the arrow keys, Enter opens.
    Space f f      type "main" and press Enter to jump to a file by name.
    In main.c, move the cursor to the text "Hello, raylib!".
    Press  i  (Insert mode), change the text, press  Esc .

 3. Save
    Type  :w  and press Enter.  (Or Space w.)

 4. Build
    Space m b   — a terminal opens at the bottom and CMake/Ninja compile.
    Errors? Space x x lists them; Enter jumps to the line.
    Close the build output with  q  (in that window) or Ctrl+w o.

 5. Run
    Space m r   — the game opens on workspace 5. Esc closes it and you are
    back in AstroVim (Super+1 also takes you back).

 6. Debug
    Put the cursor on the line  frameCount++;  and press F9 (red dot).
    Press F5 (or Space m d). The game starts; when it reaches the line,
    AstroVim comes back with the debugger panels:
      Locals shows frameCount, the stack shows where you are.
    F10 = next line, F11 = step into, F5 = continue, Shift+F5 = stop.

 7. Switch to a terminal
    Ctrl+b 2   → the build terminal. Try:  build   then   run-game
    Ctrl+b 1   → back to AstroVim.

 8. Open LibreSprite
    Super+A (or type  art ). LibreSprite opens on workspace 2, started in the
    active project's assets/ folder. Draw a sprite, File ▸ Save As…, and save
    it as ~/Projects/raylib-hello/assets/player.png.

 9. Return to AstroVim
    Super+1.  The new file appears in the explorer under assets/.

10. Switch between raylib and Game Boy
    Space m p  → choose gameboy-hello.  (Or Space h, then 2.)
    The tmux status bar now shows "gameboy-hello".
    Space m b builds the ROM, Space m r runs it in Emulicious,
    F9 on  keys = joypad();  then F5 debugs the C code in Emulicious.
    Space m p → raylib-hello switches back.

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

  Super+2 shows LibreSprite (art), Super+3 Tiled (tiles), Super+4 Blender
  (3d), Super+5 the running game, Super+6 is for anything else.
  Super+1 brings you back to the editor.

 Projects
 --------------------------------------------------------------------------
  Your code lives in ~/Projects. Two starters are ready:
     raylib-hello    a C + raylib desktop game (CMake + Ninja)
     gameboy-hello   a C Game Boy ROM (GBDK-2020)

  The ACTIVE project is the one build/run/debug use. It changes when you
     • open a project from the AstroVim dashboard ([P] or 1/2), or Space m p
     • open/enter a file of another project in AstroVim
     • run  projects  (picker),  projects use NAME,  code PATH,  new-raylib/new-gameboy
  The tmux status bar shows the active project (purple, bottom right).
  If your shell is inside project A while B is active, build refuses and
  tells you how to choose — it never silently builds the wrong project.

 Commands
 --------------------------------------------------------------------------
  dev                 attach the tmux workspace (creates it if needed)
  projects            choose a project and open it in AstroVim
  code PATH           open a file or folder in AstroVim
  build [--release]   compile the active project
  run-game            build + run (raylib window or ROM in Emulicious)
  debug-game          build Debug + start the debugger in AstroVim
  art [FILE]          LibreSprite on workspace 2 (saves into assets/)
  tiles [FILE.tmx]    Tiled map editor on workspace 3 (maps into assets/)
  3d [FILE.blend]     Blender on workspace 4 (export .glb into assets/)
  new-c NAME          new plain C project (CMake, no libraries) in ~/Projects/NAME
  new-raylib NAME     new raylib project in ~/Projects/NAME
  new-gameboy NAME    new Game Boy project in ~/Projects/NAME
  projects adopt      make the current folder a project (writes .nullptr-project)
  build --clean       remove build output
  gb-build gb-run gb-debug gb-clean gb-info    Game Boy specific
  (all new-* commands accept --no-git; details: docs/c-projects.md)
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
  Updates:   nullptr-update   (workstation from GitHub; --dry-run first)
  Reinstall: nullptr-iso      (GitHub-built ISO; --write /dev/sdX for a USB stick)
             sudo apt update && sudo apt upgrade   (Debian security updates)
  Wi-Fi:     nmtui → "Activate a connection"
  Volume:    the laptop's volume keys, or  pulsemixer  in a terminal
  Lock:      Super+L      Suspend: close the lid
```
