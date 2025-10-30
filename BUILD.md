# SecureOS Build Guide

## Overview
Building the SecureOS ISO creates a bootable installation media with all security and privacy features pre-configured, including advanced v5.0.0 features like quantum-resistant cryptography, blockchain audit logging, AI-powered threat detection, self-healing security, and advanced malware sandboxing.

## System Requirements for Building

### Minimum:
- Ubuntu/Debian-based Linux system (Ubuntu 20.04+ or Debian 11+)
- 15GB free disk space (for /tmp directory)
- 4GB RAM
- Fast internet connection (will download ~2GB)
- Root/sudo access

### Recommended:
- 25GB free disk space
- 8GB RAM
- SSD storage
- Dedicated build machine or VM
- Multi-core CPU (for faster compilation)

## Build Time Estimates

| Connection Speed | Build Time |
|-----------------|------------|
| Fast (100+ Mbps) | 30-45 minutes |
| Medium (50 Mbps) | 45-60 minutes |
| Slow (<25 Mbps) | 60-90 minutes |

## Step-by-Step Build Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/barrersoftware/SecureOS.git
cd SecureOS
```

### 2. Choose Your Build Script

SecureOS provides multiple build options:

- **`build-iso.sh`** (Recommended): Comprehensive build with v5.0.0 features
- **`scripts/build_iso.sh`**: Standard build with all security features
- **`scripts/build_iso_fast.sh`**: Faster build with fewer packages (for testing)

### 3. Review the Build Script (Optional)
```bash
cat build-iso.sh
```

### 4. Run the Build (requires sudo)

**Comprehensive Build (Recommended):**
```bash
sudo ./build-iso.sh
```

**Standard Build:**
```bash
sudo bash scripts/build_iso.sh
```

**Fast Build (for testing):**
```bash
sudo bash scripts/build_iso_fast.sh
```

### 5. Monitor Progress
The build process will:
1. Check and install dependencies (debootstrap, squashfs-tools, xorriso, etc.)
2. Bootstrap Ubuntu 24.04.3 (Noble) base system
3. Install kernel and system packages
4. Install security tools (UFW, AppArmor, auditd, fail2ban, ClamAV)
5. Install privacy tools (Tor, Privoxy, macchanger, MAT2)
6. **Install v5.0.0 advanced features:**
   - Quantum-resistant cryptography
   - Blockchain-based audit logging
   - AI-powered threat detection
   - Self-healing security system
   - Advanced malware sandboxing
7. Apply security hardening
8. Create compressed squashfs filesystem
9. Generate bootable ISO with GRUB

### 6. Build Output
When complete, you'll find:
```
iso-build/
├── SecureOS-1.0.0-amd64.iso       # Bootable ISO (~1.5-2.0GB)
├── SecureOS-1.0.0-amd64.iso.sha256 # SHA256 checksum
└── SecureOS-1.0.0-amd64.iso.md5    # MD5 checksum
```

Build logs are saved to `build.log` in the project directory.

## What Gets Installed in the ISO

### Base System
- Ubuntu 24.04.3 LTS (Noble Numbat)
- Linux kernel (latest stable)
- Minimal desktop (Openbox + LightDM)
- Network Manager
- Essential utilities

### Security Tools
- **UFW**: Uncomplicated Firewall
- **AppArmor**: Mandatory Access Control
- **auditd**: System audit daemon
- **fail2ban**: Intrusion prevention
- **ClamAV**: Antivirus engine
- **AIDE**: Advanced Intrusion Detection
- **rkhunter**: Rootkit hunter
- **chkrootkit**: Rootkit checker
- **firejail**: Application sandboxing

### Privacy Tools
- **Tor**: Anonymous networking
- **Privoxy**: Privacy-enhancing proxy
- **macchanger**: MAC address randomization
- **MAT2**: Metadata removal
- **BleachBit**: System cleaner

### Encryption
- **cryptsetup**: LUKS disk encryption
- **ecryptfs-utils**: File-level encryption

### 🚀 Advanced v5.0.0 Security Features
- **Quantum-Resistant Cryptography**: Post-quantum encryption algorithms (NIST PQC)
- **Blockchain Audit Logging**: Immutable, tamper-proof security event logging
- **AI Threat Detection**: Machine learning-powered behavioral analysis and anomaly detection
- **Self-Healing Security**: Autonomous security remediation and recovery
- **Advanced Malware Sandbox**: Hardware-isolated malware analysis environment

## Testing the ISO

### Option 1: QEMU (Fast, Recommended for Testing)
```bash
# Install QEMU if not already installed
sudo apt install qemu-system-x86

# Run the ISO
qemu-system-x86_64 -m 2048 -enable-kvm \
  -cdrom iso-build/SecureOS-1.0.0-amd64.iso \
  -boot d
```

### Option 2: VirtualBox
1. Open VirtualBox
2. New > Linux > Ubuntu (64-bit)
3. Allocate 2GB+ RAM, 20GB+ disk
4. Settings > Storage > Add optical drive
5. Select SecureOS ISO
6. Start VM

### Option 3: Physical Media
```bash
# Find your USB device (e.g., /dev/sdb)
lsblk

# Write ISO to USB (DESTRUCTIVE - erases USB!)
sudo dd if=iso-build/SecureOS-1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress
sudo sync

# Safely remove
sudo eject /dev/sdX
```

## Customizing the Build

### Change Base Distribution
Edit `scripts/build_iso.sh`:
```bash
# For Debian 12 instead of Ubuntu 24.04.3
debootstrap --arch=amd64 bookworm "$WORK_DIR/chroot" http://deb.debian.org/debian/
```

### Add/Remove Packages
Edit the package installation section in `scripts/build_iso.sh`:
```bash
# Add your packages here
apt-get install -y \
    your-package-1 \
    your-package-2
```

### Modify Security Settings
Edit `config/security-defaults.conf` before building.

### Change Desktop Environment
Replace Openbox with your preference:
```bash
# For XFCE
apt-get install -y xfce4 xfce4-goodies

# For KDE Plasma
apt-get install -y kde-plasma-desktop

# For GNOME
apt-get install -y ubuntu-desktop
```

## Troubleshooting Build Issues

### Error: "Not enough disk space"
**Solution:**
- Free up at least 15GB (20GB recommended)
- Build uses `/tmp/secureos-build` (needs 8-12GB temp space)
- Check with: `df -h /tmp`

### Error: "Permission denied"
**Solution:**
- Must run with `sudo` or as root
- Check file permissions with: `ls -la build-iso.sh`
- Make executable: `chmod +x build-iso.sh`

### Error: "Failed to download packages"
**Solution:**
- Check internet connection: `ping archive.ubuntu.com`
- Try different mirror in sources.list
- Update package lists: `sudo apt-get update`
- Retry the build

### Error: "This script must be run as root"
**Solution:**
- Run with sudo: `sudo ./build-iso.sh`
- Or switch to root: `sudo su -` then run the script

### Build Hangs or Freezes
**Solution:**
- Check system resources: `htop` or `free -h`
- Kill and restart: `sudo killall debootstrap`
- Clear temp: `sudo rm -rf /tmp/secureos-build`
- Check logs: `tail -f build.log`

### Error: "Invalid GPG signature"
**Solution:**
- Update GPG keys:
  ```bash
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys [KEY_ID]
  ```

### Error: "grub-mkrescue: command not found"
**Solution:**
- Install GRUB tools:
  ```bash
  sudo apt-get install grub-pc-bin grub-efi-amd64-bin
  ```

### Error: "mksquashfs: command not found"
**Solution:**
- Install squashfs-tools:
  ```bash
  sudo apt-get install squashfs-tools
  ```

### Python Dependencies Missing (v5.0.0 features)
**Solution:**
- Install Python packages:
  ```bash
  sudo apt-get install python3-pip python3-dev
  sudo pip3 install numpy scikit-learn cryptography pynacl
  ```

### Build fails during chroot
**Solution:**
- Check if filesystems are mounted: `mount | grep secureos-build`
- Unmount manually:
  ```bash
  sudo umount /tmp/secureos-build/chroot/{dev/pts,sys,proc,run,dev}
  ```
- Clean and retry

## Dependency Management

### Required Build Dependencies

The build scripts automatically check and install required dependencies. These include:

- **debootstrap**: Bootstrap base system
- **squashfs-tools**: Create compressed filesystem
- **xorriso**: Create ISO images
- **isolinux**: Boot loader for ISO
- **syslinux-efi**: EFI boot support
- **grub-pc-bin**: GRUB bootloader (BIOS)
- **grub-efi-amd64-bin**: GRUB bootloader (UEFI)
- **mtools**: DOS filesystem tools
- **dosfstools**: FAT filesystem tools
- **git**: Version control

### Manual Dependency Installation

If you prefer to install dependencies manually before building:

```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-efi \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    git \
    python3 \
    python3-pip
```

### Python Dependencies for v5.0.0 Features

```bash
sudo pip3 install numpy scikit-learn cryptography pynacl
```

## Build Cleanup

After successful build:
```bash
# Temporary build files are auto-cleaned by the script
# But you can manually clean with:
sudo rm -rf /tmp/secureos-build

# Clean all build artifacts:
sudo rm -rf iso-build/ build-output/ build.log
```

## Advanced: Automated Build

For CI/CD or automated builds:
```bash
#!/bin/bash
cd /path/to/SecureOS
sudo bash scripts/build_iso.sh 2>&1 | tee build-$(date +%Y%m%d-%H%M%S).log

if [ -f iso-build/SecureOS-1.0.0-amd64.iso ]; then
    echo "Build successful!"
    sha256sum iso-build/SecureOS-1.0.0-amd64.iso
else
    echo "Build failed!"
    exit 1
fi
```

## Security Notes

### Build Environment Security
- Use a clean, dedicated build system
- Verify checksums of downloaded packages
- Review all scripts before running with sudo
- Don't build on production systems

### ISO Security
- Generated ISO contains hardened defaults
- No passwords are pre-set
- First boot requires configuration
- All network services disabled by default

## Build Verification

After building, verify the ISO integrity:

### Automated Verification (Recommended)

Run the verification script to perform comprehensive checks:
```bash
./verify-iso.sh
```

This script checks:
- ISO file existence and size
- SHA256 and MD5 checksums
- ISO format and bootability
- Essential ISO contents (kernel, initrd, filesystem)
- Build log for errors

### Manual Verification

Check the SHA256 checksum manually:
```bash
cd iso-build
sha256sum -c SecureOS-1.0.0-amd64.iso.sha256
```

Expected output:
```
SecureOS-1.0.0-amd64.iso: OK
```

## Next Steps After Building

1. **Verify the ISO** (see Build Verification section above)

2. **Test in VM** before deploying to production:
   ```bash
   qemu-system-x86_64 -m 2048 -enable-kvm -cdrom iso-build/SecureOS-1.0.0-amd64.iso
   ```

3. **Create installation media** (USB/DVD)

4. **Read installation guide** in README.md

5. **Configure post-installation** with hardening script

## Support

For build issues:
- Check `build.log` if created
- Review `/tmp/secureos-build/` logs
- Open issue on GitHub

## References

- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/)
- [Ubuntu Custom ISO](https://help.ubuntu.com/community/LiveCDCustomization)
- [Debootstrap Guide](https://wiki.debian.org/Debootstrap)
