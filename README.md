# ShopServer (Raspberry Pi 4/5) — README

This repository contains the installer and supporting files for ShopServer:
a headless Raspberry Pi 4/5 file server that exposes:

- `main` network share (backs the `/srv/shopserver/shopserver` directory; if a dedicated NVMe is formatted it will be mounted there)
- auto-mounted `removable`, `removable2`, ... shares for USB disks
- a minimal Flask web UI (status, access logs)
- udev-based auto-mounting and Samba share generation

Canonical GitHub repository: https://github.com/obj-imp/cncpiserver

See SPEC.md for architecture and design reasoning.

---

## Shares & protocols

- Modern SMB2+/SMB3 clients (macOS, Windows, Linux) should use `\\<hostname>\main`.
- Legacy SMB1-only clients (DOS/Win9x) should use `\\<hostname>\<hostname>-smb1` (the installer appends `-smb1` to whatever hostname you choose).
- Removable disks are exported twice: `removable`, `removable2`, … for SMB2+/SMB3 and `removable-smb1`, `removable2-smb1`, … for SMB1-only machines. All variants point at the same mounted directories.
- SMB1 support requires weaker authentication (LANMAN/NTLMv1) which the installer enables automatically; use the SMB1 shares only when needed.

---

Quick start (target: fresh Pi OS 64-bit):

1. Flash Raspberry Pi OS (64-bit) and enable SSH (create `ssh` file on boot).
2. SSH into the Pi and copy this repository to the Pi (or clone it directly:
   `git clone https://github.com/obj-imp/cncpiserver.git`).
3. Make `install.sh` executable:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
4. To format a *non-boot* NVMe and use it for the `main` share, pass:
   ```bash
   sudo ./install.sh --format-nvme /dev/nvme0n1
   ```
   The script will require an explicit `YES` confirmation before destructive actions.
   If the Pi is already booting from that NVMe (or from an SD card), the installer will refuse to format it
   and will instead create `/srv/shopserver/shopserver` on the boot volume for the primary share.
5. The installer automatically picks the invoking sudo user (or `root` if unavailable) as the filesystem owner and Samba `force user`,
   so it works on systems that do not provide the historical `pi` account.
6. After installation you can:
   - From macOS Finder: `Cmd+K` → `smb://shopserver/main` (replace `shopserver` with your hostname or IP).
   - From legacy DOS/Win9x systems: `net use z: \\shopserver\shopserver-smb1`.
   - From Linux: `mount -t cifs -o vers=3.0 //shopserver/main /mnt/shopserver`.

Files included in this repo:
- `install.sh` — interactive installer (supports `--format-nvme`)
- `README.md`, `SPEC.md` — docs
- `packaging/` — templates of files the installer will deploy to the system:
  - `usr-local-bin/` scripts (`shopserver-device-handler.sh`, `shopserver-generate-smb.py`, `shopserver-inotify-watcher.py`)
  - `etc-systemd/` service unit templates
  - `etc-udev/` udev rule
  - `opt-shopserver-ui/` Flask app & templates
  - `etc-samba/` sample `smb.conf`, `smb.d/main.conf`, `smb.d/main-smb1.conf`, `smb.d/removable*.conf`

You can inspect files and then run the installer on the Pi. The installer will copy these templates into the appropriate system locations.
