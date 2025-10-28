# SecureOS Advanced Features - Version 1.1.0 & 2.0.0

This directory contains advanced security and privacy features for SecureOS.

## Version 1.1.0 Features

### 1. VPN Integration (`vpn-integration.sh`)
Complete VPN support with WireGuard and OpenVPN:
- **WireGuard**: Modern, fast VPN protocol
- **OpenVPN**: Traditional, widely-supported VPN
- **Kill Switch**: Blocks all traffic if VPN disconnects
- **DNS Leak Protection**: Prevents DNS queries outside VPN
- **Easy Management**: `secureos-vpn` command-line tool

**Installation**:
```bash
sudo bash advanced-features/vpn-integration.sh
```

**Usage**:
```bash
secureos-vpn wg-generate       # Generate WireGuard keys
secureos-vpn wg-connect        # Connect WireGuard
secureos-vpn check-leak        # Check for leaks
```

### 2. Enhanced MAC Randomization (`enhanced-mac-randomization.sh`)
Advanced privacy through MAC address randomization:
- **Automatic Randomization**: On boot and per-connection
- **NetworkManager Integration**: Different MAC per WiFi network
- **Easy Control**: Command-line interface

**Installation**:
```bash
sudo bash advanced-features/enhanced-mac-randomization.sh
```

**Usage**:
```bash
secureos-mac list              # List interfaces
secureos-mac random wlan0      # Randomize MAC
secureos-mac restore wlan0     # Restore original
```

### 3. Container Security Hardening (`container-security.sh`)
Enhanced security for Docker and containerized applications:
- **Seccomp Filtering**: Restrict system calls
- **AppArmor Profiles**: Mandatory access control
- **User Namespace Remapping**: Prevent privilege escalation
- **Audit Logging**: Track container activity
- **Security Scanning**: Vulnerability detection

**Installation**:
```bash
sudo bash advanced-features/container-security.sh
```

**Usage**:
```bash
secureos-container audit           # Audit running containers
secureos-container scan            # Scan for vulnerabilities
secureos-container secure-run img  # Run container securely
```

## Version 2.0.0 Features

### 1. Custom Hardened Kernel (`custom-kernel-builder.sh`)
Build a custom kernel with enhanced security:
- **Kernel Lockdown**: Prevents runtime modifications
- **Memory Protections**: ASLR, stack canaries, SMAP/SMEP
- **Module Signing**: Only signed modules can load
- **BPF Hardening**: Secure BPF JIT compiler
- **Attack Surface Reduction**: Disabled legacy features

**Build Kernel**:
```bash
sudo bash advanced-features/custom-kernel-builder.sh
```

**Warning**: Kernel builds take 1-2 hours and require 20GB+ disk space

### 2. Advanced Intrusion Detection (`advanced-ids.sh`)
Real-time threat detection and automated response:
- **AIDE Integration**: File integrity monitoring
- **Auth Log Monitoring**: Detect brute force attacks
- **Auto IP Blocking**: Automatic firewall rules
- **Port Scanning Detection**: Find unexpected services
- **Automated Response**: Block threats automatically

**Installation**:
```bash
sudo bash advanced-features/advanced-ids.sh
```

**Control**:
```bash
sudo systemctl start secureos-ids    # Start monitoring
sudo systemctl status secureos-ids   # Check status
sudo tail -f /var/log/secureos-ids.log  # View logs
```

### 3. GUI Security Manager (`gui-security-manager.py`)
Graphical interface for security management:
- **Dashboard**: Real-time security status
- **Firewall Control**: Easy firewall management
- **Privacy Tools**: VPN, Tor, MAC randomization
- **Security Scans**: Rootkit, virus, integrity checks
- **Quick Actions**: One-click security tools

**Launch**:
```bash
python3 advanced-features/gui-security-manager.py
```

**Requires**: PyQt5 (auto-installed on first run)

## SecureOS Packages

Custom Debian packages for easy installation:

### Build Packages

```bash
# Build metapackage (installs all security tools)
bash packages/build-meta.sh

# Build SecureOS tools package
bash packages/build-tools.sh
```

### Install Packages

```bash
sudo dpkg -i secureos-meta_1.1.0_all.deb
sudo dpkg -i secureos-tools_1.1.0_all.deb
```

## APT Repository

Host your own SecureOS package repository:

### Setup Repository

```bash
sudo bash apt-repo/setup-repo.sh
```

### Add Packages

```bash
sudo secureos-repo add package.deb
sudo secureos-repo update
```

### Client Configuration

```bash
# On client machines
wget -qO - http://repo.secureos.local/secureos-repo.gpg | sudo apt-key add -
echo 'deb http://repo.secureos.local noble main security' | sudo tee /etc/apt/sources.list.d/secureos.list
sudo apt update
sudo apt install secureos-meta
```

## Feature Matrix

| Feature | Version | Status |
|---------|---------|--------|
| VPN Integration (WireGuard/OpenVPN) | 1.1.0 | ✅ Complete |
| Enhanced MAC Randomization | 1.1.0 | ✅ Complete |
| Container Security Hardening | 1.1.0 | ✅ Complete |
| Custom Hardened Kernel | 2.0.0 | ✅ Complete |
| Advanced Intrusion Detection | 2.0.0 | ✅ Complete |
| GUI Security Manager | 2.0.0 | ✅ Complete |
| APT Repository | Both | ✅ Complete |
| Secure Boot Signing | Future | 🔄 Planned |
| Biometric Authentication | Future | 🔄 Planned |

## Security Considerations

### VPN
- Always verify VPN provider's security practices
- Use kill switch to prevent leaks
- Test for DNS/IP leaks regularly

### MAC Randomization
- May break network authentication (802.1X)
- Some networks block randomized MACs
- Restore original MAC if needed

### Containers
- Never run containers as root
- Use read-only filesystems when possible
- Limit resources (CPU, memory)
- Scan images for vulnerabilities

### Custom Kernel
- Test in VM before production use
- Keep kernel updated
- Verify module signatures
- Monitor security advisories

### Intrusion Detection
- Tune thresholds to reduce false positives
- Review blocked IPs regularly
- Integrate with logging infrastructure
- Test automated responses carefully

## Integration with Base System

All features integrate seamlessly with base SecureOS:

```bash
# Full system with all features
sudo bash scripts/post_install_hardening.sh
sudo bash advanced-features/vpn-integration.sh
sudo bash advanced-features/enhanced-mac-randomization.sh
sudo bash advanced-features/container-security.sh
sudo bash advanced-features/advanced-ids.sh

# Or install via packages
sudo apt install secureos-meta secureos-tools
```

## Command Reference

### VPN Commands
```bash
secureos-vpn wg-generate       # Generate WireGuard keys
secureos-vpn wg-connect        # Connect WireGuard
secureos-vpn wg-disconnect     # Disconnect
secureos-vpn check-leak        # Test for leaks
```

### MAC Commands
```bash
secureos-mac list              # List interfaces
secureos-mac show wlan0        # Show current MAC
secureos-mac random wlan0      # Randomize MAC
secureos-mac restore wlan0     # Restore original
```

### Container Commands
```bash
secureos-container audit       # Audit containers
secureos-container scan        # Security scan
secureos-container status      # Show status
```

### IDS Commands
```bash
sudo systemctl start secureos-ids
sudo systemctl stop secureos-ids
sudo systemctl status secureos-ids
```

### Repository Commands
```bash
secureos-repo add pkg.deb      # Add package
secureos-repo remove pkg       # Remove package
secureos-repo list             # List packages
secureos-repo update           # Update metadata
```

## Troubleshooting

### VPN Issues
- Check configuration files
- Verify firewall rules: `sudo ufw status`
- Test connectivity: `ping 1.1.1.1`
- Check logs: `sudo journalctl -u wg-quick@wg0`

### MAC Randomization
- Disable for specific networks
- Check NetworkManager: `nmcli device show`
- Restore if broken: `secureos-mac restore wlan0`

### Container Security
- Check Docker daemon: `sudo systemctl status docker`
- View audit logs: `sudo ausearch -k docker`
- Test seccomp: `docker run --rm --security-opt seccomp=unconfined`

### IDS Issues
- Check service: `sudo systemctl status secureos-ids`
- View logs: `sudo cat /var/log/secureos-ids.log`
- Unblock IP: `sudo secureos-ids-response unblock IP`

## Contributing

To add new features:
1. Create script in `advanced-features/`
2. Follow naming convention
3. Add documentation here
4. Test thoroughly
5. Submit pull request

## License

All SecureOS components inherit from base system licenses. Custom tools are provided as-is for security and privacy enhancement.

## Support

- Issues: https://github.com/ssfdre38/SecureOS/issues
- Discussions: https://github.com/ssfdre38/SecureOS/discussions
- Security: Report privately to maintainers

---

**SecureOS Advanced Features** - Security and Privacy Enhanced
