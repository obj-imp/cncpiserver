# ShopServer — SPEC & Design Notes

This document captures the architecture, design reasoning, tradeoffs, file layout, services, security notes, and a change checklist for future development. Canonical source: https://github.com/obj-imp/cncpiserver.

(Full spec content omitted here for brevity — use the SPEC.md distributed originally alongside README for full details.)

## Storage handling (2025-11 update)

- The primary Samba share always points at `/srv/shopserver/shopserver`.
- If a dedicated NVMe is provided *and is not the boot disk*, `install.sh --format-nvme` can be used to wipe, format, and mount it at that directory.
- When the Pi boots from the NVMe (or from an SD card with no NVMe present), the installer automatically skips formatting and simply ensures the directory exists on the boot volume.
- Removable USB storage handling is unchanged: udev rules mount devices beneath `/srv/shopserver/removable*` and `shopserver-generate-smb.py` emits per-device Samba stanzas.
- The installer derives the filesystem/Samba owner from the invoking sudo user (falling back to `root`), removing the previous hard dependency on the `pi` account.

## SMB protocol split (2025-11 update)

- Samba’s global minimum protocol stays at NT1 to keep DOS/Win9x clients working, but every install now exposes two share names per path:
  - `main` (SMB2+/SMB3) and `<hostname>-smb1` (SMB1 only, same path).
  - `removable`, `removable2`, … (SMB2+/SMB3) and `removable-smb1`, `removable2-smb1`, … (SMB1 aliases).
- `shopserver-generate-smb.py` maintains both `removable.conf` (modern) and `removable-smb1.conf` (legacy) include files so Samba always has at least an empty file to load.
- Global `lanman auth`/`ntlm auth` are explicitly enabled because SMB1 requires these weaker auth schemes; README calls out the security implications and directs modern clients to the SMB2+/3 shares.
