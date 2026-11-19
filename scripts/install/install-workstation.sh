#!/usr/bin/env bash
# install-workstation.sh — install the nullptr Workstation files into a system.
#
#   sudo scripts/install/install-workstation.sh            # into / (chroot or real system)
#   sudo scripts/install/install-workstation.sh --no-nvim-plugins
#
# Installs commands, docs, system config (incl. clang as the default C/C++ compiler) and
# the default home directory contents (/etc/skel: dotfiles, an empty ~/Projects and the
# pre-downloaded AstroNvim plugins/parsers). Existing users' homes are never modified by
# this script; nullptr-update does that (with backups).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKEL="${NULLPTR_SKEL:-/etc/skel}"
PREFIX=/usr/local
SHARE=$PREFIX/share/nullptr
NVIM_PLUGINS=1
for a in "$@"; do
  case "$a" in
    --no-nvim-plugins) NVIM_PLUGINS=0 ;;
    *) echo "unknown option $a" >&2; exit 64 ;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
log() { printf '\n\033[1;34m[nullptr]\033[0m %s\n' "$*"; }

log "Commands -> $PREFIX/bin, helpers -> $PREFIX/lib/nullptr"
install -d "$PREFIX/bin" "$PREFIX/lib/nullptr" "$SHARE/docs"
install -m755 "$REPO"/scripts/bin/* "$PREFIX/bin/"
install -m644 "$REPO"/scripts/lib/*.sh "$PREFIX/lib/nullptr/"
install -m644 "$REPO/versions.lock" "$SHARE/versions.lock"
# files of earlier versions (project templates, Game Boy/raylib commands)
rm -rf "${SHARE:?}/templates" "$PREFIX/lib/nullptr/nullptr-actions.sh"
for old in build run-game debug-game projects new-c new-raylib new-gameboy nullptr-new \
           gb-build gb-clean gb-debug gb-info gb-run; do
  [ -e "$REPO/scripts/bin/$old" ] || rm -f "$PREFIX/bin/$old"
done

log "Docs -> $SHARE/docs"
cp -a "$REPO"/docs/. "$SHARE/docs/"
chmod -R a+rX "$SHARE/docs"

log "System configuration"
cp -a "$REPO/config/system/." /
rm -f /etc/profile.d/nullptr-gbdk.sh

log "clang is the default C/C++ compiler (cc, c++; CMake and make use these)"
if command -v clang >/dev/null 2>&1; then
  update-alternatives --install /usr/bin/cc cc "$(readlink -f "$(command -v clang)")" 100 >/dev/null
  update-alternatives --install /usr/bin/c++ c++ "$(readlink -f "$(command -v clang++)")" 100 >/dev/null
  update-alternatives --set cc "$(readlink -f "$(command -v clang)")" >/dev/null
  update-alternatives --set c++ "$(readlink -f "$(command -v clang++)")" >/dev/null
fi
# lldb-dap under its plain name (Debian ships it versioned, e.g. lldb-dap-19)
# (the newest one if several LLVM versions are installed)
if ! command -v lldb-dap >/dev/null 2>&1 || [ -L "$PREFIX/bin/lldb-dap" ]; then
  d="$(ls -1 /usr/bin/lldb-dap-[0-9]* /usr/lib/llvm-*/bin/lldb-dap 2>/dev/null | sort -V | tail -n1)"
  [ -n "$d" ] && [ -x "$d" ] && ln -sf "$d" "$PREFIX/bin/lldb-dap"
fi
[ -d /usr/lib/live/config ] && chmod 755 /usr/lib/live/config/2000-nullptr-lock-live-user 2>/dev/null || true

log "Default home directory ($SKEL)"
D="$REPO/config/dotfiles"
install -d "$SKEL/.config" "$SKEL/.local/state/nullptr" "$SKEL/.config/nullptr"
install -m644 "$D/shell/bash_profile" "$SKEL/.bash_profile"
install -m755 "$D/shell/xinitrc" "$SKEL/.xinitrc"
install -m644 "$D/shell/Xresources" "$SKEL/.Xresources"
for app in i3 i3status kitty tmux lazygit btop; do
  rm -rf "$SKEL/.config/$app"; cp -a "$D/$app" "$SKEL/.config/$app"
done
rm -rf "$SKEL/.config/nvim"; cp -a "$D/nvim" "$SKEL/.config/nvim"
# lazygit reads ~/.config/lazygit/config.yml (XDG) — already in place

install -d "$SKEL/Projects"   # empty: clone your projects here (Space m g, or gh repo clone)

if [ "$NVIM_PLUGINS" = 1 ]; then
  log "AstroNvim plugins and treesitter parsers (pinned by lazy-lock.json) -> $SKEL/.local/share/nvim"
  # Install exactly the locked plugin commits, then compile parsers, all offline-ready.
  NVIM_BUILD_CACHE="$(mktemp -d)"
  export HOME="$SKEL" XDG_CONFIG_HOME="$SKEL/.config" XDG_DATA_HOME="$SKEL/.local/share" \
         XDG_STATE_HOME="$SKEL/.local/state" XDG_CACHE_HOME="$NVIM_BUILD_CACHE" \
         NULLPTR_TS_BOOTSTRAP=1   # parsers are installed by nvim-ts-install.lua below, via git
  nvim --headless "+Lazy! restore" +qa
  nvim --headless "+Lazy! restore" +qa   # second pass: plugins added by AstroNvim imports
  nvim --headless -c "luafile $REPO/scripts/install/nvim-ts-install.lua" -c qa
  # Sanity check: AstroNvim loads with no errors
  unset NULLPTR_TS_BOOTSTRAP
  nvim --headless -c 'lua if not pcall(require, "astronvim") then vim.cmd "cquit 1" end' -c qa
  rm -rf "$XDG_CACHE_HOME" "$SKEL/.local/state/nvim"
  git -C "$SKEL/.config/nvim" status >/dev/null 2>&1 || true
fi
chmod -R go-w "$SKEL"
log "Workstation files installed."
