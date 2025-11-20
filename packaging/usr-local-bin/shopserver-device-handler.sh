#!/usr/bin/env bash
set -euo pipefail
ACTION="$1"
DEVPATH="$2"
CONFIG="/etc/shopserver/config.yaml"

# load config
eval $(python3 - <<PY - "$CONFIG"
import sys,yaml
cfg=yaml.safe_load(open(sys.argv[1]))
print("REMBASE='{}'".format(cfg.get("removable_base","/srv/shopserver/removable")))
PY
)

ensure_dir() { mkdir -p "$1"; chown pi:pi "$1"; chmod 2775 "$1"; }

if [ "$ACTION" = "add" ]; then
  sleep 0.5
  PART=""
  if lsblk -ln "$DEVPATH" | awk '{print $1}' | grep -q -E "$(basename "$DEVPATH")"; then
    CHILD=$(lsblk -ln -o NAME "$DEVPATH" | sed -n '2p' || true)
    if [ -n "$CHILD" ]; then
      PART="/dev/${CHILD}"
    else
      PART="$DEVPATH"
    fi
  else
    PART="$DEVPATH"
  fi

  idx=1
  while [ -e "${REMBASE}/removable${idx}" ] && mountpoint -q "${REMBASE}/removable${idx}"; do
    idx=$((idx+1))
  done
  if [ "$idx" -eq 1 ]; then name="removable"; dir="${REMBASE}/removable"; else name="removable${idx}"; dir="${REMBASE}/${name}"; fi
  ensure_dir "$dir"

  UUID=$(blkid -s UUID -o value "$PART" || true)
  if [ -n "$UUID" ]; then
    grep -q "$UUID" /etc/fstab || echo "UUID=${UUID} ${dir} auto nosuid,nodev,nofail,x-gvfs-show,uid=1000,gid=1000,umask=0002 0 0" >> /etc/fstab
    mount "${dir}" || true
    if ! mountpoint -q "$dir"; then
      mount "$dir" || mount -t auto "/dev/disk/by-uuid/$UUID" "$dir" || mount "$PART" "$dir"
    fi
  else
    mount -t auto "$PART" "$dir" || mount "$PART" "$dir"
  fi

  /usr/local/bin/shopserver-generate-smb.py
  systemctl try-restart smbd || true
  logger "shopserver: mounted $PART at $dir and reloaded smb"
  echo "$(date -u --iso-8601=seconds) mounted $PART at $dir" >> /var/log/shopserver-mounts.log
  exit 0
fi

if [ "$ACTION" = "remove" ]; then
  for mp in $(mount | awk '{print $3}' | grep "^${REMBASE}" || true); do
    dev=$(findmnt -n -o SOURCE --target "$mp" || true)
    if [ -z "$dev" ]; then continue; fi
    if [[ "$dev" == "$DEVPATH"* || "$dev" == */$(basename "$DEVPATH")* ]]; then
      umount -l "$mp" || true
      sed -i "\|$mp|d" /etc/fstab || true
      rmdir "$mp" || true
      /usr/local/bin/shopserver-generate-smb.py
      systemctl try-restart smbd || true
      logger "shopserver: unmounted $mp for removed device $DEVPATH"
      echo "$(date -u --iso-8601=seconds) removed $DEVPATH unmounted $mp" >> /var/log/shopserver-mounts.log
    fi
  done
  exit 0
fi
