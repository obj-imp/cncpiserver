# ShopServer (Raspberry Pi 5) — README

This repository contains the installer and supporting files for ShopServer:
a headless Raspberry Pi 5 NVMe-based file server that exposes:

- `main` network share (on NVMe)
- auto-mounted `removable`, `removable2`, ... shares for USB disks
- a minimal Flask web UI (status, access logs)
- udev-based auto-mounting and Samba share generation

See SPEC.md for architecture and design reasoning.

---

Quick start (target: fresh Pi OS 64-bit):

1. Flash Raspberry Pi OS (64-bit) and enable SSH (create `ssh` file on boot).
2. SSH into the Pi and copy this repository to the Pi (or `git clone` if served).
3. Make `install.sh` executable:
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
4. To format an NVMe and use it as `main`, pass:
   ```bash
   sudo ./install.sh --format-nvme /dev/nvme0n1
   ```
   The script will require an explicit `YES` confirmation before destructive actions.

Files included in this repo:
- `install.sh` — interactive installer (supports `--format-nvme`)
- `README.md`, `SPEC.md` — docs
- `packaging/` — templates of files the installer will deploy to the system:
  - `usr-local-bin/` scripts (`shopserver-device-handler.sh`, `shopserver-generate-smb.py`, `shopserver-inotify-watcher.py`)
  - `etc-systemd/` service unit templates
  - `etc-udev/` udev rule
  - `opt-shopserver-ui/` Flask app & templates
  - `etc-samba/` sample smb.conf and smb.d/main.conf

You can inspect files and then run the installer on the Pi. The installer will copy these templates into the appropriate system locations.
