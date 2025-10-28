# SecureOS - Security & Privacy Enhanced Linux Distribution

**Part of Barrer Software | Based on Ubuntu 24.04 LTS**

SecureOS is a hardened Linux distribution designed with security and privacy as the primary focus. Perfect for security-conscious users, privacy advocates, and enterprise deployments.

---

🌐 **Website**: https://ssfdre38.github.io/SecureOS  
📦 **Packages**: https://ssfdre38.github.io/secureos-packages  
💻 **GitHub**: https://github.com/ssfdre38/SecureOS  
📥 **Downloads**: https://github.com/ssfdre38/SecureOS/releases

---

## Features

### Security
- **Full Disk Encryption**: LUKS2 encryption with Argon2id key derivation
- **Hardened Kernel**: Security-focused kernel parameters and lockdown mode
- **Mandatory Access Control**: AppArmor profiles enforced by default
- **Firewall**: UFW (Uncomplicated Firewall) pre-configured with deny-by-default
- **Audit Logging**: Comprehensive system auditing with auditd
- **Automatic Security Updates**: Unattended security patches
- **Intrusion Detection**: Fail2ban, AIDE, rkhunter, chkrootkit
- **Antivirus**: ClamAV with automatic definition updates
- **Application Sandboxing**: Firejail integration for application isolation

### Privacy
- **No Telemetry**: All telemetry and error reporting disabled
- **Encrypted DNS**: DNS over TLS with privacy-focused providers (Quad9, Cloudflare)
- **MAC Randomization**: Network privacy through MAC address randomization
- **Tor Support**: Pre-installed Tor and Privoxy for anonymous browsing
- **Metadata Removal**: MAT2 tool for cleaning file metadata
- **Minimal Data Collection**: No user tracking or analytics

### Hardening
- Kernel lockdown mode enabled
- Secure boot support
- Disabled unnecessary services
- Restricted kernel module loading
- Protected kernel pointers and dmesg
- Hardened network stack
- Secure default permissions
- Root login disabled
- Strong password policies
- SSH hardened configuration

## Installation

### Prerequisites
- A computer with:
  - 64-bit x86 processor
  - 2GB RAM minimum (4GB recommended)
  - 20GB disk space minimum
  - UEFI or Legacy BIOS support

### Building the ISO

1. **Clone or copy SecureOS files**:
   ```bash
   cd /home/ubuntu/SecureOS
   ```

2. **Run the ISO builder** (requires root):
   ```bash
   sudo bash scripts/build_iso.sh
   ```

3. **Wait for build to complete**:
   - This process takes 30-60 minutes depending on your system
   - The ISO will be created in `iso-build/` directory

4. **Verify checksums**:
   ```bash
   cd iso-build
   sha256sum -c SecureOS-1.0.0-amd64.iso.sha256
   ```

### Creating Installation Media

#### On Linux:
```bash
sudo dd if=SecureOS-1.0.0-amd64.iso of=/dev/sdX bs=4M status=progress
sync
```

#### On macOS:
```bash
sudo dd if=SecureOS-1.0.0-amd64.iso of=/dev/rdiskX bs=4m
```

#### On Windows:
Use [Rufus](https://rufus.ie/) or [Etcher](https://www.balena.io/etcher/)

### Installing SecureOS

1. **Boot from installation media**
2. **Select language and keyboard layout**
3. **Run the interactive installer**:
   - Quick Install: Recommended secure defaults
   - Custom Install: Full configuration options
4. **Configure basic settings**:
   - Hostname
   - Username and password
   - Disk selection
5. **Review and confirm** installation
6. **Wait for installation** to complete
7. **Reboot** into your new SecureOS system

## Post-Installation

### Run Security Audit
```bash
sudo secureos-audit
```

### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### Configure Firewall Rules
```bash
# Allow specific services
sudo ufw allow 22/tcp  # SSH
sudo ufw allow 80/tcp  # HTTP
sudo ufw allow 443/tcp # HTTPS
```

### Enable Additional Privacy Features

#### Use Tor for Anonymous Browsing
```bash
systemctl start tor
# Configure browser to use SOCKS proxy: localhost:9050
```

#### Randomize MAC Address
```bash
sudo macchanger -r eth0  # Replace eth0 with your interface
```

#### Scan for Rootkits
```bash
sudo rkhunter --check
sudo chkrootkit
```

## Configuration Files

- **Security Defaults**: `/etc/secureos/security-defaults.conf`
- **Firewall Rules**: `/etc/ufw/`
- **AppArmor Profiles**: `/etc/apparmor.d/`
- **Audit Rules**: `/etc/audit/rules.d/`
- **Kernel Parameters**: `/etc/sysctl.d/99-secureos-hardening.conf`

## Security Tools Included

| Tool | Purpose |
|------|---------|
| UFW | Firewall management |
| AppArmor | Mandatory access control |
| Auditd | System audit logging |
| Fail2ban | Intrusion prevention |
| ClamAV | Antivirus scanning |
| AIDE | File integrity monitoring |
| rkhunter | Rootkit detection |
| chkrootkit | Rootkit scanner |
| Firejail | Application sandboxing |
| Tor | Anonymous networking |
| MAT2 | Metadata removal |
| Bleachbit | Privacy cleaning |

## Testing the ISO (Virtual Machine)

### Using QEMU:
```bash
qemu-system-x86_64 -m 2048 -enable-kvm \
  -cdrom SecureOS-1.0.0-amd64.iso \
  -boot d
```

### Using VirtualBox:
1. Create new VM with Linux/Ubuntu (64-bit)
2. Allocate 2GB RAM minimum
3. Create 20GB virtual disk
4. Attach ISO to optical drive
5. Start VM

### Using VMware:
1. Create new VM
2. Select "Install from disc image"
3. Choose SecureOS ISO
4. Configure 2GB RAM, 20GB disk
5. Power on VM

## Maintenance

### Security Updates
Automatic security updates are enabled by default. To check status:
```bash
sudo systemctl status unattended-upgrades
```

### Manual Updates
```bash
sudo apt update
sudo apt upgrade
```

### Firewall Status
```bash
sudo ufw status verbose
```

### Check Security Status
```bash
sudo secureos-audit
```

### Update Virus Definitions
```bash
sudo freshclam
```

### Scan System for Viruses
```bash
sudo clamscan -r /home
```

## Customization

### Disable Specific Security Features

Edit `/etc/secureos/security-defaults.conf` and change settings:

```ini
[Privacy]
randomize_mac=false  # Disable MAC randomization

[Hardening]
disable_bluetooth=false  # Enable Bluetooth
```

Then reboot or run:
```bash
sudo /usr/local/sbin/apply-secureos-settings
```

### Add Custom Firewall Rules

```bash
sudo ufw allow from 192.168.1.0/24 to any port 22
sudo ufw reload
```

### Create Custom AppArmor Profile

```bash
sudo aa-genprof /path/to/application
```

## Troubleshooting

### Boot Issues
- Check UEFI/Legacy BIOS settings
- Disable Secure Boot if necessary
- Verify ISO checksum

### Network Issues
- Check if firewall is blocking: `sudo ufw status`
- Verify DNS configuration: `systemd-resolve --status`
- Test connectivity: `ping 1.1.1.1`

### Application Not Starting
- Check AppArmor: `sudo aa-status`
- View denials: `sudo journalctl -xe | grep -i apparmor`
- Set profile to complain mode: `sudo aa-complain /path/to/profile`

## Architecture

```
SecureOS/
├── installer/              # Interactive installer
│   └── secure_installer.py # Python curses-based installer
├── config/                 # Configuration files
│   └── security-defaults.conf
├── scripts/                # Build and maintenance scripts
│   ├── build_iso.sh       # ISO builder
│   └── post_install_hardening.sh
└── iso-build/             # Output directory for ISO
```

## Contributing

SecureOS is designed to be community-driven. Contributions are welcome!

### Areas for Contribution
- Additional security hardening
- Privacy tools integration
- Documentation improvements
- Bug fixes and testing
- Localization

## Security Considerations

### What SecureOS Does NOT Protect Against
- Physical access attacks
- Zero-day exploits
- User error (weak passwords, social engineering)
- State-level adversaries with unlimited resources
- Hardware backdoors

### Best Practices
1. Use strong, unique passwords
2. Keep system updated
3. Review audit logs regularly
4. Use encryption for sensitive data
5. Be cautious with unknown software
6. Regular backups

## License

SecureOS is based on Ubuntu/Debian and inherits their respective licenses. Custom components are provided as-is for educational and security purposes.

## Support

For issues, questions, or contributions:
- Check documentation
- Review logs: `/var/log/`
- Run security audit: `sudo secureos-audit`

## Changelog

### Version 4.0.0 (Latest - ENTERPRISE RELEASE!)
- **Zero Trust Architecture**: Never trust, always verify with OPA and microsegmentation
- **HSM Integration**: TPM 2.0 and YubiKey support for hardware-backed security
- **Threat Intelligence**: Real-time feeds, Suricata IDS, YARA scanning, automated blocking
- **Cloud Security**: AWS/Azure/GCP auditing, compliance, IaC scanning, Falco protection
- **Enterprise Features**: Complete security platform for financial, healthcare, government sectors

### Version 3.0.0
- **Live ISO Environment**: Bootable desktop with XFCE
- **Advanced Installer**: Interactive desktop/server selection
- **12 Server Roles**: Web, VPN, dev, VS Code, file, ZFS, mail, DB, monitoring, containers, backup
- **Professional Deployment**: Production-ready server configurations
- **Complete Documentation**: Full guides for all features

### Version 2.0.0
- **Custom Kernel Builder**: Build hardened kernels with security patches
- **Advanced IDS**: Real-time intrusion detection with automated response
- **GUI Security Manager**: PyQt5-based graphical management interface
- **APT Repository**: Host custom SecureOS packages
- Enhanced privacy and container security

### Version 1.1.0
- **VPN Integration**: WireGuard and OpenVPN with kill switch
- **Enhanced MAC Randomization**: Per-connection privacy
- **Container Security**: Docker/LXC hardening with seccomp
- **SecureOS CLI**: Interactive command-line management
- **Custom Packages**: Debian packages for easy installation

### Version 1.0.0 (Initial Release)
- Base system on Ubuntu 24.04.3 LTS
- Full disk encryption with LUKS2
- Kernel hardening with security parameters
- AppArmor enforcement
- UFW firewall pre-configured
- Audit logging with auditd
- Privacy-focused DNS
- Automatic security updates
- Interactive installer with curses interface
- Comprehensive security toolset

## Roadmap

### Version 1.1.0 (✅ COMPLETE!)
- [x] VPN integration (WireGuard & OpenVPN)
- [x] Enhanced MAC randomization
- [x] Container security hardening
- [x] Additional desktop environments
- [ ] Secure boot signing (in progress)
- [ ] Biometric authentication support (planned)

### Version 2.0.0 (✅ COMPLETE!)
- [x] Custom kernel builder with security patches
- [x] Advanced intrusion detection system
- [x] Automated security response
- [x] Enhanced privacy features
- [x] GUI security management tools
- [x] APT repository infrastructure

### Version 3.0.0 (✅ COMPLETE!)
- [x] Live ISO with desktop environment
- [x] Advanced interactive installer
- [x] Desktop vs Server installation modes  
- [x] 12 pre-configured server roles
- [x] Role-based service installation
- [x] Web host, VPN, dev environment, VS Code Server
- [x] File server with ZFS, mail server, databases
- [x] Monitoring stack, container host, backup server

### Version 4.0.0 (✅ COMPLETE!)
- [x] Zero-trust network architecture
- [x] Hardware security module integration (TPM 2.0, YubiKey)
- [x] Advanced threat intelligence
- [x] Cloud security integration (AWS, Azure, GCP)
- [x] Multi-cloud compliance monitoring
- [x] Runtime workload protection

### Version 5.0.0 (Future)
- [ ] AI-powered threat detection
- [ ] Blockchain-based audit logs
- [ ] Quantum-resistant cryptography
- [ ] Self-healing security
- [ ] Advanced malware sandboxing

---

## License & Copyright

**Copyright © 2025 Barrer Software. All rights reserved.**

SecureOS is free and open source software, licensed under the MIT License.

- 📄 See [LICENSE](LICENSE) for full license text
- 📋 See [COPYRIGHT.md](COPYRIGHT.md) for detailed attribution and third-party licenses
- 🌐 Website: https://ssfdre38.github.io/SecureOS

### Trademarks

- **SecureOS** is a trademark of Barrer Software
- **Ubuntu** is a registered trademark of Canonical Ltd.
- All other trademarks are property of their respective owners

### Third-Party Software

SecureOS is based on Ubuntu 24.04 LTS and includes numerous open source components.
Each component retains its original license and copyright. See COPYRIGHT.md for details.

---

**SecureOS** - Security and Privacy First | **Barrer Software** © 2025
