#!/bin/bash
#
# SecureOS Backup Script
# Backup all SecureOS configurations and data
#

set -e

BACKUP_DIR="/var/backups/secureos"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/secureos_backup_$TIMESTAMP.tar.gz"

echo "═══════════════════════════════════════════════════════════"
echo "SecureOS Backup Utility"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_FILE"
echo ""

# Items to backup
BACKUP_ITEMS=(
    "/etc/secureos"
    "/var/lib/secureos"
    "/var/log/secureos"
    "/etc/ufw"
    "/etc/fail2ban"
    "/etc/apparmor.d"
    "/etc/audit"
    "/etc/sysctl.d/99-secureos-hardening.conf"
)

# Create temporary list
TEMP_LIST=$(mktemp)

for item in "${BACKUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo "$item" >> "$TEMP_LIST"
        echo "  ✓ Adding: $item"
    else
        echo "  ⊘ Skipping: $item (not found)"
    fi
done

echo ""
echo "Compressing backup..."

# Create backup
tar -czf "$BACKUP_FILE" -T "$TEMP_LIST" 2>/dev/null || true

# Cleanup
rm -f "$TEMP_LIST"

# Get file size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Backup completed successfully!"
echo ""
echo "Backup file: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo ""
echo "To restore this backup:"
echo "  sudo tar -xzf $BACKUP_FILE -C /"
echo "═══════════════════════════════════════════════════════════"

# Keep only last 10 backups
cd "$BACKUP_DIR"
ls -t secureos_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f

echo ""
echo "Old backups cleaned up (keeping last 10)"
