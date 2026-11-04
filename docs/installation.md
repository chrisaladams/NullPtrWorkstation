# Installing nullptr Workstation

Target: Lenovo ThinkPad X1 Carbon Gen 6 (x86_64). Base: Debian 13 "trixie" amd64.

## 1. Build the ISO

The ISO is built from this repository with Debian's `live-build`. It takes 30–90 minutes,
~25 GB of disk, and network access to `deb.debian.org`, `security.debian.org`, `github.com`
(+ `release-assets.githubusercontent.com`) and `emulicious.net`.

On a Debian 13 machine:

```bash
sudo ./build-iso.sh
```

On any other Linux machine with Docker (builds inside the official `debian:trixie` image):

```bash
./build-iso.sh --docker
```

Check names and download URLs first without building:

```bash
sudo ./build-iso.sh --preflight
```

Results land in `out/`:

| File | Purpose |
|---|---|
| `nullptr-workstation-amd64.iso` | hybrid ISO, boots from USB or DVD, BIOS and UEFI |
| `nullptr-workstation-amd64.iso.sha256` | checksum |
| `packages.manifest` | every Debian package and version in the image |
| `versions.resolved` | every non-Debian component that was installed, with hashes/commits |
| `build.log` | complete live-build log |

Build switches (environment variables):

| Variable | Default | Effect |
|---|---|---|
| `NULLPTR_WITH_EMULICIOUS` | `1` | `0` = don't bundle Emulicious (use this for an ISO you give to other people; see [licenses.md](licenses.md)) |
| `NULLPTR_WITH_VSCODIUM` | `1` | `0` = skip the VSCodium fallback debugger UI (saves ~400 MB) |
| `NULLPTR_MIRROR` | `http://deb.debian.org/debian/` | Debian mirror |

## 2. Verify and write the USB stick

```bash
cd out && sha256sum -c nullptr-workstation-amd64.iso.sha256
```

Find the stick's device name **carefully** (`lsblk`; compare before/after plugging it in).
Everything on it is erased:

```bash
sudo dd if=out/nullptr-workstation-amd64.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

## 3. ThinkPad X1 Carbon Gen 6 firmware settings

Press Enter then F1 at power-on:

- *Config ▸ Power ▸ Sleep State* → **Linux** (S3). Without it suspend uses "Windows Modern
  Standby" (s2idle), which drains more battery.
- *Security ▸ Secure Boot* can stay enabled (Debian's shim/GRUB are signed). Disable it if
  the stick does not show up.
- *Startup ▸ UEFI/Legacy Boot* → UEFI Only.

Boot the stick with F12.

## 4. The boot menu

| Entry | What it does |
|---|---|
| **Live system** | try everything without installing (user `nullptr`, auto-login on tty1, nothing is saved) |
| **Graphical install** | debian-installer, mouse-driven |
| **Install** | debian-installer, text mode |

## 5. Installation walkthrough

The installer is Debian's own installer (`debian-installer` in "live" mode: it copies the
live system to disk). Only the account name is pre-filled:

1. Language, location, keyboard: your choice.
2. Network: Wi-Fi is offered if the firmware loaded (it is on the ISO). You can skip it;
   the system installs offline.
3. Hostname: suggested `nullptr`, editable.
4. **User account:** the user `nullptr` (home `/home/nullptr`) is fixed. You are asked to
   **choose a password and type it again**. No password is built in anywhere. There is no
   root password: `nullptr` gets `sudo`, which asks for *your* password.
5. Time zone.
6. **Partitioning:** nothing is automatic. Choose *Guided – use entire disk* (optionally
   *with encrypted LVM*), or *Manual*. The installer shows the full plan and asks
   **"Write the changes to disks?"**, which defaults to **No**. Nothing is written before you
   answer Yes.
7. GRUB is installed. Remove the stick and reboot.

## 6. First boot

1. A text login prompt appears on tty1.
2. Log in as `nullptr` with your password.
3. Xorg and i3 start automatically, and kitty opens fullscreen on workspace 1.
4. kitty attaches to the tmux session `dev` and AstroVim shows the dashboard.

Then run the 10-minute tutorial: press `H` on the dashboard, or type `helpme tutorial` in a
terminal ([first-use.md](first-use.md)).

First things worth doing:

```bash
nmtui                                    # connect Wi-Fi
sudo apt update && sudo apt full-upgrade # security updates
gb-info                                  # Game Boy toolchain status
```

If Emulicious was not bundled (`NULLPTR_WITH_EMULICIOUS=0`), install it now, while
online:

```bash
sudo nullptr-install-emulicious
```

## 7. Installing onto an existing Debian 13 system (without the ISO)

```bash
sudo apt install $(grep -hv '^#' packages/base.list packages/desktop.list packages/devel.list packages/gamedev.list)
sudo ./scripts/install/install-upstream.sh
sudo ./scripts/install/install-workstation.sh
sudo adduser nullptr                     # or copy /etc/skel contents into an existing home
```

`install-workstation.sh` only writes system locations and `/etc/skel`. It never modifies
existing home directories.
