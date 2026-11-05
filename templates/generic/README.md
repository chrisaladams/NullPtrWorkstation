# __NAME__

A plain C project (CMake + Ninja), created with `new-c`.

```sh
cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug   # or: cmake --preset debug
cmake --build build/debug
./build/debug/__NAME__
```

The workstation shortcuts work too, but are optional: `build`, `run-game`,
`debug-game` (or `Space m b` / `m r` / `m d` / `F5` in AstroVim).

Add new `.c` files to `add_executable()` in `CMakeLists.txt`. To use your own Makefile or
other commands with the shortcuts, see the comments in `.nullptr-project`.
