#!/usr/bin/env bash
# build-iso.sh — build nullptr-workstation-amd64.iso (Debian 13 "trixie", amd64).
#
# Usage
#   sudo ./build-iso.sh                 # on a Debian 13 host (installs live-build if missing)
#   ./build-iso.sh --docker             # on any Linux host with Docker: builds inside debian:trixie
#   sudo ./build-iso.sh --preflight     # only check package names + upstream URLs, no build
#   sudo ./build-iso.sh --clean         # remove the build tree (keeps the package cache)
#
# Output (in ./out/)
#   nullptr-workstation-amd64.iso          the hybrid ISO (USB stick or DVD, BIOS + UEFI)
#   nullptr-workstation-amd64.iso.sha256   checksum
#   packages.manifest                      every Debian package + version in the live system
#   versions.resolved                      every non-Debian component actually installed
#   build.log                              full live-build log
#
# Needs: ~25 GB free disk, network access to deb.debian.org, security.debian.org,
# github.com (+ release-assets.githubusercontent.com) and emulicious.net.
#
# Options (environment variables)
#   NULLPTR_WITH_EMULICIOUS=0   do not bundle Emulicious (for an ISO you will share)
#   NULLPTR_WITH_VSCODIUM=0     skip the VSCodium fallback debugger UI (saves ~400 MB)
#   NULLPTR_MIRROR=URL          Debian mirror (default http://deb.debian.org/debian/)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${NULLPTR_WORK:-$REPO/work}"
OUT="$REPO/out"
ISO_NAME="nullptr-workstation-amd64.iso"
DEBIAN_IMAGE="${NULLPTR_DEBIAN_IMAGE:-debian:trixie}"

log()  { printf '\n\033[1;34m[build-iso]\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m[build-iso] %s\033[0m\n' "$*" >&2; exit 1; }

mode=build
case "${1:-}" in
  --docker) mode=docker ;;
  --preflight) mode=preflight ;;
  --clean) mode=clean ;;
  --inside-docker) mode=build ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  "") ;;
  *) die "unknown option $1 (see --help)" ;;
esac

if [ "$mode" = docker ]; then
  command -v docker >/dev/null || die "docker not found"
  log "Building inside $DEBIAN_IMAGE (privileged: live-build needs mount/chroot)"
  exec docker run --rm --privileged \
    -e NULLPTR_MIRROR -e NULLPTR_SECURITY_MIRROR -e NULLPTR_WITH_VSCODIUM -e NULLPTR_WITH_EMULICIOUS \
    -e NULLPTR_ALLOW_MISSING_EMULICIOUS -e EMULICIOUS_SHA256 \
    -v "$REPO":/nullptr-workstation -w /nullptr-workstation \
    "$DEBIAN_IMAGE" ./build-iso.sh --inside-docker
fi

[ "$(id -u)" = 0 ] || die "run as root (sudo ./build-iso.sh), or use --docker"

if [ "$mode" = clean ]; then
  [ -d "$WORK" ] && (cd "$WORK" && lb clean --purge >/dev/null 2>&1 || true)
  rm -rf "$WORK"
  log "Removed $WORK"; exit 0
fi

# ---------------------------------------------------------------- host checks
. /etc/os-release
if [ "${VERSION_CODENAME:-}" != trixie ]; then
  die "Build on Debian 13 (trixie) or use --docker (this host is ${PRETTY_NAME:-unknown})."
fi
log "Installing build tools (live-build, debootstrap, xorriso, …)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends live-build debootstrap xorriso squashfs-tools \
  mtools dosfstools grub-efi-amd64-bin grub-pc-bin syslinux syslinux-common isolinux \
  ca-certificates curl git rsync >/dev/null

# ---------------------------------------------------------------- preflight
# Every package name must exist in trixie (main contrib non-free non-free-firmware);
# a typo would otherwise fail an hour into the build.
log "Preflight: checking package names against the Debian 13 archive"
MIRROR="${NULLPTR_MIRROR:-http://deb.debian.org/debian/}"
PF="$(mktemp -d)"
mkdir -p "$PF/lists/partial" "$PF/cache/archives/partial"
cat >"$PF/sources.list" <<EOF
deb $MIRROR trixie main contrib non-free non-free-firmware
deb $MIRROR trixie-updates main contrib non-free non-free-firmware
deb ${NULLPTR_SECURITY_MIRROR:-http://security.debian.org/debian-security/} trixie-security main contrib non-free non-free-firmware
EOF
APTOPT=(-o "Dir::Etc::sourcelist=$PF/sources.list" -o "Dir::Etc::sourceparts=-" -o "Dir::State::Lists=$PF/lists"
        -o "Dir::Cache=$PF/cache" -o "APT::Architecture=amd64" -o "Debug::NoLocking=1")
apt-get "${APTOPT[@]}" update -qq
missing=()
for f in "$REPO"/packages/*.list; do
  while read -r p; do
    p="${p%%#*}"; p="$(echo "$p" | xargs)"; [ -n "$p" ] || continue
    apt-cache "${APTOPT[@]}" show "$p" >/dev/null 2>&1 || missing+=("$p ($(basename "$f"))")
  done <"$f"
done
rm -rf "$PF"
if [ "${#missing[@]}" -gt 0 ]; then
  printf '  missing: %s\n' "${missing[@]}" >&2
  die "Some packages do not exist in trixie. Fix packages/*.list."
fi
log "All package names exist."
log "Preflight: checking pinned upstream downloads are reachable"
# shellcheck source=versions.lock
. "$REPO/versions.lock"
urls=("$NVIM_URL" "$GBDK_URL" "$LAZYGIT_URL" "$NERDFONT_URL" "$TREESITTER_CLI_URL")
[ "${NULLPTR_WITH_EMULICIOUS:-1}" = 1 ] && urls+=("$EMULICIOUS_URL")
[ "${NULLPTR_WITH_VSCODIUM:-1}" = 1 ] && urls+=("$VSCODIUM_URL" "$EMULICIOUS_VSIX_URL")
for u in "${urls[@]}"; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' -I -L --max-time 30 "$u" || echo 000)"
  case "$code" in 2*) echo "  ok   $u" ;; *) echo "  FAIL ($code) $u"; [ "$u" = "$EMULICIOUS_URL" ] && [ "${NULLPTR_ALLOW_MISSING_EMULICIOUS:-0}" = 1 ] || die "unreachable: $u" ;; esac
done
for g in "$RAYLIB_GIT" "$LIBRESPRITE_GIT" https://github.com/folke/lazy.nvim https://github.com/AstroNvim/AstroNvim; do
  git ls-remote --exit-code "$g" HEAD >/dev/null 2>&1 && echo "  ok   $g" || die "git unreachable: $g"
done
[ "$mode" = preflight ] && { log "Preflight passed."; exit 0; }

# ---------------------------------------------------------------- assemble the live-build tree
log "Assembling live-build tree in $WORK"
mkdir -p "$WORK"
cd "$WORK"
lb clean --binary >/dev/null 2>&1 || true
rm -rf config auto
cp -a "$REPO/config/live/auto" auto
lb config >/dev/null
# hooks
mkdir -p config/hooks/live config/package-lists
cp -a "$REPO"/config/live/hooks/live/*.hook.chroot config/hooks/live/
# package lists
for f in "$REPO"/packages/*.list; do
  grep -v '^\s*#' "$f" | sed '/^\s*$/d' >"config/package-lists/$(basename "${f%.list}").list.chroot"
done
# the repository itself goes into the image: the hooks install from it, and it
# documents exactly how the image was built (/usr/local/src/nullptr-workstation)
SRC=config/includes.chroot/usr/local/src/nullptr-workstation
mkdir -p "$SRC"
rsync -a --delete --exclude /work --exclude /out --exclude /.git "$REPO"/ "$SRC"/
git -C "$REPO" rev-parse HEAD >"$SRC/BUILD-COMMIT" 2>/dev/null || echo unknown >"$SRC/BUILD-COMMIT"
# live-build does not pass the host environment into chroot hooks: hand over the switches
cat >"$SRC/build.env" <<EOF
NULLPTR_WITH_EMULICIOUS=${NULLPTR_WITH_EMULICIOUS:-1}
NULLPTR_WITH_VSCODIUM=${NULLPTR_WITH_VSCODIUM:-1}
NULLPTR_ALLOW_MISSING_EMULICIOUS=${NULLPTR_ALLOW_MISSING_EMULICIOUS:-0}
EMULICIOUS_SHA256=${EMULICIOUS_SHA256:-}
EOF
# debian-installer preseed (account name only; password and disks stay interactive)
mkdir -p config/includes.installer
cp "$REPO/installer/preseed.cfg" config/includes.installer/preseed.cfg

# ---------------------------------------------------------------- build
log "Running live-build (this takes 30–90 minutes)"
lb build 2>&1 | tee "$WORK/build.log"
iso="$(ls -1 "$WORK"/nullptr-workstation-amd64*.iso 2>/dev/null | head -n1)"
[ -n "$iso" ] || die "live-build finished without an ISO; see $WORK/build.log"

mkdir -p "$OUT"
mv -f "$iso" "$OUT/$ISO_NAME"
(cd "$OUT" && sha256sum "$ISO_NAME" >"$ISO_NAME.sha256")
cp "$WORK/build.log" "$OUT/build.log"
cp "$WORK"/chroot.packages.live "$OUT/packages.manifest" 2>/dev/null || true
cp "$WORK/chroot/usr/local/share/nullptr/versions.resolved" "$OUT/versions.resolved" 2>/dev/null || true
log "Done:"
ls -lh "$OUT"
cat "$OUT/$ISO_NAME.sha256"
