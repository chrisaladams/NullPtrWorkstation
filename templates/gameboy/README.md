# __NAME__

A Game Boy ROM written in C with [GBDK-2020](https://github.com/gbdk-2020/gbdk-2020),
created from the nullptr Workstation template.

## Build, run, debug

| Task | Terminal | AstroVim |
|---|---|---|
| Build Debug ROM | `gb-build` (or `build`) | `Space m b` |
| Build Release ROM | `gb-build --release` | `Space m B` |
| Run in Emulicious | `gb-run` (or `run-game`) | `Space m r` |
| Debug C source | `gb-debug` (or `debug-game`) | `Space m d` or `F5` |
| Clean | `gb-clean` | `Space m c` |

The Debug build passes `-debug` to `lcc`, which makes SDCC/the linker write
`build/debug/__NAME__.cdb` (C source debug info), `.noi` (symbols) and `.map`.
Emulicious uses the `.cdb` to stop on C lines, step and show variables.
Keep the `.cdb` next to the `.gb` file.

Breakpoints must be on **executable** lines (e.g. `keys = joypad();`), not on
declarations or blank lines.

## Layout

```
src/main.c     game code (compiled by lcc, not gcc)
assets/        sprites/tiles (save LibreSprite PNGs here; convert with $GBDK_HOME/bin/png2asset)
Makefile       Debug/Release build
.clangd        lets clangd understand GBDK headers for completion
.vscode/       launch config for the optional VSCodium fallback debugger
```

Convert a sprite sheet made in LibreSprite:

```sh
/opt/gbdk/bin/png2asset assets/player.png -c src/player.c -sw 16 -sh 16 -spr8x16
```
