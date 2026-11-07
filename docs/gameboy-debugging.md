# Game Boy (GBDK-2020 + Emulicious): build and C source debugging

## Toolchain

| Component | Version | Notes |
|---|---|---|
| GBDK-2020 | 4.5.0 (`/opt/gbdk`) | includes its own SDCC 4.5.1 (#15267). ROMs are always built with GBDK's `lcc`, never with native GCC |
| Emulicious | latest from emulicious.net, installed at build time (`/opt/emulicious`) | freeware Java emulator with a built-in debugger and a **Debug Adapter Protocol server** |
| Java | Debian `default-jre` (OpenJDK 21) | runs Emulicious |
| nvim-dap adapter | `emulicious` (TCP) | configured in `~/.config/nvim/lua/plugins/dap.lua` |
| VSCodium + Emulicious Debugger 1.3.0 | optional fallback (`NULLPTR_WITH_VSCODIUM=1`, default) | |

`gb-info` prints all of this on the machine.

## Build

| | Terminal | AstroVim |
|---|---|---|
| Debug ROM | `gb-build` (or `build`) | `Space m b` |
| Release ROM | `gb-build --release` | `Space m B` |
| Clean | `gb-clean` | `Space m c` |

The Makefile uses:

```make
# Debug: C source debug info (SDCC --debug, linker .cdb), symbols (.noi), map, listings
lcc -debug -Wf--fverbose-asm -Wa-l -c -o build/debug/main.o src/main.c
lcc -debug -Wf--fverbose-asm -Wa-l -Wm-yn"GAMEBOY_HELLO" -Wl-m -o build/debug/gameboy-hello.gb build/debug/main.o
```

Outputs in `build/debug/`: `NAME.gb` (ROM), **`NAME.cdb`** (C source debug info: functions,
variables and `L:C$main.c$<line>` records), `NAME.noi`, `NAME.map`, `*.lst`, `*.adb`.
**Keep the `.cdb` next to the `.gb`**, because Emulicious loads it from there.

## Run

`gb-run` (or `Space m r`) builds and opens the ROM in Emulicious on workspace 5 (game).

## Debug C source in AstroVim (primary path)

1. Open `src/main.c`, put the cursor on an executable statement such as
   `keys = joypad();`, and press **F9**.
2. Press **F5** (or `Space m d`, or `gb-debug` in a terminal).
3. What happens:
   - `build --debug` makes the Debug ROM and `.cdb`,
   - nvim-dap starts `emulicious -remotedebug <port>` (Emulicious **is** the debug adapter;
     the VS Code extension does exactly this and then connects to the port),
   - nvim-dap connects over TCP and sends `launch` with
     `program = build/debug/NAME.gb` and `additionalSrcFolders = src/` (the `.cdb` stores
     only `main.c`, so Emulicious needs the folder to map it to your file).
4. Execution stops on the C line, and AstroVim's debugger panels show locals/globals
   (`keys`, `frame_counter`, `a_presses`) and the call stack.
5. **F10** steps one C line, **F11** steps into, **F5** continues.

Breakpoints must be on executable C lines, not on declarations, comments or blank lines.

### Fallbacks

| Command | Backend |
|---|---|
| `gb-debug --emulicious` | Emulicious's own debugger window (*Tools ▸ Debugger*). It shows C source when the `.cdb` is next to the ROM |
| `gb-debug --vscodium` | VSCodium with the Emulicious Debugger extension. The project's `.vscode/launch.json` holds *Debug ROM in Emulicious*, so press F5 |

## Test status

**Verified on a fresh installation of the ISO** (UEFI virtual machine, automated, see
[tests/REPORT.md](../tests/REPORT.md)):

- `gb-build` makes Debug and Release ROMs, and the `.cdb` holds C line records.
- `gb-run` opens the ROM in Emulicious.
- **C source debugging through AstroVim's nvim-dap** with the Emulicious adapter: a breakpoint
  on `keys = joypad();` is verified and hit, `keys` is shown (`unsigned char`, Locals), step
  goes to the next C line, and continue stops at the breakpoint again on the next frame. The
  same passes with a raw DAP client.

Two things learned while testing:

- On first start Emulicious shows a modal **"Update Behaviour"** dialog that blocks everything,
  including the debug adapter. The workstation ships `Emulicious.ini` with `Update=0` ("never
  check"), so the dialog does not appear and Emulicious stays on the tested version. Update
  deliberately with `sudo nullptr-install-emulicious`.
- Emulicious's adapter does not support the DAP `configurationDone` request (it says so in its
  capabilities). nvim-dap respects that. A client that sends it anyway crashes the adapter.

Re-run the check on your machine:

```bash
/usr/local/src/nullptr-workstation/tests/dap/gameboy-dap-test.sh
```
