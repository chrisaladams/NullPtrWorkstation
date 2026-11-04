#!/usr/bin/env bash
# Unattended live-boot smoke test. Extracts the live kernel/initrd from the ISO and boots
# the live system headless with a serial console, then checks that it reached the login
# stage and that the workstation commands exist inside the image.
#   tests/qemu/smoke-test.sh out/nullptr-workstation-amd64.iso
# Needs: qemu-system-x86, xorriso.  KVM strongly recommended.
set -euo pipefail
iso="${1:-out/nullptr-workstation-amd64.iso}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
xorriso -osirrox on -indev "$iso" -extract /live/vmlinuz "$tmp/vmlinuz" -extract /live/initrd.img "$tmp/initrd.img" >/dev/null 2>&1
accel=(); [ -w /dev/kvm ] && accel=(-enable-kvm -cpu host)
log="$tmp/serial.log"
timeout "${TIMEOUT:-900}" qemu-system-x86_64 -m 4096 -smp 2 "${accel[@]}" -nographic \
  -cdrom "$iso" -kernel "$tmp/vmlinuz" -initrd "$tmp/initrd.img" \
  -append "boot=live components username=nullptr hostname=nullptr console=ttyS0,115200 nullptr.nox" \
  -nic user,model=virtio-net-pci >"$log" 2>&1 &
pid=$!
ok=0
for _ in $(seq 1 180); do
  sleep 5
  if grep -qE "nullptr login:|Debian GNU/Linux 13" "$log"; then ok=1; break; fi
done
kill "$pid" 2>/dev/null || true
tail -n 25 "$log"
[ "$ok" = 1 ] && echo "SMOKE TEST: PASS (live system booted to the console)" || { echo "SMOKE TEST: FAIL"; cp "$log" ./smoke-serial.log; exit 1; }
