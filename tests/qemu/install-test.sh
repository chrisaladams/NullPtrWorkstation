#!/usr/bin/env bash
# shellcheck disable=SC2054  # QEMU options legitimately contain commas
# Boot the ISO in QEMU and install onto a blank virtual disk (interactive: you choose the
# password and confirm partitioning, exactly as on the laptop).
#   tests/qemu/install-test.sh out/nullptr-workstation-amd64.iso      # UEFI (default)
#   FIRMWARE=bios tests/qemu/install-test.sh out/nullptr-workstation-amd64.iso
# Then boot the installed disk:  tests/qemu/install-test.sh --boot-disk
set -euo pipefail
iso="${1:-out/nullptr-workstation-amd64.iso}"
disk="${DISK:-out/qemu-disk.qcow2}"
mem="${MEM:-6144}"; cpus="${CPUS:-4}"
accel=(); [ -w /dev/kvm ] && accel=(-enable-kvm -cpu host) || echo "warning: no KVM, this will be very slow"
fw=()
if [ "${FIRMWARE:-uefi}" = uefi ]; then
  code=/usr/share/OVMF/OVMF_CODE_4M.fd; vars_src=/usr/share/OVMF/OVMF_VARS_4M.fd
  [ -f "$code" ] || { echo "install ovmf (apt install ovmf) or use FIRMWARE=bios"; exit 1; }
  [ -f out/OVMF_VARS.fd ] || cp "$vars_src" out/OVMF_VARS.fd
  fw=(-drive if=pflash,format=raw,readonly=on,file="$code" -drive if=pflash,format=raw,file=out/OVMF_VARS.fd)
fi
[ -f "$disk" ] || qemu-img create -f qcow2 "$disk" 40G
common=(-m "$mem" -smp "$cpus" "${accel[@]}" "${fw[@]}" -device virtio-vga -display gtk
        -nic user,model=virtio-net-pci -device qemu-xhci -device usb-tablet
        -drive file="$disk",if=virtio,format=qcow2)
if [ "$iso" = --boot-disk ]; then
  exec qemu-system-x86_64 "${common[@]}"
fi
exec qemu-system-x86_64 "${common[@]}" -cdrom "$iso" -boot order=d
