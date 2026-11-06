# C + raylib: build and debug guide

## Toolchain

| Tool | Source | Notes |
|---|---|---|
| GCC, Clang, Make, pkg-config | Debian 13 | `build-essential`, `clang` |
| clangd, clang-format, clang-tidy | Debian 13 | used by AstroVim (no Mason downloads) |
| GDB 16.3 | Debian 13 | its built-in DAP server (`gdb --interpreter=dap`) drives nvim-dap |
| CMake 3.31, Ninja | Debian 13 | |
| raylib 5.5 | built from source at commit `c1ab645c` | X11 + OpenGL, shared lib in `/usr/local/lib`, `raylib.pc` for pkg-config |
| ENet | Debian `libenet-dev` | `pkg-config --libs libenet` |

## Project layout (`new-raylib NAME`)

```
NAME/
  .nullptr-project     type=raylib, target=NAME (marks the project root)
  CMakeLists.txt       finds raylib with pkg-config; Debug -g3 -O0, Release -O2
  CMakePresets.json    cmake --preset debug|release
  src/main.c
  assets/              load as "assets/file.png" (games run from the project root)
  .clang-format        style used by Space l f
  .clang-tidy          checks clangd reports while you type
  .gitignore
```

## Build

| | Terminal | AstroVim |
|---|---|---|
| Debug | `build` | `Space m b` |
| Release | `build --release` | `Space m B` |
| Clean | `rm -rf build` | `Space m c` |

`build` runs, for the Debug configuration:

```sh
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build/debug
ln -sfn build/debug/compile_commands.json compile_commands.json   # for clangd
```

Binaries: `build/debug/NAME` and `build/release/NAME`.

## Run

`run-game` (or `Space m r`) builds incrementally, switches to i3 workspace 4 (game), runs the game
from the project root, and returns to workspace 1 when the game exits.

## Debug (GDB through nvim-dap)

1. Put the cursor on an executable line (e.g. `frameCount++;`) and press **F9**
   (`Space d b`). A breakpoint sign appears.
2. Press **F5** (`Space m d`). A Debug build is made, the game starts on workspace 4, and
   when the breakpoint is hit **i3 switches back to the editor** with the debugger panels:
   *Scopes/Locals* (variables), *Stacks* (call stack), *Breakpoints*, *Watches*, *REPL*.
3. **F10** step over, **F11** step into, **Shift+F11** step out, **F5** continue
   (the game workspace comes back while it runs), **Shift+F5** stop.
4. `Space d h` shows the value under the cursor. `Space d E` evaluates an expression.

From a terminal, `debug-game` does the same thing inside the running AstroVim (or opens one).
`debug-game --gdb` gives plain GDB in text mode (`gdb -tui`).

Why the workspace switching matters: GLFW (used by raylib) waits for its window to become
visible before `InitWindow()` returns. If the game window opened behind the fullscreen editor,
the game would hang at start-up. This was found and fixed during testing.

**GDB version:** the nvim-dap integration needs **GDB ≥ 16**. Debian 13 ships 16.3, which
was tested (see [tests/REPORT.md](../tests/REPORT.md)). GDB 15 starts the program on
`launch` before breakpoints arrive, so breakpoints may be skipped.

## Using LibreSprite assets

Save sprites from LibreSprite into `assets/` and load them in C:

```c
Texture2D player = LoadTexture("assets/player.png");
// ... DrawTexture(player, x, y, WHITE);
UnloadTexture(player);
```

## Networking with ENet

```cmake
pkg_check_modules(ENET REQUIRED IMPORTED_TARGET libenet)
target_link_libraries(${PROJECT_NAME} PRIVATE PkgConfig::ENET)
```
