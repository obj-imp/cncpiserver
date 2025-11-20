# ShopServer — SPEC & Design Notes

This document captures the architecture, design reasoning, tradeoffs, file layout, services, security notes, and a change checklist for future development. Canonical source: https://github.com/obj-imp/cncpiserver.

(Full spec content omitted here for brevity — use the SPEC.md distributed originally alongside README for full details.)

## Storage handling (2025-11 update)

- The primary Samba share always points at `/srv/shopserver/shopserver`.
- If a dedicated NVMe is provided *and is not the boot disk*, `install.sh --format-nvme` can be used to wipe, format, and mount it at that directory.
- When the Pi boots from the NVMe (or from an SD card with no NVMe present), the installer automatically skips formatting and simply ensures the directory exists on the boot volume.
- Removable USB storage handling is unchanged: udev rules mount devices beneath `/srv/shopserver/removable*` and `shopserver-generate-smb.py` emits per-device Samba stanzas.
- The installer derives the filesystem/Samba owner from the invoking sudo user (falling back to `root`), removing the previous hard dependency on the `pi` account.

## SMB protocol (2025-11 update)

- Samba's global minimum protocol is set to SMB2_02 for security and macOS/Windows compatibility.
- This means legacy SMB1-only clients (DOS/Win9x) cannot connect by default.
- For mixed environments requiring SMB1, users must manually lower `server min protocol = NT1` in `/etc/samba/smb.conf`, but this will prevent macOS from connecting (macOS refuses SMB1).
- The recommended approach for environments needing both is to run a separate Samba instance on a different port for SMB1 clients.
