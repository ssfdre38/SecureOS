#!/bin/bash
#
# SecureOS ISO Builder Script
# Part of SecureOS - Security Enhanced Linux Distribution
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# This script builds a custom Ubuntu-based ISO with security hardening
#
set -e

WORK_DIR="/tmp/secureos-build"
ISO_NAME="SecureOS-1.0.0-amd64.iso"
# BASE_DISTRO variable for documentation - using Ubuntu 24.04.3 LTS (Noble Numbat)
# To change base: modify debootstrap command to use different release

# Cleanup function to unmount on exit or error
cleanup() {
    echo "[*] Cleaning up mounts..."
    umount -l "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
    umount -l "$WORK_DIR/chroot/sys" 2>/dev/null || true
    umount -l "$WORK_DIR/chroot/proc" 2>/dev/null || true
    umount -l "$WORK_DIR/chroot/run" 2>/dev/null || true
    umount -l "$WORK_DIR/chroot/dev" 2>/dev/null || true
}

# Set trap to cleanup on exit or error
trap cleanup EXIT ERR

echo "=========================================="
echo "   SecureOS ISO Builder"
echo "=========================================="

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

# Bootstrap base system
echo "[*] Bootstrapping base system..."
debootstrap --arch=amd64 noble "$WORK_DIR/chroot" https://mirror.secureos.xyz/

# Mount necessary filesystems
echo "[*] Mounting filesystems..."
mount --bind /dev "$WORK_DIR/chroot/dev"
mount --bind /run "$WORK_DIR/chroot/run"
mount -t proc none "$WORK_DIR/chroot/proc"
mount -t sysfs none "$WORK_DIR/chroot/sys"
mount -t devpts none "$WORK_DIR/chroot/dev/pts"

# Copy DNS configuration for chroot
echo "[*] Configuring DNS..."
cp /etc/resolv.conf "$WORK_DIR/chroot/etc/resolv.conf"

# Configure APT
echo "[*] Configuring package repositories..."
cat > "$WORK_DIR/chroot/etc/apt/sources.list" << EOF
deb https://mirror.secureos.xyz/ noble main restricted universe multiverse
deb https://mirror.secureos.xyz/ noble-updates main restricted universe multiverse
deb https://mirror.secureos.xyz/ noble-security main restricted universe multiverse
deb https://mirror.secureos.xyz/ noble-backports main restricted universe multiverse
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
    bleachbit \
    cryptsetup \
    ecryptfs-utils

# Install privacy tools
apt-get install -y \
    tor \
    privoxy \
    macchanger \
    mat2

# Install minimal desktop (optional - can be removed for server)
apt-get install -y \
    xorg \
    openbox \
    lightdm \
    firefox \
    gnome-terminal

# Install Python for installer
apt-get install -y \
    python3 \
    python3-pip \
    python3-curses

# Clean up
apt-get autoremove -y
apt-get clean

# Configure locales
locale-gen en_US.UTF-8

rm -f /install_packages.sh
CHROOT_EOF

chmod +x "$WORK_DIR/chroot/install_packages.sh"
chroot "$WORK_DIR/chroot" /install_packages.sh

# Copy installer
echo "[*] Installing SecureOS installer..."
cp -r ../installer "$WORK_DIR/chroot/opt/secureos-installer"
chmod +x "$WORK_DIR/chroot/opt/secureos-installer/secure_installer.py"

# Apply security hardening
echo "[*] Applying security hardening..."
cat > "$WORK_DIR/chroot/apply_hardening.sh" << 'HARDENING_EOF'
#!/bin/bash

# Kernel hardening (sysctl)
cat >> /etc/sysctl.d/99-secureos.conf << EOF
# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.tcp_syncookies = 1

# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
EOF

# AppArmor enforcement
systemctl enable apparmor

# Enable firewall
ufw default deny incoming
ufw default allow outgoing
ufw logging on
systemctl enable ufw

# Enable audit logging
systemctl enable auditd

# Secure SSH (if installed)
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo "Protocol 2" >> /etc/ssh/sshd_config
fi

# Disable unnecessary services
systemctl disable bluetooth 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

rm -f /apply_hardening.sh
HARDENING_EOF

chmod +x "$WORK_DIR/chroot/apply_hardening.sh"
chroot "$WORK_DIR/chroot" /apply_hardening.sh

# Create live boot configuration
echo "[*] Configuring live boot..."
cat > "$WORK_DIR/chroot/etc/casper.conf" << EOF
export USERNAME="live"
export USERFULLNAME="Live session user"
export HOST="secureos"
EOF

# Unmount filesystems
echo "[*] Unmounting filesystems..."
umount "$WORK_DIR/chroot/dev/pts"
umount "$WORK_DIR/chroot/sys"
umount "$WORK_DIR/chroot/proc"
umount "$WORK_DIR/chroot/run"
umount "$WORK_DIR/chroot/dev"

# Create manifest
echo "[*] Creating manifest..."
chroot "$WORK_DIR/chroot" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORK_DIR/image/casper/filesystem.manifest"
cp "$WORK_DIR/image/casper/filesystem.manifest" "$WORK_DIR/image/casper/filesystem.manifest-desktop"

# Create squashfs
echo "[*] Creating squashfs filesystem..."
mksquashfs "$WORK_DIR/chroot" "$WORK_DIR/image/casper/filesystem.squashfs" -comp xz -b 1M

# Copy kernel and initrd
echo "[*] Copying kernel and initrd..."
cp "$WORK_DIR/chroot/boot"/vmlinuz-* "$WORK_DIR/image/casper/vmlinuz"
cp "$WORK_DIR/chroot/boot"/initrd.img-* "$WORK_DIR/image/casper/initrd"

# Create GRUB configuration
echo "[*] Creating bootloader configuration..."
cat > "$WORK_DIR/image/isolinux/grub.cfg" << EOF
set timeout=10
set default=0

menuentry "Install SecureOS" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "Try SecureOS (Live)" {
    linux /casper/vmlinuz boot=casper quiet splash live-media-timeout=10 ---
    initrd /casper/initrd
}
EOF

# Create ISO
echo "[*] Creating ISO image..."
grub-mkrescue -o "/home/ubuntu/SecureOS/iso-build/$ISO_NAME" "$WORK_DIR/image" \
    --output-dir="$WORK_DIR/iso-output"

# Calculate checksums
echo "[*] Generating checksums..."
cd /home/ubuntu/SecureOS/iso-build
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
md5sum "$ISO_NAME" > "$ISO_NAME.md5"

# Cleanup
echo "[*] Cleaning up..."
# Unmount filesystems before removing
umount -l "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
umount -l "$WORK_DIR/chroot/sys" 2>/dev/null || true
umount -l "$WORK_DIR/chroot/proc" 2>/dev/null || true
umount -l "$WORK_DIR/chroot/run" 2>/dev/null || true
umount -l "$WORK_DIR/chroot/dev" 2>/dev/null || true
rm -rf "$WORK_DIR"

echo "=========================================="
echo "   Build completed successfully!"
echo "=========================================="
echo "ISO location: /home/ubuntu/SecureOS/iso-build/$ISO_NAME"
echo ""
echo "To test the ISO:"
echo "  qemu-system-x86_64 -m 2048 -cdrom /home/ubuntu/SecureOS/iso-build/$ISO_NAME"
