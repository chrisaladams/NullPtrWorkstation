# C projects: clone, build, run, debug

The workstation has no project types and nothing to add to a repository. A project is a
folder in `~/Projects`, usually a git repository. You set it up the way you like (CMake,
Make, a script). AstroVim works out how to build, run and debug it, and the project can
override that from its own files, so you never edit AstroVim for a new target.

## Get a project

| | |
|---|---|
| AstroVim | `Space m g` (or **[G]** on the dashboard): `owner/repo` or any git URL, cloned with submodules into `~/Projects`, then opened |
| terminal | `gh repo clone owner/repo ~/Projects/repo`, or `git clone --recurse-submodules URL ~/Projects/repo` |
| your own new one | `mkdir ~/Projects/pong && cd ~/Projects/pong && git init`, then write the `CMakeLists.txt` or `Makefile` yourself |

Open a project with `Space m p` (or **[P]**, or a number on the dashboard). AstroVim's working
folder becomes the project root: the git repository, or without git the folder with the build
file. Opening a file of another project switches to it.

The other tools follow the project open in AstroVim: Super+E (file manager), Ctrl+b 3
(LazyGit), `import-assets`, and the repository name and branch in the tmux status bar.

## Space m: what AstroVim does

| Key | |
|---|---|
| `Space m b` | build |
| `Space m r` | build, then run (output in a split; a window opens on workspace 6) |
| `Space m d` or `F5` | build, then debug (`F5` continues while debugging) |
| `Space m c` | clean |
| `Space m T` | choose which program to run/debug (if the build makes several) |
| `Space m i` | show how this project is built and debugged |

Without any project settings, AstroVim detects:

| Project has | Build | clangd gets |
|---|---|---|
| `CMakeLists.txt` | `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` once, then `cmake --build build` | `build/compile_commands.json` |
| `Makefile` | `bear --append -- make -jN` | `compile_commands.json` (bear records the compiler calls) |
| `build.sh` | `sh ./build.sh` | whatever the script produces |

**Run** and **debug** use the program the build produced: an executable under `build/`, `bin/`,
`out/` or the project root. If there are several, AstroVim asks once and remembers (`Space m T`
to change it). **Debugging** uses LLDB (`lldb-dap`): `F9` breakpoint, `F5` continue, `F10` step
over, `F11` step into, `Space d u` panels.

**clang is the default compiler**: `cc`/`c++`, CMake and make all use clang unless a project
says otherwise. `gcc` is still installed.

## When the defaults don't fit: settings in the project

Two places, both inside the repository, both used by other editors too:

### `.vscode/launch.json`: how to debug

nvim-dap reads it, so a project that already has one for VS Code just works. Debugger types:

| `"type"` | Debugger |
|---|---|
| `"lldb"` or `"lldb-dap"` | LLDB |
| `"gdb"` | GDB (its built-in DAP: `program`, `args`, `cwd`, `target` for remote) |
| `"gdb-multiarch"` | GDB for other CPUs (ARM: GBA, embedded) |

```json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "game (GDB)", "type": "gdb", "request": "launch",
      "program": "${workspaceFolder}/build/game", "cwd": "${workspaceFolder}" }
  ]
}
```

(VS Code's `cppdbg`/`cppvsdbg` types are specific to Microsoft's extension; use `gdb` or `lldb`.)

### `.nvim.lua`: how to build, run and debug

A `.nvim.lua` in the project root that **returns a table** overrides the detection. The first
time AstroVim reads it (and after every change), Neovim asks whether you trust the file:
`[a]llow`, `[v]iew` or `[d]eny`. It's Lua that runs on your machine, so look before allowing
one from someone else's repository.

```lua
return {
  build   = "make -j8",            -- a string (run by sh) or a list { "make", "-j8" }
  run     = "./build/game --windowed",
  clean   = "make clean",
  cwd     = "assets",              -- where run starts (default: the project root)
  program = "build/game",          -- what run and the debugger use
  debug   = { ... },               -- one nvim-dap configuration, or a list of them
}
```

Every field is optional. The file can also do anything else Neovim allows, such as register
a debug adapter or set options for this project only.

## Examples

### A raylib or SDL3 game: the library inside the project

Nothing is installed system-wide. The project fetches a pinned copy and links it statically, so
every game keeps the version it was written for and the binary runs elsewhere too:

```cmake
cmake_minimum_required(VERSION 3.24)
project(pong C)
include(FetchContent)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(raylib GIT_REPOSITORY https://github.com/raysan5/raylib.git
                            GIT_TAG 5.5 GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(raylib)
add_executable(pong src/main.c)
target_link_libraries(pong PRIVATE raylib m)
```

For SDL3, use `GIT_REPOSITORY https://github.com/libsdl-org/SDL.git` with a release tag, plus
`set(SDL_STATIC ON)`, and link `SDL3::SDL3-static`. To work offline, put the library in as a
git submodule (`git submodule add URL external/raylib`) and use `add_subdirectory(external/raylib)`.

`Space m b` and `F5` work on this with no settings. The game window opens on workspace 6, and
the editor comes back when execution stops at a breakpoint.

### Game Boy Advance (devkitARM + mGBA)

Install the toolchain from devkitPro (it goes to `/opt/devkitpro`). clangd already asks
compilers under `/opt` for their headers, so completion works once the build has produced
`compile_commands.json` (through bear for a Makefile). `.nvim.lua`:

```lua
return {
  build = "make -j8",
  run   = "mgba-qt game.gba",
  debug = {
    name = "GBA in mGBA (gdb stub)", type = "gdb-multiarch", request = "attach",
    program = "${workspaceFolder}/game.elf",
    target = "localhost:2345",               -- start mGBA with:  mgba-qt -g game.gba
  },
}
```

### Game Boy (GBDK-2020 + Emulicious)

Emulicious is itself a debug adapter. Register it from the project's `.nvim.lua`:

```lua
require("dap").adapters.emulicious = {
  type = "server", port = "${port}",
  executable = { command = "emulicious", args = { "-remotedebug", "${port}" } },
  options = { max_retries = 120 },        -- the JVM takes a few seconds to start
}
return {
  build = "make",
  program = "build/game.gb",
  debug = { name = "ROM in Emulicious", type = "emulicious", request = "launch",
            program = "${workspaceFolder}/build/game.gb", port = 58870,
            additionalSrcFolders = "${workspaceFolder}/src" },
}
```

GBDK, Emulicious (and Java for it) are your installs; see their sites.

### A plain C tool

Nothing to set: `Space m r` runs it in the split at the bottom (it has no window), and `F5`
debugs it with LLDB.

## Doing it by hand

Everything AstroVim does is an ordinary command in a terminal (Ctrl+b 2):

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```
```bash
cmake --build build && ./build/pong
```
```bash
bear -- make            # Make projects: compile_commands.json for clangd
```
```bash
lldb ./build/pong       # or: gdb -tui ./build/pong
```

A program with a window started from the terminal also opens on workspace 6, and closing it
brings you back to the editor.
