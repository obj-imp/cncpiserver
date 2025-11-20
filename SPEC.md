# ShopServer — SPEC & Design Notes

This document captures the architecture, design reasoning, tradeoffs, file layout, services, security notes, and a change checklist for future development. Canonical source: https://github.com/obj-imp/cncpiserver.

(Full spec content omitted here for brevity — use the SPEC.md distributed originally alongside README for full details.)

## Storage handling (2025-11 update)

- The primary Samba share always points at `/srv/shopserver/shopserver`.
- If a dedicated NVMe is provided *and is not the boot disk*, `install.sh --format-nvme` can be used to wipe, format, and mount it at that directory.
- When the Pi boots from the NVMe (or from an SD card with no NVMe present), the installer automatically skips formatting and simply ensures the directory exists on the boot volume.
- Removable USB storage handling is unchanged: udev rules mount devices beneath `/srv/shopserver/removable*` and `shopserver-generate-smb.py` emits per-device Samba stanzas.
- The installer derives the filesystem/Samba owner from the invoking sudo user (falling back to `root`), removing the previous hard dependency on the `pi` account.

## Dual Samba architecture (2025-11 update)

ShopServer now runs two independent Samba daemons to support incompatible client requirements:

### Modern instance (smbd on port 445)
- Protocol: SMB2_02 minimum, SMB3 maximum
- Clients: macOS (all versions), Windows 10+, modern Linux
- Config: `/etc/samba/smb.conf`
- Service: `smbd.service`, `nmbd.service`
- Log: `/var/log/samba/smb2.log`
- macOS compatibility: Includes `fruit` VFS module for metadata handling

### Legacy instance (smbd-legacy on port 4450)
- Protocol: NT1 (SMB1) only
- Clients: DOS, Windows 9x, legacy systems
- Config: `/etc/samba/smb-legacy.conf`
- Service: `smbd-legacy.service`, `nmbd-legacy.service`
- Log: `/var/log/samba/smb1.log`
- Auth: Enables LANMAN and NTLMv1 for compatibility

### Design rationale
- macOS Ventura+ refuses to connect to servers advertising SMB1 as minimum protocol
- DOS/Win9x cannot negotiate SMB2 or higher
- Running separate instances on different ports allows both to coexist
- Both instances include the same share definitions from `/etc/samba/smb.d/*.conf`
- File permissions and ownership are identical across both instances
