#!/usr/bin/env bash
set -euo pipefail
# install.sh - installer for ShopServer (pi5 target)
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAT_DEVICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format-nvme) FORMAT_DEVICE="$2"; shift 2 ;;
    --help) echo "Usage: sudo ./install.sh [--format-nvme /dev/nvme0n1]"; exit 0 ;;
    *) echo "Unknown arg $1"; exit 1 ;;
  esac
done

DEFAULT_HOSTNAME="shopserver"
DEFAULT_USER="shopserver"
DEFAULT_PASS="shopserver"
SHOPSERVER_ROOT="/srv/shopserver"
SHOPSERVER_DIR_NAME="shopserver"
MAIN_PATH="${SHOPSERVER_ROOT}/${SHOPSERVER_DIR_NAME}"
IMAGES_PATH="${SHOPSERVER_ROOT}/images"
REMOVABLE_BASE="${SHOPSERVER_ROOT}/removable"
ETC_SHOPSERVER_DIR="/etc/shopserver"
CONFIG_PATH="${ETC_SHOPSERVER_DIR}/config.yaml"
SMB_DIR="/etc/samba/smb.d"
UI_DIR="/opt/shopserver/ui"

sanitize_share_name() {
  echo "$1" | tr -c '[:alnum:]._-' '_'
}

DEFAULT_DATA_USER="${SUDO_USER:-pi}"
if ! id -u "$DEFAULT_DATA_USER" >/dev/null 2>&1; then
  DEFAULT_DATA_USER="root"
fi
DEFAULT_DATA_GROUP=$(id -gn "$DEFAULT_DATA_USER" 2>/dev/null || echo "root")
DATA_USER="$DEFAULT_DATA_USER"
DATA_GROUP="$DEFAULT_DATA_GROUP"
DATA_UID=$(id -u "$DATA_USER" 2>/dev/null || echo 0)
DATA_GID=$(id -g "$DATA_USER" 2>/dev/null || echo 0)

canonical_block_path() {
  local dev="$1"
  if [ -z "$dev" ]; then
    echo ""
    return
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath "$dev" 2>/dev/null && return
  fi
  readlink -f "$dev" 2>/dev/null || echo "$dev"
}

detect_root_block() {
  local root_src parent
  root_src=$(findmnt -n -o SOURCE -T / || true)
  if [ -z "$root_src" ]; then
    echo ""
    return
  fi
  if [[ "$root_src" != /dev/* ]]; then
    root_src=$(readlink -f "$root_src" 2>/dev/null || echo "$root_src")
  fi
  if [ ! -b "$root_src" ]; then
    echo ""
    return
  fi
  parent=$(lsblk -no PKNAME "$root_src" 2>/dev/null || true)
  if [ -n "$parent" ]; then
    echo "/dev/$parent"
  else
    echo "$root_src"
  fi
}

is_boot_device_target() {
  local target="$1"
  local canon_target parent
  if [ -z "$ROOT_BLOCK_CANON" ]; then
    return 1
  fi
  canon_target=$(canonical_block_path "$target")
  if [ -z "$canon_target" ]; then
    return 1
  fi
  if [ "$canon_target" = "$ROOT_BLOCK_CANON" ]; then
    return 0
  fi
  parent=$(lsblk -no PKNAME "$canon_target" 2>/dev/null || true)
  if [ -n "$parent" ] && [ "/dev/$parent" = "$ROOT_BLOCK_CANON" ]; then
    return 0
  fi
  return 1
}

ROOT_BLOCK_DEVICE=$(detect_root_block)
ROOT_BLOCK_CANON=$(canonical_block_path "$ROOT_BLOCK_DEVICE")
if [ -n "$ROOT_BLOCK_CANON" ]; then
  echo "Detected root block device: $ROOT_BLOCK_CANON"
else
  echo "Warning: unable to determine root block device automatically."
fi

prompt() {
  local var="$1"; local def="$2"; local q="$3"
  read -rp "$q [$def]: " val
  echo "${val:-$def}"
}

echo "=== ShopServer installer ==="
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo $0"; exit 1
fi

echo "Data directories will be owned by ${DATA_USER}:${DATA_GROUP} (uid=${DATA_UID} gid=${DATA_GID})"

HOSTNAME=$(prompt HOSTNAME "$DEFAULT_HOSTNAME" "Network hostname")
USERNAME=$(prompt USERNAME "$DEFAULT_USER" "Samba username for write access")
PASSWORD=$(prompt PASSWORD "$DEFAULT_PASS" "Samba password")
GUEST_OK=$(prompt GUEST_OK "no" "Allow guest (anonymous) access to 'main'? (yes/no)")
SMB1_SHARE_NAME=$(sanitize_share_name "${HOSTNAME}-smb1")

echo "Installing required packages..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y samba avahi-daemon python3 python3-venv python3-pip inotify-tools dosfstools gdisk jq || true

echo "Creating directories..."
mkdir -p "$MAIN_PATH" "$IMAGES_PATH" "$REMOVABLE_BASE" "$SMB_DIR" "$UI_DIR" "$ETC_SHOPSERVER_DIR"
chown -R "$DATA_USER":"$DATA_GROUP" /srv/shopserver || true
chmod -R 2775 /srv/shopserver

echo "Writing base config to $CONFIG_PATH ..."
mkdir -p "$ETC_SHOPSERVER_DIR"
cat > "$CONFIG_PATH" <<EOF
hostname: $HOSTNAME
samba_user: $USERNAME
samba_pass: $PASSWORD
guest_ok_main: $( [ "$GUEST_OK" = "yes" ] && echo "true" || echo "false" )
main_path: $MAIN_PATH
removable_base: $REMOVABLE_BASE
images_path: $IMAGES_PATH
data_user: $DATA_USER
data_group: $DATA_GROUP
data_uid: $DATA_UID
data_gid: $DATA_GID
smb1_share_name: $SMB1_SHARE_NAME
EOF

echo "Setting system hostname to $HOSTNAME ..."
echo "$HOSTNAME" > /etc/hostname
hostnamectl set-hostname "$HOSTNAME" || true

echo "Installing packaged templates to system paths..."
# copy packaged files to target layout
mkdir -p /usr/local/bin /etc/udev/rules.d /etc/samba/smb.d /opt/shopserver/ui /etc/systemd/system /var/log/shopserver

cp -r "${REPO_DIR}/packaging/usr-local-bin/"* /usr/local/bin/
cp "${REPO_DIR}/packaging/etc-udev/99-shopserver.rules" /etc/udev/rules.d/99-shopserver.rules
cp "${REPO_DIR}/packaging/etc-samba/smb.conf" /etc/samba/smb.conf
cp "${REPO_DIR}/packaging/etc-samba/smb.d-main.conf" /etc/samba/smb.d/main.conf
cp "${REPO_DIR}/packaging/etc-samba/smb.d-main-smb1.conf" /etc/samba/smb.d/main-smb1.conf
cp "${REPO_DIR}/packaging/etc-samba/smb.d-removable.conf" /etc/samba/smb.d/removable.conf
cp "${REPO_DIR}/packaging/etc-samba/smb.d-removable-smb1.conf" /etc/samba/smb.d/removable-smb1.conf
cp -r "${REPO_DIR}/packaging/opt-shopserver-ui/"* /opt/shopserver/ui/
cp "${REPO_DIR}/packaging/etc-systemd/shopserver-watcher.service" /etc/systemd/system/shopserver-watcher.service
cp "${REPO_DIR}/packaging/etc-systemd/shopserver-ui.service" /etc/systemd/system/shopserver-ui.service
cp "${REPO_DIR}/packaging/etc-shopserver-config.yaml" "${ETC_SHOPSERVER_DIR}/config.yaml.example" || true

chmod +x /usr/local/bin/shopserver-*.sh || true
chmod +x /usr/local/bin/shopserver-generate-smb.py || true
chmod +x /usr/local/bin/shopserver-inotify-watcher.py || true

# create main path if not present
mkdir -p "$MAIN_PATH"
chown -R "$DATA_USER":"$DATA_GROUP" "$MAIN_PATH"
chmod -R 2775 "$MAIN_PATH"

# Optionally format NVMe
if [ -n "$FORMAT_DEVICE" ]; then
  if is_boot_device_target "$FORMAT_DEVICE"; then
    echo "Detected that $FORMAT_DEVICE contains the running OS. Skipping format and using $MAIN_PATH instead."
    FORMAT_DEVICE=""
  fi
fi

if [ -n "$FORMAT_DEVICE" ]; then
  echo "NVMe format requested: $FORMAT_DEVICE"
  if [ ! -b "$FORMAT_DEVICE" ]; then
    echo "Device $FORMAT_DEVICE not found or not a block device. Aborting."
    exit 1
  fi
  echo "!!! WARNING: This will irreversibly wipe $FORMAT_DEVICE and all data on it !!!"
  read -rp "Type YES to confirm: " CONF
  if [ "$CONF" != "YES" ]; then
    echo "Confirmation not given; aborting format."
    exit 1
  fi
  echo "Wiping signatures and partition table..."
  wipefs -a "$FORMAT_DEVICE" || true
  sgdisk --zap-all "$FORMAT_DEVICE" || true
  parted -s "$FORMAT_DEVICE" mklabel gpt || true
  parted -s "$FORMAT_DEVICE" mkpart primary ext4 0% 100% || true
  # detect partition
  if [ -e "${FORMAT_DEVICE}p1" ]; then
    PART="${FORMAT_DEVICE}p1"
  else
    PART="${FORMAT_DEVICE}1"
  fi
  echo "Formatting partition $PART as ext4..."
  mkfs.ext4 -F -L shopserver_main "$PART"
  mkdir -p "$MAIN_PATH"
  # add to fstab by UUID
  UUID=$(blkid -s UUID -o value "$PART")
  if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $MAIN_PATH ext4 defaults,noatime 0 2" >> /etc/fstab
  fi
  mount -a
  echo "NVMe formatted and mounted at $MAIN_PATH"
fi

echo "Configuring Samba global and main share..."
# set smb main.conf guest flag according to config
GUESTFLAG=$( [ "$GUEST_OK" = "yes" ] && echo "yes" || echo "no" )
cat > /etc/samba/smb.d/main.conf <<EOF
[main]
   path = $MAIN_PATH
   read only = no
   browsable = yes
   guest ok = $GUESTFLAG
   force user = $DATA_USER
   create mask = 0775
   directory mask = 2775
EOF

cat > /etc/samba/smb.d/main-smb1.conf <<EOF
[$SMB1_SHARE_NAME]
   path = $MAIN_PATH
   read only = no
   browsable = yes
   guest ok = $GUESTFLAG
   force user = $DATA_USER
   create mask = 0775
   directory mask = 2775
   server min protocol = NT1
   server max protocol = NT1
   lanman auth = yes
   ntlm auth = yes
EOF

echo "Creating samba user: $USERNAME"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$USERNAME" || true
fi
(echo "$PASSWORD"; echo "$PASSWORD") | smbpasswd -s -a "$USERNAME" || true

# logs
touch /var/log/shopserver-access.log /var/log/shopserver-mounts.log
chown -R root:root /var/log/shopserver

echo "Setting up Python venv for UI and installing dependencies..."
python3 -m venv /opt/shopserver/venv
/opt/shopserver/venv/bin/pip install --upgrade pip
/opt/shopserver/venv/bin/pip install flask pyyaml

echo "Enabling services..."
systemctl daemon-reload
systemctl enable --now shopserver-watcher.service || true
systemctl enable --now shopserver-ui.service || true
systemctl enable --now avahi-daemon || true

udevadm control --reload
udevadm trigger --type=subsystems --action=change || true

systemctl restart smbd nmbd || systemctl restart smbd || true

echo "Installation complete. Reboot recommended."
echo "Web UI: http://$HOSTNAME:5000/ or http://$(hostname -I | awk '{print $1}'):5000/"
