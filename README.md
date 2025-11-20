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

## Dual-protocol architecture

ShopServer runs **two separate Samba instances** to support all client types:

1. **Modern instance** (port 445): SMB2/SMB3 for macOS, Windows 10+, and Linux
2. **Legacy instance** (port 4450): SMB1 for DOS and Windows 9x

Both instances serve the same files from `/srv/shopserver/shopserver`. This allows:
- macOS to connect securely via SMB2+ without being blocked by SMB1
- DOS/Win9x to connect via SMB1 on a dedicated port
- All clients to access the same shared files

### Connection methods

**Modern clients (macOS, Windows 10+, Linux):**
- macOS: `⌘K` → `smb://shopserver/main`
- Windows: `\\shopserver\main`
- Linux: `mount -t cifs -o vers=3.0 //shopserver/main /mnt`

**Legacy clients (DOS, Windows 9x):**
- DOS: `net use z: \\shopserver:4450\main`
- Win9x: Map network drive to `\\shopserver:4450\main`

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
6. After installation, connect based on your client type (see "Connection methods" above).

Files included in this repo:
- `install.sh` — interactive installer (supports `--format-nvme`)
- `README.md`, `SPEC.md` — docs
- `packaging/` — templates of files the installer will deploy to the system:
  - `usr-local-bin/` scripts (`shopserver-device-handler.sh`, `shopserver-generate-smb.py`, `shopserver-inotify-watcher.py`)
  - `etc-systemd/` service unit templates
  - `etc-udev/` udev rule
  - `opt-shopserver-ui/` Flask app & templates
  - `etc-samba/` sample `smb.conf` (SMB2+), `smb-legacy.conf` (SMB1), `smb.d/main.conf`, `smb.d/removable.conf`

You can inspect files and then run the installer on the Pi. The installer will copy these templates into the appropriate system locations.
