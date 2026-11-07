# Licenses and redistribution

The ISO is built **by you, for you**. This table covers what changes if you share the ISO
with other people.

| Component | License | In the ISO | Redistribution notes |
|---|---|---|---|
| Debian 13 packages | DFSG-free (main), plus non-free firmware | yes | Debian redistributes them all, including `non-free-firmware`. `out/packages.manifest` lists versions; sources at `deb.debian.org` / `snapshot.debian.org` |
| Neovim 0.12.6 | Apache-2.0 / Vim | yes | ✓ |
| AstroNvim v6 + plugins (pinned by `lazy-lock.json`) | GPL-3.0 (AstroNvim), MIT/Apache-2.0/GPL (plugins) | yes, as git checkouts with source | ✓ source is included |
| tree-sitter CLI 0.27.1, parsers | MIT | yes | ✓ |
| GBDK-2020 4.5.0 (+ bundled SDCC) | GPL-2.0+ with linking exceptions, see `/opt/gbdk/licenses` | yes | ✓ upstream binary release, license files kept |
| raylib 5.5 | zlib | yes | ✓ |
| Tiled | GPL-2.0 (editor); BSD-2 for its file-format libraries | Debian package | ✓ Maps you make are yours. Debian ships its source, like every other Debian package |
| LibreSprite 1.2 | GPL-2.0 | yes (built from source) | ✓ for you. **If you share the ISO**, GPL-2.0 §3 requires offering the source: the exact commit is in `versions.lock`; ship `https://github.com/LibreSprite/LibreSprite` at `5cb089be…` with it |
| lazygit 0.66.2 | MIT | yes | ✓ |
| JetBrains Mono Nerd Font 3.5.1 | SIL OFL 1.1 | yes | ✓ |
| VSCodium 1.143 | MIT (binaries) | yes (optional) | ✓ |
| Emulicious Debugger extension 1.3.0 | MIT | yes (optional) | ✓ |
| **Emulicious** | **freeware, closed source** | **yes by default** | **Unverified.** The developer's site could not be reached while building this, so its redistribution terms could not be read. Downloading it into your own image for your own use matches its normal use. **Before sharing an ISO, build with `NULLPTR_WITH_EMULICIOUS=0`**: users then install it themselves with `sudo nullptr-install-emulicious` (downloads from emulicious.net). |
| OpenJDK 21 | GPL-2.0 + Classpath exception | yes (Debian) | ✓ |

Nothing in the image has a default password or embedded credentials.
