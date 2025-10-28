#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS Custom Kernel Builder
# Builds hardened kernel with security patches

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

KERNEL_VERSION="6.11"
WORK_DIR="/tmp/kernel-build"

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Installing kernel build dependencies..."
apt-get update
apt-get install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    kmod \
    cpio \
    git \
    wget \
    xz-utils

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

log "Downloading kernel source..."
wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
tar -xf "linux-${KERNEL_VERSION}.tar.xz"
cd "linux-${KERNEL_VERSION}"

log "Applying security hardening..."

# Create hardened kernel config
cat > secureos.config << 'EOF'
# SecureOS Kernel Hardening

# Kernel lockdown
CONFIG_SECURITY_LOCKDOWN_LSM=y
CONFIG_SECURITY_LOCKDOWN_LSM_EARLY=y
CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY=y

# Remove legacy/insecure features
CONFIG_DEVMEM=n
CONFIG_DEVKMEM=n
CONFIG_COMPAT_VDSO=n
CONFIG_X86_VSYSCALL_EMULATION=n

# Harden kernel memory
CONFIG_STRICT_KERNEL_RWX=y
CONFIG_STRICT_MODULE_RWX=y
CONFIG_PAGE_TABLE_ISOLATION=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_RANDOMIZE_MEMORY=y

# Stack protection
CONFIG_STACKPROTECTOR=y
CONFIG_STACKPROTECTOR_STRONG=y
CONFIG_SLAB_FREELIST_RANDOM=y
CONFIG_SLAB_FREELIST_HARDENED=y

# Restrict kernel modules
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_SHA512=y

# Restrict kernel pointers
CONFIG_SECURITY_DMESG_RESTRICT=y
CONFIG_KALLSYMS_ALL=n

# Harden BPF
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y
CONFIG_BPF_JIT_ALWAYS_ON=y

# Yama security
CONFIG_SECURITY_YAMA=y

# AppArmor
CONFIG_SECURITY_APPARMOR=y
CONFIG_DEFAULT_SECURITY_APPARMOR=y

# Restrict userns
CONFIG_USER_NS=y

# Audit
CONFIG_AUDIT=y
CONFIG_AUDITSYSCALL=y

# Integrity measurement
CONFIG_INTEGRITY=y
CONFIG_INTEGRITY_SIGNATURE=y
CONFIG_IMA=y
CONFIG_IMA_APPRAISE=y

# Kernel hardening
CONFIG_HARDENED_USERCOPY=y
CONFIG_FORTIFY_SOURCE=y
CONFIG_GCC_PLUGIN_STRUCTLEAK_BYREF_ALL=y
CONFIG_GCC_PLUGIN_RANDSTRUCT=y
CONFIG_GCC_PLUGIN_LATENT_ENTROPY=y

# Remove debugging symbols
CONFIG_DEBUG_KERNEL=n
CONFIG_DEBUG_INFO=n
CONFIG_KPROBES=n
EOF

log "Configuring kernel..."
make defconfig
scripts/kconfig/merge_config.sh .config secureos.config

log "Building kernel (this will take a while)..."
make -j$(nproc) deb-pkg LOCALVERSION=-secureos

log "Kernel packages built in $WORK_DIR"
ls -lh ../*.deb

success "SecureOS hardened kernel built successfully!"
echo ""
log "To install:"
echo "  sudo dpkg -i ../linux-*.deb"
echo "  sudo update-grub"
echo "  sudo reboot"
