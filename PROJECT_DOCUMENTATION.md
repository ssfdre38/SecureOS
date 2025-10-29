# SecureOS - Complete Project Documentation

**Server Location:** `/mnt/projects/repos/secureos/`  
**Developer:** Barrer Software  
**Last Updated:** 2025-10-29

---

## 📋 Project Overview

SecureOS is a security and privacy-enhanced Linux distribution based on Ubuntu 24.04 LTS. It's designed for security-conscious users, privacy advocates, and enterprise deployments requiring hardened systems.

---

## 🌐 Online Presence

- **Main Website:** https://secureos.xyz
- **Package Repository:** http://repo.secureos.xyz
- **GitHub Repository:** https://github.com/ssfdre38/SecureOS
- **Downloads:** https://github.com/ssfdre38/SecureOS/releases
- **Documentation:** https://secureos.github.io

---

## ✨ Features

### Security Features

#### Disk & Boot Security
- **Full Disk Encryption:** LUKS2 with Argon2id key derivation
- **Secure Boot:** UEFI Secure Boot support
- **Kernel Lockdown:** Prevents runtime modification of kernel
- **Hardened Kernel:** Custom kernel parameters for security

#### Access Control
- **AppArmor:** Mandatory Access Control profiles enforced
- **UFW Firewall:** Pre-configured deny-by-default firewall
- **Root Login Disabled:** No direct root access
- **Strong Password Policies:** Enforced password complexity
- **SSH Hardening:** Secure SSH configuration out-of-the-box

#### Monitoring & Detection
- **Audit Logging:** Comprehensive system auditing with auditd
- **Fail2ban:** Automatic IP blocking for brute force attempts
- **AIDE:** Advanced Intrusion Detection Environment
- **rkhunter:** Rootkit detection
- **chkrootkit:** Additional rootkit scanning
- **ClamAV:** Antivirus with automatic updates

#### Updates & Maintenance
- **Automatic Security Updates:** Unattended security patches
- **Repository Signing:** All packages cryptographically signed
- **Verified Boot Chain:** Ensures system integrity

### Privacy Features

#### Network Privacy
- **Zero Telemetry:** All telemetry and error reporting disabled
- **Encrypted DNS:** DNS over TLS (DoT) by default
  - Primary: Quad9 (9.9.9.9)
  - Secondary: Cloudflare (1.1.1.1)
- **MAC Randomization:** Network interface MAC address randomization
- **VPN Ready:** Pre-configured for VPN usage

#### Anonymous Browsing
- **Tor Browser:** Pre-installed with Tor daemon
- **Privoxy:** HTTP proxy for enhanced privacy
- **No Tracking:** No user analytics or tracking

#### Data Protection
- **MAT2 Tool:** Metadata removal from files
- **Secure Deletion:** Tools for secure file wiping
- **Minimal Data Collection:** Only essential system logs

### Hardening Features

#### Kernel Hardening
- Kernel lockdown mode enabled
- Restricted kernel module loading
- Protected kernel pointers (kptr_restrict)
- Protected dmesg output
- Disabled kernel debugging interfaces

#### Network Hardening
- IP forwarding disabled
- ICMP redirects disabled
- Source routing disabled
- SYN cookies enabled
- TCP hardening parameters

#### System Hardening
- Disabled unnecessary services
- Secure default file permissions
- No SUID binaries where possible
- Restricted core dumps
- Disabled USB storage (optional)

#### Application Security
- **Firejail:** Application sandboxing
- **AppArmor Profiles:** For common applications
- **Restricted /tmp:** Separate partition with noexec

---

## 📦 Package Structure

### Core Packages

#### 1. secureos-meta
**Description:** Meta package that pulls in all SecureOS components  
**Dependencies:** All other secureos-* packages  
**Size:** ~1KB (metadata only)

#### 2. secureos-tools
**Description:** Security tools and utilities  
**Includes:**
- ClamAV (antivirus)
- Fail2ban (intrusion prevention)
- AIDE (intrusion detection)
- rkhunter (rootkit detection)
- chkrootkit (rootkit scanner)
- Firejail (sandboxing)
- MAT2 (metadata removal)
- Tor & Privoxy

#### 3. secureos-hardening
**Description:** System hardening configurations  
**Includes:**
- Kernel hardening parameters
- Sysctl security settings
- AppArmor profiles
- UFW firewall rules
- SSH hardening config
- PAM security modules
- Login policies

#### 4. secureos-privacy
**Description:** Privacy enhancements  
**Includes:**
- DNS-over-TLS configuration
- Telemetry disabling scripts
- MAC randomization
- Browser privacy configs
- Tracking blockers

---

## 🏗️ Build System

### Build Script
**Location:** `/mnt/projects/repos/secureos/build.sh`

### Build Process

1. **Package Preparation**
   - Validates package structure
   - Checks dependencies
   - Verifies file permissions

2. **Debian Package Building**
   - Creates .deb packages for each component
   - Signs packages with GPG key
   - Generates package metadata

3. **Repository Update**
   - Adds packages to APT repository
   - Updates repository metadata
   - Regenerates package indices

4. **ISO Building (Optional)**
   - Creates bootable ISO image
   - Includes all packages
   - Configures installer

### Build Output

**Packages:** `/mnt/projects/builds/packages/`
- `secureos-meta_*.deb`
- `secureos-tools_*.deb`
- `secureos-hardening_*.deb`
- `secureos-privacy_*.deb`

**ISO Images:** `/mnt/projects/repos/secureos/iso-output/`
- `SecureOS-*.iso`
- `SecureOS-*.iso.sha256`

### Build Methods

#### Via Web Interface
```
URL: http://dev.barrersoftware.com
Login: ssfdre38 / Fairfield866 (or passkey)
Click: "Start SecureOS Build"
```

#### Via API
```bash
curl -X POST http://dev.barrersoftware.com/api/build/secureos \
  -u ssfdre38:Fairfield866
```

#### Direct Execution
```bash
cd /mnt/projects/repos/secureos
bash build.sh
```

#### Monitor Build
```bash
# Watch build log
tail -f /mnt/projects/repos/secureos/build.log

# Or use monitoring script
bash /mnt/projects/repos/secureos/monitor-build.sh
```

---

## 📚 APT Repository

### Repository Details
- **URL:** http://repo.secureos.xyz
- **Type:** APT repository (reprepro)
- **Distributions:** noble (Ubuntu 24.04)
- **Components:** main, security
- **Architecture:** amd64
- **Signing:** GPG signed packages

### Automatic Updates
- **Schedule:** Daily at 3:00 AM UTC
- **Cron Job:** `/etc/cron.d/secureos-repo-update`
- **Script:** Automatic reprepro export
- **Log:** `/var/log/secureos-repo-update.log`

### Client Setup

**Add Repository:**
```bash
# Download GPG key
wget -qO - http://repo.secureos.xyz/secureos-repo.gpg | sudo apt-key add -

# Add repository
echo "deb http://repo.secureos.xyz noble main security" | \
  sudo tee /etc/apt/sources.list.d/secureos.list

# Update package list
sudo apt update
```

**Install SecureOS:**
```bash
# Install all components
sudo apt install secureos-meta

# Or install individual packages
sudo apt install secureos-tools
sudo apt install secureos-hardening
sudo apt install secureos-privacy
```

---

## 🗂️ Directory Structure

```
/mnt/projects/repos/secureos/
├── README.md                  # Main documentation
├── BUILD.md                   # Build instructions
├── BUILD_STATUS.md            # Current build status
├── PROJECT_STATUS.md          # Project roadmap
├── DOMAIN_SETUP.md            # Domain configuration
├── SETUP_STATUS.md            # Setup checklist
├── COPYRIGHT.md               # Copyright information
├── CONTRIBUTING.md            # Contribution guidelines
├── LICENSE                    # License file
├── .github/                   # GitHub Actions
├── advanced-features/         # Advanced configurations
├── apt-repo/                  # Repository tools
├── config/                    # Configuration files
├── installer/                 # Installation scripts
├── iso-output/                # ISO build output
├── packages/                  # Package source files
├── scripts/                   # Build and utility scripts
├── v3.0.0/                    # Version 3.0.0
├── v4.0.0/                    # Version 4.0.0
├── v5.0.0/                    # Version 5.0.0
├── v6.0.0/                    # Version 6.0.0 (current)
├── build.sh                   # Main build script
├── monitor-build.sh           # Build monitoring
├── demo.sh                    # Demo/testing script
├── build.log                  # Build log file
└── requirements.txt           # Python dependencies
```

---

## 🚀 Installation

### Prerequisites
- **CPU:** 64-bit x86 processor
- **RAM:** 2GB minimum (4GB recommended)
- **Disk:** 20GB minimum
- **Boot:** UEFI or Legacy BIOS support

### Install on Existing Ubuntu 24.04

```bash
# Add SecureOS repository
wget -qO - http://repo.secureos.xyz/secureos-repo.gpg | sudo apt-key add -
echo "deb http://repo.secureos.xyz noble main security" | \
  sudo tee /etc/apt/sources.list.d/secureos.list

# Update and install
sudo apt update
sudo apt install secureos-meta

# Reboot to apply all changes
sudo reboot
```

### Clean Installation (ISO)

1. **Download ISO:**
   ```bash
   wget https://github.com/ssfdre38/SecureOS/releases/latest/download/SecureOS-amd64.iso
   ```

2. **Create Bootable USB:**
   ```bash
   # Linux
   sudo dd if=SecureOS-amd64.iso of=/dev/sdX bs=4M status=progress
   sync
   ```

3. **Boot and Install:**
   - Boot from USB
   - Select language and keyboard
   - Follow installation wizard
   - Set up disk encryption
   - Create user account
   - Reboot when complete

---

## 🔧 Configuration

### Post-Installation

**Enable All Security Features:**
```bash
sudo systemctl enable --now fail2ban
sudo systemctl enable --now clamav-freshclam
sudo systemctl enable --now tor
sudo ufw enable
```

**Update Security Tools:**
```bash
sudo freshclam                    # Update ClamAV
sudo rkhunter --update            # Update rkhunter
sudo rkhunter --propupd           # Update file properties
sudo aide --init                  # Initialize AIDE
```

### Customization

**Firewall Rules:**
```bash
# Allow specific ports
sudo ufw allow 22/tcp             # SSH
sudo ufw allow 80/tcp             # HTTP
sudo ufw allow 443/tcp            # HTTPS

# Check status
sudo ufw status verbose
```

**DNS Configuration:**
Edit `/etc/systemd/resolved.conf`:
```ini
[Resolve]
DNS=9.9.9.9 1.1.1.1
DNSOverTLS=yes
DNSSEC=yes
```

**Privacy Settings:**
```bash
# Disable services (if needed)
sudo systemctl disable cups       # Printing
sudo systemctl disable bluetooth  # Bluetooth

# Enable MAC randomization
sudo nano /etc/NetworkManager/NetworkManager.conf
# Add:
# [connection]
# wifi.mac-address-randomization=1
```

---

## 🧪 Testing & Verification

### Security Tests

**Check Firewall:**
```bash
sudo ufw status
sudo iptables -L -n -v
```

**Check Kernel Security:**
```bash
cat /proc/sys/kernel/kptr_restrict      # Should be 2
cat /proc/sys/kernel/dmesg_restrict     # Should be 1
cat /proc/sys/kernel/yama/ptrace_scope  # Should be 1
```

**Run Security Scan:**
```bash
sudo rkhunter --check
sudo chkrootkit
sudo aide --check
```

**Check Services:**
```bash
systemctl list-units --state=running
sudo ss -tulpn
```

### Privacy Tests

**Verify DNS-over-TLS:**
```bash
resolvectl status
# Should show DNS over TLS: yes
```

**Check for Telemetry:**
```bash
# Ubuntu telemetry should be disabled
ubuntu-report show
```

**Test Tor:**
```bash
# Check Tor is running
systemctl status tor

# Test connection
curl --socks5 localhost:9050 https://check.torproject.org/api/ip
```

---

## 📊 System Requirements

### Minimum Requirements
- **CPU:** 1 GHz 64-bit processor
- **RAM:** 2 GB
- **Disk:** 20 GB
- **Graphics:** 1024x768 resolution

### Recommended Requirements
- **CPU:** 2 GHz dual-core processor
- **RAM:** 4 GB
- **Disk:** 50 GB (SSD recommended)
- **Graphics:** 1920x1080 resolution

### Optimal Requirements (for full features)
- **CPU:** 2+ GHz quad-core processor
- **RAM:** 8 GB+
- **Disk:** 100 GB+ SSD
- **Graphics:** Dedicated GPU

---

## 🔄 Version History

### v6.0.0 (Current - In Development)
- Enhanced privacy features
- Updated to Ubuntu 24.04 LTS
- Improved hardening configurations
- Better documentation

### v5.0.0
- Added privacy enhancements
- DNS-over-TLS by default
- MAC randomization
- Tor integration

### v4.0.0
- Enhanced security features
- Improved intrusion detection
- Better firewall management
- Application sandboxing

### v3.0.0
- Initial public release
- Core security features
- Basic hardening
- Package repository

---

## 🤝 Contributing

### Development Setup
```bash
# Fork and clone
git clone https://github.com/yourusername/SecureOS.git
cd SecureOS

# Create feature branch
git checkout -b feature/your-feature

# Make changes and commit
git add .
git commit -m "Add your feature"

# Push and create PR
git push origin feature/your-feature
```

### Contribution Guidelines
See [CONTRIBUTING.md](CONTRIBUTING.md) in the repository

---

## 📞 Support

- **Documentation:** https://secureos.github.io
- **Issues:** https://github.com/ssfdre38/SecureOS/issues
- **Email:** secureos@barrersoftware.com
- **Website:** https://secureos.xyz

---

## 📄 License

SecureOS is licensed under the terms specified in the LICENSE file.

**Copyright © 2025 Barrer Software**

---

## 🔗 Related Projects

- **SecureVault Browser:** Privacy-focused web browser
- **VelocityPanel:** Web hosting control panel
- **AI Security Scanner:** Automated security scanning

---

**Project maintained by Barrer Software**  
**For more information visit: https://barrersoftware.com**
