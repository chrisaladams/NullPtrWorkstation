# Licenses and redistribution

The ISO is built **by you, for you**. This table covers what changes if you share the ISO
with other people.

| Component | License | In the ISO | Redistribution notes |
|---|---|---|---|
| Debian 13 packages | DFSG-free (main), plus non-free firmware | yes | Debian redistributes them all, including `non-free-firmware`. `out/packages.manifest` lists versions; sources at `deb.debian.org` / `snapshot.debian.org` |
| Neovim 0.12.6 | Apache-2.0 / Vim | yes | ✓ |
| AstroNvim v6 + plugins (pinned by `lazy-lock.json`) | GPL-3.0 (AstroNvim), MIT/Apache-2.0/GPL (plugins) | yes, as git checkouts with source | ✓ source is included |
| tree-sitter CLI 0.27.1, parsers | MIT | yes | ✓ |
| Tiled | GPL-2.0 (editor); BSD-2 for its file-format libraries | Debian package | ✓ Maps you make are yours. Debian ships its source, like every other Debian package |
| LibreSprite 1.2 | GPL-2.0 | yes (built from source) | ✓ for you. **If you share the ISO**, GPL-2.0 §3 requires offering the source: the exact commit is in `versions.lock`; ship `https://github.com/LibreSprite/LibreSprite` at `5cb089be…` with it |
| lazygit 0.66.2 | MIT | yes | ✓ |
| JetBrains Mono Nerd Font 3.5.1 | SIL OFL 1.1 | yes | ✓ |
| Blockbench 5.2.2 | GPL-3.0 | yes (upstream `.deb`) | ✓ for you. **If you share the ISO**, offer the source: `https://github.com/JannisX11/blockbench` at tag `v5.2.2` |

Nothing in the image has a default password or embedded credentials.
