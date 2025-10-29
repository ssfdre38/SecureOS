# SecureOS Build Guide

## Overview
Building the SecureOS ISO creates a bootable installation media with all security and privacy features pre-configured.

## System Requirements for Building

### Minimum:
- Ubuntu/Debian-based Linux system
- 10GB free disk space
- 4GB RAM
- Fast internet connection (will download ~2GB)
- Root/sudo access

### Recommended:
- 20GB free disk space
- 8GB RAM
- SSD storage
- Dedicated build machine or VM

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

### 2. Review the Build Script
```bash
cat scripts/build_iso.sh
```

### 3. Run the Build (requires sudo)
```bash
sudo bash scripts/build_iso.sh
```

### 4. Monitor Progress
The build process will:
1. Install dependencies (debootstrap, squashfs-tools, etc.)
2. Bootstrap Ubuntu 24.04.3 base system
3. Install kernel and system packages
4. Install security tools (UFW, AppArmor, auditd, fail2ban, ClamAV)
5. Install privacy tools (Tor, Privoxy, macchanger, MAT2)
6. Apply security hardening
7. Create squashfs filesystem
8. Generate bootable ISO with GRUB

### 5. Build Output
When complete, you'll find:
```
iso-build/
├── SecureOS-1.0.0-amd64.iso       # Bootable ISO (~1.5GB)
├── SecureOS-1.0.0-amd64.iso.sha256 # SHA256 checksum
└── SecureOS-1.0.0-amd64.iso.md5    # MD5 checksum
```

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
- Free up at least 10GB
- Build uses `/tmp/secureos-build` (needs 5-8GB temp space)

### Error: "Permission denied"
- Must run with `sudo`
- Check file permissions

### Error: "Failed to download packages"
- Check internet connection
- Try different mirror in sources.list
- Retry the build

### Build Hangs or Freezes
- Check system resources (RAM, CPU)
- Kill and restart: `sudo killall debootstrap`
- Clear temp: `sudo rm -rf /tmp/secureos-build`

### Error: "Invalid GPG signature"
- Update GPG keys:
  ```bash
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys [KEY_ID]
  ```

## Build Cleanup

After successful build:
```bash
# Temporary build files are auto-cleaned
# But you can manually clean with:
sudo rm -rf /tmp/secureos-build
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

## Next Steps After Building

1. **Verify the ISO**:
   ```bash
   sha256sum -c iso-build/SecureOS-1.0.0-amd64.iso.sha256
   ```

2. **Test in VM** before deploying to production

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
