#!/usr/bin/env bash
# install-upstream.sh — install the pinned non-Debian components listed in versions.lock.
# Runs as root inside the live-build chroot (hook 0100) and also works on any Debian 13
# system:  sudo scripts/install/install-upstream.sh [component...]
# Components: neovim tree-sitter gbdk lazygit nerdfont raylib libresprite emulicious vscodium
# Every download is SHA-256 verified and every git checkout is commit-verified.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${NULLPTR_LOCK:-$HERE/../../versions.lock}"
[ -f "$LOCK" ] || LOCK=/usr/local/share/nullptr/versions.lock
# shellcheck source=../../versions.lock
. "$LOCK"
SHARE=/usr/local/share/nullptr
CACHE="${NULLPTR_CACHE:-/var/cache/nullptr-build}"
JOBS="${JOBS:-$(nproc)}"
RESOLVED="$SHARE/versions.resolved"
mkdir -p "$CACHE" "$SHARE"
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

log() { printf '\n\033[1;34m[nullptr]\033[0m %s\n' "$*"; }
record() { printf '%-14s %s\n' "$1" "$2" >>"$RESOLVED"; }

fetch() { # fetch URL SHA256 OUTFILE
  local url="$1" sum="$2" out="$3"
  if [ ! -f "$out" ] || ! echo "$sum  $out" | sha256sum -c --quiet - 2>/dev/null; then
    curl -fL --retry 4 --retry-delay 3 -o "$out.part" "$url"
    mv "$out.part" "$out"
  fi
  echo "$sum  $out" | sha256sum -c --quiet - || { echo "SHA-256 mismatch for $url" >&2; exit 1; }
}

git_at() { # git_at URL COMMIT DIR [--recursive]
  local url="$1" commit="$2" dir="$3"
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  git -C "$dir" fetch -q --depth 1 origin "$commit"
  git -C "$dir" checkout -q --force FETCH_HEAD
  [ "$(git -C "$dir" rev-parse HEAD)" = "$commit" ] || { echo "commit mismatch in $dir" >&2; exit 1; }
  if [ "${4:-}" = --recursive ]; then
    git -C "$dir" submodule update -q --init --recursive --depth 1 --jobs 4
  fi
}

do_neovim() {
  log "Neovim $NVIM_VERSION"
  fetch "$NVIM_URL" "$NVIM_SHA256" "$CACHE/nvim.tar.gz"
  rm -rf /opt/nvim && mkdir -p /opt/nvim
  tar -xzf "$CACHE/nvim.tar.gz" -C /opt/nvim --strip-components=1
  ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
  # make `vi`/`vim`/`editor` resolve to Neovim for the user
  for n in vi vim editor; do update-alternatives --install /usr/bin/$n $n /usr/local/bin/nvim 60 >/dev/null 2>&1 || true; done
  record neovim "$NVIM_VERSION sha256:$NVIM_SHA256"
}

do_tree_sitter() {
  log "tree-sitter CLI $TREESITTER_CLI_VERSION"
  fetch "$TREESITTER_CLI_URL" "$TREESITTER_CLI_SHA256" "$CACHE/tree-sitter.gz"
  gunzip -c "$CACHE/tree-sitter.gz" >/usr/local/bin/tree-sitter
  chmod 755 /usr/local/bin/tree-sitter
  record tree-sitter "$TREESITTER_CLI_VERSION sha256:$TREESITTER_CLI_SHA256"
}

do_gbdk() {
  log "GBDK-2020 $GBDK_VERSION"
  fetch "$GBDK_URL" "$GBDK_SHA256" "$CACHE/gbdk.tar.gz"
  rm -rf /opt/gbdk && tar -xzf "$CACHE/gbdk.tar.gz" -C /opt
  mkdir -p /opt/gbdk/share && echo "$GBDK_VERSION" >/opt/gbdk/share/nullptr-gbdk-version
  chmod -R a+rX /opt/gbdk
  record gbdk "$GBDK_VERSION sha256:$GBDK_SHA256"
}

do_lazygit() {
  log "lazygit $LAZYGIT_VERSION"
  fetch "$LAZYGIT_URL" "$LAZYGIT_SHA256" "$CACHE/lazygit.tar.gz"
  tar -xzf "$CACHE/lazygit.tar.gz" -C /usr/local/bin lazygit
  chmod 755 /usr/local/bin/lazygit
  record lazygit "$LAZYGIT_VERSION sha256:$LAZYGIT_SHA256"
}

do_nerdfont() {
  log "JetBrainsMono Nerd Font $NERDFONT_VERSION"
  fetch "$NERDFONT_URL" "$NERDFONT_SHA256" "$CACHE/JetBrainsMono.tar.xz"
  rm -rf /usr/local/share/fonts/JetBrainsMonoNerd && mkdir -p /usr/local/share/fonts/JetBrainsMonoNerd
  tar -xJf "$CACHE/JetBrainsMono.tar.xz" -C /usr/local/share/fonts/JetBrainsMonoNerd --wildcards '*.ttf' 'OFL.txt' 'README.md' 2>/dev/null ||
    tar -xJf "$CACHE/JetBrainsMono.tar.xz" -C /usr/local/share/fonts/JetBrainsMonoNerd
  fc-cache -f /usr/local/share/fonts >/dev/null
  record nerdfont "$NERDFONT_VERSION sha256:$NERDFONT_SHA256"
}

do_raylib() {
  log "raylib $RAYLIB_VERSION (from source, X11, shared + pkg-config)"
  git_at "$RAYLIB_GIT" "$RAYLIB_COMMIT" "$CACHE/raylib"
  rm -rf "$CACHE/raylib/build"
  cmake -S "$CACHE/raylib" -B "$CACHE/raylib/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_SHARED_LIBS=ON -DPLATFORM=Desktop -DBUILD_EXAMPLES=OFF \
    -DGLFW_BUILD_WAYLAND=OFF -DGLFW_BUILD_X11=ON -DCUSTOMIZE_BUILD=OFF
  cmake --build "$CACHE/raylib/build" -j "$JOBS"
  cmake --install "$CACHE/raylib/build"
  ldconfig
  record raylib "$RAYLIB_VERSION git:$RAYLIB_COMMIT"
}

do_libresprite() {
  log "LibreSprite $LIBRESPRITE_VERSION (from source)"
  git_at "$LIBRESPRITE_GIT" "$LIBRESPRITE_COMMIT" "$CACHE/libresprite" --recursive
  rm -rf "$CACHE/libresprite/build"
  cmake -S "$CACHE/libresprite" -B "$CACHE/libresprite/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/libresprite \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  cmake --build "$CACHE/libresprite/build" -j "$JOBS"
  rm -rf /opt/libresprite
  cmake --install "$CACHE/libresprite/build"
  ln -sfn /opt/libresprite/bin/libresprite /usr/local/bin/libresprite
  mkdir -p /usr/local/share/applications
  cat >/usr/local/share/applications/libresprite.desktop <<'D'
[Desktop Entry]
Type=Application
Name=LibreSprite
Exec=libresprite %F
Terminal=false
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=image/png;image/gif;image/bmp;
D
  record libresprite "$LIBRESPRITE_VERSION git:$LIBRESPRITE_COMMIT"
}

do_emulicious() {
  log "Emulicious (freeware, downloaded from $EMULICIOUS_URL)"
  local inst="$HERE/../sbin/nullptr-install-emulicious"
  [ -x "$inst" ] || inst=/usr/local/sbin/nullptr-install-emulicious
  EMULICIOUS_URL="$EMULICIOUS_URL" EMULICIOUS_SHA256="${EMULICIOUS_SHA256:-}" "$inst" || return 1
  record emulicious "$(cat "$SHARE/emulicious.sha256")"
}

do_vscodium() {
  log "VSCodium $VSCODIUM_VERSION + Emulicious Debugger $EMULICIOUS_VSIX_VERSION (fallback debugger UI)"
  fetch "$VSCODIUM_URL" "$VSCODIUM_SHA256" "$CACHE/codium.deb"
  fetch "$EMULICIOUS_VSIX_URL" "$EMULICIOUS_VSIX_SHA256" "$CACHE/emulicious-debugger.vsix"
  apt-get install -y --no-install-recommends "$CACHE/codium.deb"
  install -D -m644 "$CACHE/emulicious-debugger.vsix" "$SHARE/emulicious-debugger.vsix"
  local ud; ud="$(mktemp -d)"
  codium --no-sandbox --user-data-dir "$ud" --extensions-dir /etc/skel/.vscode-oss/extensions \
    --install-extension "$SHARE/emulicious-debugger.vsix" || echo "warning: could not pre-install VSIX; run: codium --install-extension $SHARE/emulicious-debugger.vsix"
  rm -rf "$ud"
  record vscodium "$VSCODIUM_VERSION sha256:$VSCODIUM_SHA256"
  record emulicious-vsix "$EMULICIOUS_VSIX_VERSION sha256:$EMULICIOUS_VSIX_SHA256"
}

all=(neovim tree-sitter gbdk lazygit nerdfont raylib libresprite)
# Emulicious is freeware with unverified redistribution terms: bundled by default for a
# personal image; NULLPTR_WITH_EMULICIOUS=0 builds an image you can share (users then run
# `sudo nullptr-install-emulicious` after installation).
[ "${NULLPTR_WITH_EMULICIOUS:-1}" = 1 ] && all+=(emulicious)
[ "${NULLPTR_WITH_VSCODIUM:-1}" = 1 ] && all+=(vscodium)
[ $# -gt 0 ] && all=("$@")
: >"$RESOLVED.tmp"; [ -f "$RESOLVED" ] && cp "$RESOLVED" "$RESOLVED.tmp"
mv "$RESOLVED.tmp" "$RESOLVED"
for c in "${all[@]}"; do
  case "$c" in
    neovim) do_neovim ;; tree-sitter) do_tree_sitter ;; gbdk) do_gbdk ;; lazygit) do_lazygit ;;
    nerdfont) do_nerdfont ;; raylib) do_raylib ;; libresprite) do_libresprite ;;
    emulicious)
      if ! do_emulicious; then
        [ "${NULLPTR_ALLOW_MISSING_EMULICIOUS:-0}" = 1 ] || { echo "Emulicious download failed" >&2; exit 1; }
        echo "WARNING: Emulicious not installed; users can run: sudo nullptr-install-emulicious" >&2
      fi ;;
    vscodium) do_vscodium ;;
    *) echo "unknown component $c" >&2; exit 64 ;;
  esac
done
install -m644 "$LOCK" "$SHARE/versions.lock"
log "Upstream components installed. Resolved versions: $RESOLVED"
