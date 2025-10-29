#!/bin/bash
#
# SecureOS ISO Builder Script - Using Local Mirror
# Part of SecureOS - Security Enhanced Linux Distribution
#
# This version uses local mirrors for faster builds:
#   - mirror.secureos.xyz for Ubuntu packages
#   - repo.secureos.xyz for SecureOS packages
#
set -e

WORK_DIR="/tmp/secureos-build"
ISO_NAME="SecureOS-6.0.0-amd64.iso"
UBUNTU_MIRROR="https://mirror.secureos.xyz"
SECUREOS_REPO="https://repo.secureos.xyz"

echo "=========================================="
echo "   SecureOS ISO Builder (Local Mirror)"
echo "=========================================="
echo ""
echo "Using mirrors:"
echo "  Ubuntu: $UBUNTU_MIRROR"
echo "  SecureOS: $SECUREOS_REPO"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Install required packages
echo "[*] Installing build dependencies..."
apt-get update
apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    git

# Create work directory
echo "[*] Creating work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{chroot,image/{casper,isolinux,install}}

# Bootstrap base system using local mirror
echo "[*] Bootstrapping base system from local mirror..."
debootstrap --arch=amd64 noble "$WORK_DIR/chroot" $UBUNTU_MIRROR

# Mount necessary filesystems
echo "[*] Mounting filesystems..."
mount --bind /dev "$WORK_DIR/chroot/dev"
mount --bind /run "$WORK_DIR/chroot/run"
mount -t proc none "$WORK_DIR/chroot/proc"
mount -t sysfs none "$WORK_DIR/chroot/sys"
mount -t devpts none "$WORK_DIR/chroot/dev/pts"

# Configure APT to use local mirrors
echo "[*] Configuring package repositories..."
cat > "$WORK_DIR/chroot/etc/apt/sources.list" << EOF
# Local Ubuntu Mirror
deb $UBUNTU_MIRROR noble main restricted universe multiverse
deb $UBUNTU_MIRROR noble-updates main restricted universe multiverse
deb $UBUNTU_MIRROR noble-security main restricted universe multiverse
deb $UBUNTU_MIRROR noble-backports main restricted universe multiverse

# SecureOS Repository
deb $SECUREOS_REPO noble main security
EOF

# Chroot and install packages
echo "[*] Installing system packages..."
cat > "$WORK_DIR/chroot/install_packages.sh" << 'CHROOT_EOF'
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export LC_ALL=C

# Update package lists
apt-get update

# Install kernel and base system
apt-get install -y \
    linux-generic \
    casper \
    lupin-casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    resolvconf \
    net-tools \
    wireless-tools \
    wpagui \
    locales \
    grub-common \
    grub-gfxpayload-lists \
    grub-pc \
    grub-pc-bin \
    grub2-common

# Install SecureOS packages if available
apt-get install -y secureos-meta secureos-tools || echo "SecureOS packages not available yet"

# Install security tools
apt-get install -y \
    ufw \
    apparmor \
    apparmor-utils \
    auditd \
    aide \
    rkhunter \
    chkrootkit \
    fail2ban \
    clamav \
    clamav-daemon \
    firejail \
    cryptsetup \
    ecryptfs-utils \
    tor \
    privoxy \
    macchanger \
    unattended-upgrades

# Configure locales
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
CHROOT_EOF

chmod +x "$WORK_DIR/chroot/install_packages.sh"
chroot "$WORK_DIR/chroot" /install_packages.sh
rm "$WORK_DIR/chroot/install_packages.sh"

# Configure SecureOS branding
echo "[*] Configuring SecureOS branding..."
cat > "$WORK_DIR/chroot/etc/lsb-release" << EOF
DISTRIB_ID=SecureOS
DISTRIB_RELEASE=6.0.0
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="SecureOS 6.0.0 LTS - Security Enhanced Linux"
EOF

# Create manifest
echo "[*] Creating manifest..."
chroot "$WORK_DIR/chroot" dpkg-query -W --showformat='${Package} ${Version}\n' | tee "$WORK_DIR/image/casper/filesystem.manifest" > /dev/null

# Create squashfs
echo "[*] Creating compressed filesystem..."
mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/image/casper/filesystem.squashfs" -comp xz -e boot

# Unmount filesystems
echo "[*] Unmounting filesystems..."
umount "$WORK_DIR/chroot/dev/pts"
umount "$WORK_DIR/chroot/sys"
umount "$WORK_DIR/chroot/proc"
umount "$WORK_DIR/chroot/run"
umount "$WORK_DIR/chroot/dev"

# Copy kernel and initrd
echo "[*] Copying kernel and initrd..."
cp "$WORK_DIR/chroot/boot/vmlinuz-"* "$WORK_DIR/image/casper/vmlinuz"
cp "$WORK_DIR/chroot/boot/initrd.img-"* "$WORK_DIR/image/casper/initrd"

# Create GRUB configuration
echo "[*] Creating bootloader configuration..."
cat > "$WORK_DIR/image/isolinux/grub.cfg" << 'EOF'
set default="0"
set timeout=10

menuentry "SecureOS 6.0.0 - Live System" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "SecureOS 6.0.0 - Install" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
    initrd /casper/initrd
}
EOF

# Create ISO
echo "[*] Creating ISO image..."
cd "$WORK_DIR/image"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "SecureOS 6.0.0" \
    -output "/tmp/$ISO_NAME" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    .

# Generate checksums
echo "[*] Generating checksums..."
cd /tmp
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
md5sum "$ISO_NAME" > "$ISO_NAME.md5"

echo ""
echo "=========================================="
echo "   SecureOS ISO Build Complete!"
echo "=========================================="
echo ""
echo "ISO: /tmp/$ISO_NAME"
echo "Size: $(du -h /tmp/$ISO_NAME | cut -f1)"
echo ""
echo "SHA256: $(cat /tmp/$ISO_NAME.sha256)"
echo ""
echo "Verify: sha256sum -c $ISO_NAME.sha256"
echo ""
echo "Built using:"
echo "  Ubuntu Mirror: $UBUNTU_MIRROR"
echo "  SecureOS Repo: $SECUREOS_REPO"
