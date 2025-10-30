#!/bin/bash
#
# SecureOS Local ISO Builder
# Simplified version for local builds
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SecureOS ISO Builder (Local)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Configuration
WORK_DIR="/tmp/secureos-iso-build"
ISO_NAME="SecureOS-v5.0.0-amd64.iso"
ISO_OUTPUT="$PWD/iso-output"

echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check available space
AVAILABLE=$(df /tmp | tail -1 | awk '{print $4}')
REQUIRED=$((10 * 1024 * 1024)) # 10GB in KB

if [ "$AVAILABLE" -lt "$REQUIRED" ]; then
    echo -e "${RED}Insufficient space in /tmp${NC}"
    echo "Required: 10GB, Available: $(( AVAILABLE / 1024 / 1024 ))GB"
    exit 1
fi

echo -e "${YELLOW}Installing build dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools 2>/dev/null || true

echo -e "${YELLOW}Creating build directory...${NC}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{chroot,iso/{casper,isolinux,install}}
mkdir -p "$ISO_OUTPUT"

echo -e "${YELLOW}Creating minimal filesystem (this will take a while)...${NC}"
echo "This step downloads Ubuntu packages and may take 15-30 minutes..."

# Use a minimal bootstrap
debootstrap \
    --variant=minbase \
    --arch=amd64 \
    --include=linux-image-generic,linux-headers-generic,systemd,udev,network-manager \
    noble \
    "$WORK_DIR/chroot" \
    http://archive.ubuntu.com/ubuntu/ 2>&1 | grep -E "Retrieving|Extracting|Unpacking" || true

echo -e "${YELLOW}Customizing system...${NC}"

# Mount necessary filesystems
mount -t proc none "$WORK_DIR/chroot/proc"
mount -t sysfs none "$WORK_DIR/chroot/sys"
mount -o bind /dev "$WORK_DIR/chroot/dev"
mount -t devpts none "$WORK_DIR/chroot/dev/pts"

# Customize the chroot
cat > "$WORK_DIR/chroot/customize.sh" << 'CHROOT_SCRIPT'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export LC_ALL=C

echo "secureos" > /etc/hostname

# Basic packages
apt-get update
apt-get install -y \
    ufw \
    fail2ban \
    apparmor \
    openssh-server \
    vim \
    wget \
    curl \
    git \
    python3 \
    python3-pip

# Enable services
systemctl enable ufw
systemctl enable fail2ban

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_SCRIPT

chmod +x "$WORK_DIR/chroot/customize.sh"
chroot "$WORK_DIR/chroot" /customize.sh
rm "$WORK_DIR/chroot/customize.sh"

# Copy SecureOS files
echo -e "${YELLOW}Copying SecureOS files...${NC}"
mkdir -p "$WORK_DIR/chroot/opt/secureos"
cp -r "$PWD"/{v5.0.0,v6.0.0,scripts,README.md,LICENSE} "$WORK_DIR/chroot/opt/secureos/" 2>/dev/null || true

# Unmount filesystems
echo -e "${YELLOW}Cleaning up...${NC}"
umount "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
umount "$WORK_DIR/chroot/dev" 2>/dev/null || true
umount "$WORK_DIR/chroot/sys" 2>/dev/null || true
umount "$WORK_DIR/chroot/proc" 2>/dev/null || true

echo -e "${YELLOW}Creating squashfs filesystem...${NC}"
mksquashfs \
    "$WORK_DIR/chroot" \
    "$WORK_DIR/iso/casper/filesystem.squashfs" \
    -comp xz \
    -b 1M \
    -Xbcj x86 \
    -e boot 2>&1 | grep -E "Creating|Writing" || true

# Copy kernel and initrd
echo -e "${YELLOW}Copying kernel files...${NC}"
cp "$WORK_DIR/chroot/boot"/vmlinuz-* "$WORK_DIR/iso/casper/vmlinuz"
cp "$WORK_DIR/chroot/boot"/initrd.img-* "$WORK_DIR/iso/casper/initrd"

# Create filesystem manifest
echo -e "${YELLOW}Creating manifest...${NC}"
chroot "$WORK_DIR/chroot" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORK_DIR/iso/casper/filesystem.manifest"
printf "%s" "$(du -sx --block-size=1 "$WORK_DIR/chroot" | cut -f1)" > "$WORK_DIR/iso/casper/filesystem.size"

# Create isolinux config
cat > "$WORK_DIR/iso/isolinux/isolinux.cfg" << 'ISOLINUX'
DEFAULT live
LABEL live
  menu label ^Start SecureOS
  kernel /casper/vmlinuz
  append initrd=/casper/initrd boot=casper quiet splash ---
ISOLINUX

# Copy isolinux files
cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/iso/isolinux/"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "$WORK_DIR/iso/isolinux/"

# Create README
cat > "$WORK_DIR/iso/README.txt" << 'README'
SecureOS v5.0.0 "Quantum Shield"
================================

This is a live ISO of SecureOS.

Boot from this ISO to try SecureOS or install it to your system.

Visit: https://secureos.xyz
GitHub: https://github.com/barrersoftware/SecureOS
README

echo -e "${YELLOW}Creating ISO image...${NC}"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "SecureOS 5.0.0" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -output "$ISO_OUTPUT/$ISO_NAME" \
    "$WORK_DIR/iso" 2>&1 | grep -E "Writing|done" || true

# Calculate checksums
echo -e "${YELLOW}Calculating checksums...${NC}"
cd "$ISO_OUTPUT"
sha256sum "$ISO_NAME" > SHA256SUMS
md5sum "$ISO_NAME" > MD5SUMS

# Get ISO size
ISO_SIZE=$(du -h "$ISO_NAME" | cut -f1)

# Cleanup
echo -e "${YELLOW}Cleaning up build directory...${NC}"
rm -rf "$WORK_DIR"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}ISO Build Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "ISO File: ${BLUE}$ISO_OUTPUT/$ISO_NAME${NC}"
echo -e "Size: ${BLUE}$ISO_SIZE${NC}"
echo ""
echo "Checksums:"
echo "  SHA256: $(cat SHA256SUMS)"
echo "  MD5:    $(cat MD5SUMS)"
echo ""
echo "To test the ISO:"
echo "  qemu-system-x86_64 -cdrom $ISO_OUTPUT/$ISO_NAME -m 2048"
echo ""
echo "To write to USB (replace /dev/sdX with your device):"
echo "  sudo dd if=$ISO_OUTPUT/$ISO_NAME of=/dev/sdX bs=4M status=progress"
echo ""