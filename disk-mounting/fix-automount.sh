#!/bin/bash
# Add a udev rule so the systemd automount unit restarts automatically
# whenever the disk reconnects. Without this, the unit dies on disconnect
# and requires a manual 'systemctl restart' to recover.
#
# Usage: bash fix-automount.sh [mount-point]
# Default mount point: /media/xander

set -e

MOUNT_POINT="${1:-/media/xander}"

echo "=== Fix Automount Resilience ==="
echo "Mount point: $MOUNT_POINT"
echo

# Derive systemd unit name from mount point: /media/xander -> media-xander.automount
UNIT_NAME="$(systemd-escape --path "$MOUNT_POINT").automount"

# Verify the automount unit exists
if ! systemctl list-units --type=automount --all 2>/dev/null | grep -q "$UNIT_NAME"; then
    echo "Error: automount unit '$UNIT_NAME' not found."
    echo "Complete the disk mount setup first (see disk-mounting/setup-admin.md)."
    exit 1
fi

# Extract UUID from fstab
UUID=$(awk -v mp="$MOUNT_POINT" '$2 == mp && $1 ~ /^UUID=/ { sub(/^UUID=/, "", $1); print $1 }' /etc/fstab)
if [ -z "$UUID" ]; then
    echo "Error: no fstab entry found for $MOUNT_POINT"
    exit 1
fi

RULES_FILE="/etc/udev/rules.d/99-automount-$(systemd-escape --path "$MOUNT_POINT").rules"

echo "UUID:         $UUID"
echo "Unit:         $UNIT_NAME"
echo "Rules file:   $RULES_FILE"
echo

# Check if rule already exists
if [ -f "$RULES_FILE" ]; then
    echo "Rules file already exists:"
    cat "$RULES_FILE"
    echo
    read -p "Overwrite? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

sudo tee "$RULES_FILE" > /dev/null <<EOF
# Restart the automount unit when this disk is reconnected.
# Without this, the unit dies on disconnect and requires a manual
# 'systemctl restart $UNIT_NAME' to recover.
ACTION=="add", ENV{ID_FS_UUID}=="$UUID", RUN+="/usr/bin/systemctl restart $UNIT_NAME"
EOF

echo "✓ Created $RULES_FILE"

sudo udevadm control --reload-rules
echo "✓ Reloaded udev rules"

sudo systemctl restart "$UNIT_NAME"
echo "✓ Restarted $UNIT_NAME"

echo
echo "=== Done ==="
echo "The automount unit will now restart automatically whenever the disk is reconnected."
echo
echo "To verify: systemctl status $UNIT_NAME"
echo "To remove: sudo rm $RULES_FILE && sudo udevadm control --reload-rules"
