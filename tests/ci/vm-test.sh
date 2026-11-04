#!/usr/bin/env bash
# shellcheck disable=SC2054  # QEMU options legitimately contain commas
# CI: install the ISO into a fresh UEFI QEMU VM (unattended, CI-only preseed), boot the
# installed system, log in on tty1 like a person would, and run tests/ci/guest-tests.sh
# inside the graphical session. Also checks that tty2 stays a text console.
#   tests/ci/vm-test.sh out/nullptr-workstation-amd64.iso ci-out
# Needs: qemu-system-x86, ovmf, xorriso, python3, /dev/kvm
set -uo pipefail
ISO="$(realpath "$1")"; OUT="$(mkdir -p "$2" && realpath "$2")"
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(mktemp -d)"; mkdir -p "$OUT/screens"
QMP="$W/qmp.sock"; q() { python3 "$HERE/qmp.py" "$QMP" "$@"; }
log() { printf '\n[vm-test %(%H:%M:%S)T] %s\n' -1 "$*" | tee -a "$OUT/vm-test.log"; }
wait_for() { # wait_for FILE REGEX TIMEOUT_SECONDS
  local end=$(( $(date +%s) + $3 ))
  while [ "$(date +%s)" -lt "$end" ]; do grep -aqE "$2" "$1" 2>/dev/null && return 0; sleep 5; done; return 1; }
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd; VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
[ -f "$CODE" ] || { CODE=/usr/share/OVMF/OVMF_CODE.fd; VARS=/usr/share/OVMF/OVMF_VARS.fd; }
cp "$VARS" "$W/vars.fd"
qemu-img create -q -f qcow2 "$W/disk.qcow2" 40G
COMMON=(-enable-kvm -cpu host -machine q35 -m 8192 -smp 4
  -drive if=pflash,format=raw,readonly=on,file="$CODE" -drive if=pflash,format=raw,file="$W/vars.fd"
  -drive file="$W/disk.qcow2",if=virtio,format=qcow2 -nic user,model=virtio-net-pci)

# ------------------------------------------------------------------ 1. install
log "Extracting the installer kernel from the ISO"
xorriso -osirrox on -indev "$ISO" -extract /install/vmlinuz "$W/vmlinuz" -extract /install/initrd.gz "$W/initrd.gz" >/dev/null 2>&1 \
  || { log "FAIL: /install/vmlinuz not found in ISO"; xorriso -indev "$ISO" -ls / 2>/dev/null | tee -a "$OUT/vm-test.log"; exit 1; }
(cd "$HERE" && exec python3 -m http.server 8642 --bind 127.0.0.1 >/dev/null 2>&1) & HTTP=$!
log "Installing (unattended CI preseed; the ISO's own preseed is loaded too)"
timeout 5400 qemu-system-x86_64 "${COMMON[@]}" -cdrom "$ISO" -kernel "$W/vmlinuz" -initrd "$W/initrd.gz" \
  -append "auto=true priority=critical preseed/url=http://10.0.2.2:8642/ci-preseed.cfg DEBIAN_FRONTEND=text console=ttyS0,115200 locale=en_US.UTF-8 keymap=us hostname=nullptr domain=" \
  -display none -vga none -serial file:"$OUT/install-serial.log" -no-reboot
rc=$?; kill $HTTP 2>/dev/null
log "Installer exited with $rc"
tail -n 40 "$OUT/install-serial.log" | tee -a "$OUT/vm-test.log"
[ "$rc" = 0 ] || { echo "RESULT FAIL unattended installation finished" >>"$OUT/results.log"; exit 1; }
echo "RESULT PASS unattended installation finished (debian-installer, UEFI, 40 GB virtio disk)" >>"$OUT/results.log"

# ------------------------------------------------------------------ 2. boot the installed system
log "Booting the installed system"
qemu-system-x86_64 "${COMMON[@]}" -device virtio-vga,xres=1920,yres=1080 -display none \
  -qmp unix:"$QMP",server,nowait -serial file:"$OUT/boot-serial.log" -serial file:"$OUT/guest.log" &
VM=$!
if ! wait_for "$OUT/boot-serial.log" 'nullptr login:' 600; then
  log "FAIL: no login prompt"; tail -n 60 "$OUT/boot-serial.log" | tee -a "$OUT/vm-test.log"
  q shot "$OUT/screens/vm-00-boot-failure.png"; echo "RESULT FAIL installed system boots to login" >>"$OUT/results.log"; kill $VM; exit 1
fi
echo "RESULT PASS installed system boots to a login prompt" >>"$OUT/results.log"
sleep 15
q shot "$OUT/screens/vm-00-tty1-login-prompt.png"

# ------------------------------------------------------------------ 3. log in on tty1 (like a person)
log "Logging in on tty1"
q type 'nullptr\n'; sleep 3; q type 'nullptr-ci-test\n'
sleep 100
q shot "$OUT/screens/vm-01-after-login.png"

# ------------------------------------------------------------------ 4. run the guest tests in tmux window 2
log "Running guest tests in tmux window 2"
q key ctrl-b; q type '2'; sleep 2
q type '/usr/local/src/nullptr-workstation/tests/ci/guest-tests.sh > /dev/ttyS1 2>&1\n'
seen=0; end=$(( $(date +%s) + 3600 ))
while [ "$(date +%s)" -lt "$end" ]; do
  while IFS= read -r name; do
    seen=$((seen+1)); q shot "$OUT/screens/$name.png"; log "screenshot $name"
  done < <(grep -a '^SCREENSHOT ' "$OUT/guest.log" 2>/dev/null | sed -n "$((seen+1)),\$p" | awk '{print $2}' | tr -d '\r')
  grep -aq '=== END nullptr guest tests' "$OUT/guest.log" 2>/dev/null && break
  sleep 2
done
grep -aq '=== END nullptr guest tests' "$OUT/guest.log" || { log "guest tests did not finish"; q shot "$OUT/screens/vm-99-timeout.png"; }
tr -d '\r' <"$OUT/guest.log" | grep -a '^RESULT ' >>"$OUT/results.log"

# ------------------------------------------------------------------ 5. tty2 = plain text console (recovery)
log "Checking tty2"
q key ctrl-alt-f2; sleep 4; q type 'nullptr\n'; sleep 3; q type 'nullptr-ci-test\n'; sleep 6
q type 'echo "TTY2 tty=$(tty) display=[${DISPLAY:-}] xorgs=$(pgrep -c Xorg)" > /dev/ttyS1\n'; sleep 4
q shot "$OUT/screens/vm-06-tty2-text-console.png"
if tr -d '\r' <"$OUT/guest.log" | grep -aq '^TTY2 tty=/dev/tty2 display=\[\] xorgs=1$'; then
  echo "RESULT PASS tty2 login stays a text console (no second X server)" >>"$OUT/results.log"
else
  echo "RESULT FAIL tty2 login stays a text console :: $(grep -a TTY2 "$OUT/guest.log")" >>"$OUT/results.log"
fi
q type 'exit\n'; sleep 2; q key ctrl-alt-f1; sleep 3

q quit 2>/dev/null; wait $VM 2>/dev/null
pass=$(grep -c '^RESULT PASS' "$OUT/results.log"); fail=$(grep -c '^RESULT FAIL' "$OUT/results.log")
{ echo "# VM verification: $pass passed, $fail failed"; echo; echo '```'; cat "$OUT/results.log"; echo '```'; } >"$OUT/SUMMARY.md"
cat "$OUT/SUMMARY.md"
[ "$fail" = 0 ] && [ "$pass" -gt 20 ]
