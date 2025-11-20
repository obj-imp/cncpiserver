# ShopServer — SPEC & Design Notes

This document captures the architecture, design reasoning, tradeoffs, file layout, services, security notes, and a change checklist for future development.

(Full spec content omitted here for brevity — use the SPEC.md distributed originally alongside README for full details.)

## Storage handling (2025-11 update)

- The primary Samba share always points at `/srv/shopserver/shopserver`.
- If a dedicated NVMe is provided *and is not the boot disk*, `install.sh --format-nvme` can be used to wipe, format, and mount it at that directory.
- When the Pi boots from the NVMe (or from an SD card with no NVMe present), the installer automatically skips formatting and simply ensures the directory exists on the boot volume.
- Removable USB storage handling is unchanged: udev rules mount devices beneath `/srv/shopserver/removable*` and `shopserver-generate-smb.py` emits per-device Samba stanzas.
