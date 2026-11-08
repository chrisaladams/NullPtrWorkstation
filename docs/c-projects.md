# Plain C projects (and doing things by hand)

Three project types share the same commands. Only the template and the default build differ:

| Type | Create | Build | Run | Debug |
|---|---|---|---|---|
| `generic` | `new-c NAME` | CMake + Ninja (or your Makefile, or your `build=` command) | in the terminal | GDB |
| `raylib` | `new-raylib NAME` | CMake + Ninja, raylib linked | game window on workspace 6 | GDB |
| `gameboy` | `new-gameboy NAME` | `make` with GBDK's `lcc` | ROM in Emulicious | Emulicious |

All of this is optional. `cmake`, `make`, `gcc`, `clang` and `gdb` are ordinary commands, and
AstroVim's code intelligence (clangd) works on any C folder that has a
`compile_commands.json` (CMake writes one).

## `new-c NAME`

Creates `~/Projects/NAME` with:

```
src/main.c          prints "Hello from NAME!"
CMakeLists.txt      yours: C17, -Wall -Wextra, Debug -g3 -O0 / Release -O2, no libraries
CMakePresets.json   cmake --preset debug|release
.nullptr-project    type=generic (plus commented optional settings)
.clang-format .clang-tidy .gitignore README.md
```

Nothing is generated or maintained for you afterwards (unlike CLion): **add new `.c` files to
`add_executable()` yourself**. To link a library, see the `pkg_check_modules` example in the
template's `CMakeLists.txt`.

Add `--no-git` to skip `git init` (any `new-*` command accepts it).

## An existing folder: `projects adopt`

```bash
cd ~/Projects/myfolder
```
```bash
projects adopt
```
```bash
projects adopt --type raylib
```

`projects adopt` writes only `.nullptr-project`, guessing the type: `raylib` if
`CMakeLists.txt` mentions raylib, `gameboy` if the Makefile uses `lcc`/GBDK, otherwise
`generic`. Use `--type` to choose. It refuses if the folder already is a project. Until a
folder has `.nullptr-project` it is not in the project lists, and `build`/`run-game` ignore
it. Everything else (editing, search, git) works in any folder.

## Telling the shortcuts exactly what to do

For `generic` projects, optional lines in `.nullptr-project` override the defaults
(`CMakeLists.txt` → CMake, `Makefile` → `make`). `$CONFIG` is `debug` or `release`:

```sh
type=generic
target=myprog
build=make CONFIG=$CONFIG          # what `build` / Space m b runs (in the project folder)
run=./myprog --verbose input.txt   # what `run-game` / Space m r runs after building
artifact=myprog                    # the program the debugger (F5) starts
clean=make clean                   # what `build --clean` / Space m c runs
window=yes                         # it opens a window: show workspace 6 (game) while it runs
```

`window=yes` matters for SDL/GLFW programs. They wait until their window is visible, and a
window opened on workspace 1 would be hidden behind the fullscreen terminal.

## Manual equivalents

```bash
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
```
```bash
cmake --build build/debug
```
```bash
ln -sfn build/debug/compile_commands.json .
```
```bash
./build/debug/myprog
```
```bash
gdb ./build/debug/myprog
```

`ln` lets clangd find the build settings; `build` does that for you.
