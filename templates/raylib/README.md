# __NAME__

A C + [raylib](https://www.raylib.com) game, created from the nullptr Workstation template.

## Build, run, debug

| Task | Terminal | AstroVim |
|---|---|---|
| Build (Debug) | `build` | `Space m b` |
| Build (Release) | `build --release` | `Space m B` |
| Run | `run-game` | `Space m r` |
| Debug (GDB via nvim-dap) | `debug-game` | `Space m d` or `F5` |
| Clean | `rm -rf build` | `Space m c` |

Under the hood `build` runs CMake + Ninja:

```sh
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug   # or: cmake --preset debug
cmake --build build/debug
./build/debug/__NAME__
```

`build/debug/compile_commands.json` is symlinked to the project root so clangd
(code completion, diagnostics, clang-tidy) understands the project.

## Layout

```
src/main.c        game code
assets/           sprites and sounds (save LibreSprite files here; load them as "assets/name.png")
CMakeLists.txt    build definition (Debug: -g3 -O0, Release: -O2)
CMakePresets.json `cmake --preset debug|release`
```
