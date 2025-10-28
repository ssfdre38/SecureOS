# SecureOS v3.0.0 - Advanced Features

Welcome to SecureOS v3.0.0! This version includes major enhancements for both desktop and server deployments.

## 🎯 What's New in v3.0.0

### Desktop Installation
- **Live ISO Environment**: Boot and try SecureOS without installing
- **XFCE Desktop**: Lightweight, fast, and secure desktop environment
- **Pre-installed Security Tools**: Full suite ready to use
- **One-Click Installer**: Desktop icon for easy installation

### Server Installation with Role Selection
Choose exactly what you need for your server:

| Role | Description | Key Components |
|------|-------------|----------------|
| **Base** | Minimal server install | SSH, firewall, fail2ban |
| **Web Host** | Full web stack | nginx, Apache, PHP 8.3, MySQL |
| **VPN Server** | Secure remote access | WireGuard, OpenVPN |
| **Dev Environment** | Development tools | Docker, Node.js, Python, Go |
| **VS Code Server** | Web-based IDE | code-server on port 8080 |
| **File Server** | Network storage | Samba, NFS, ZFS support |
| **ZFS Web Interface** | Storage management | Cockpit with ZFS plugin |
| **Mail Server** | Email hosting | Postfix, Dovecot, DKIM |
| **Database Server** | Database hosting | PostgreSQL, MySQL, Redis |
| **Monitoring** | System monitoring | Prometheus, Grafana |
| **Container Host** | Containerization | Docker, Kubernetes (k3s) |
| **Backup Server** | Backup solution | Bacula, Borg, rsync |

## 🚀 Quick Start

### Build Live ISO

```bash
cd /home/ubuntu/SecureOS/v3.0.0/live-iso
sudo bash build-live-iso.sh
```

Creates: `secureos-3.0.0-live-amd64.iso`

### Test in VM

```bash
qemu-system-x86_64 -cdrom output/secureos-3.0.0-live-amd64.iso -m 4096 -enable-kvm
```

### Burn to USB

```bash
sudo dd if=output/secureos-3.0.0-live-amd64.iso of=/dev/sdX bs=4M status=progress
```

## 📦 Installation Types

### Desktop Installation

Perfect for:
- Workstations
- Privacy-focused personal computers
- Security testing environments
- Learning Linux security

Includes:
- XFCE desktop environment
- Firefox browser
- Security tools (UFW, AppArmor, fail2ban, etc.)
- File manager, terminal, text editor
- Automatic security updates

### Server Installation

Choose from 12 pre-configured server roles:

#### 1. Base Server
Minimal installation with:
- SSH access
- UFW firewall
- fail2ban intrusion prevention
- Unattended security updates
- Essential utilities

#### 2. Web Host
Complete LAMP/LEMP stack:
- **nginx** - High-performance web server
- **Apache** - Alternative web server (disabled by default)
- **PHP 8.3** - Latest PHP with extensions
- **MySQL** - Database server
- **Certbot** - Free SSL certificates

Default site: `http://YOUR_IP/`
PHP info: Create `/var/www/html/info.php`

#### 3. VPN Server
Secure remote access:
- **WireGuard** - Modern, fast VPN (port 51820)
- **OpenVPN** - Traditional VPN (port 1194)
- Pre-generated keys
- NAT traversal configured

Config: `/etc/wireguard/wg0.conf`
Start: `systemctl start wg-quick@wg0`

#### 4. Development Environment
Full dev stack:
- **Docker** + docker-compose
- **Node.js** + npm
- **Python 3** + pip + venv
- **Go** language
- **Git** with LFS
- Build tools (gcc, make, etc.)
- PostgreSQL and Redis clients

#### 5. VS Code Server
Browser-based development:
- Full VS Code in browser
- Extensions support
- Terminal access
- Git integration

Access: `http://YOUR_IP:8080`
Password: `changeme` (CHANGE THIS!)

#### 6. File Server
Network file sharing:
- **Samba** - Windows-compatible shares
- **NFS** - Linux/Unix file sharing
- **ZFS** - Advanced filesystem support

Samba share: `//YOUR_IP/shared`
NFS mount: `mount YOUR_IP:/srv/nfs /mnt`

#### 7. ZFS Web Interface
Web-based storage management:
- **Cockpit** - System management
- **ZFS plugin** - Pool/dataset management
- Real-time monitoring
- Snapshot management

Access: `https://YOUR_IP:9090`

#### 8. Mail Server
Email hosting:
- **Postfix** - SMTP server
- **Dovecot** - IMAP/POP3 server
- **OpenDKIM** - Email authentication
- TLS encryption

Ports: 25 (SMTP), 587 (submission), 993 (IMAPS)

#### 9. Database Server
Multiple databases:
- **PostgreSQL** - Advanced SQL database
- **MySQL** - Popular SQL database
- **Redis** - In-memory data store

Remote access enabled (configure passwords!)

#### 10. Monitoring Stack
Complete monitoring:
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards
- **Node Exporter** - System metrics

Grafana: `http://YOUR_IP:3000` (admin/admin)

#### 11. Container Host
Container platform:
- **Docker** - Container runtime
- **docker-compose** - Multi-container apps
- **k3s** - Lightweight Kubernetes
- **kubectl** - Kubernetes CLI

Ready for microservices deployment

#### 12. Backup Server
Backup solutions:
- **Bacula** - Enterprise backup
- **BorgBackup** - Deduplication backup
- **rsync** - File synchronization

Backup directory: `/backup`

## 🔒 Security Features

All installations include:

### System Security
- ✅ Full disk encryption (LUKS2)
- ✅ AppArmor mandatory access control
- ✅ Kernel hardening parameters
- ✅ Secure boot support (optional)

### Network Security
- ✅ UFW firewall (deny by default)
- ✅ fail2ban intrusion prevention
- ✅ Automatic port configuration per role
- ✅ TLS/SSL ready

### Monitoring & Auditing
- ✅ Audit logging (auditd)
- ✅ System event logging
- ✅ File integrity monitoring (AIDE)
- ✅ Rootkit detection (rkhunter)

### Updates & Maintenance
- ✅ Automatic security updates
- ✅ Unattended upgrades configured
- ✅ Package signature verification

## 🎨 Interactive Installer

The v3.0.0 installer features:

1. **Welcome Screen**
   - Introduction and overview
   - System requirements check

2. **Installation Type Selection**
   - Desktop: Full GUI environment
   - Server: Minimal with role selection

3. **Server Role Selection** (Server only)
   - Multi-select interface
   - Space to toggle roles
   - Detailed descriptions

4. **Installation Summary**
   - Review all selections
   - Confirm before installing

5. **Installation Progress**
   - Real-time status updates
   - Role-by-role installation

6. **Post-Installation**
   - Access credentials
   - Next steps guide
   - Service URLs

## 📊 System Requirements

### Desktop Installation
- **CPU**: 2+ cores recommended
- **RAM**: 2 GB minimum, 4 GB recommended
- **Disk**: 20 GB minimum, 40 GB recommended
- **Graphics**: Any (supports safe graphics mode)

### Server Installation
- **CPU**: 1+ cores (more for containers/k8s)
- **RAM**: 1 GB minimum (varies by roles)
  - Base: 1 GB
  - Web: 2 GB
  - Database: 2 GB
  - Monitoring: 4 GB
  - Container: 4 GB+
- **Disk**: 10 GB minimum (varies by roles)
  - File server: 100+ GB recommended
  - ZFS: Multiple drives recommended
  - Backup: Large storage

## 🔧 Post-Installation Tasks

### All Installations

1. **Change default passwords**
   ```bash
   sudo passwd root
   sudo passwd secureos
   ```

2. **Update system**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Configure firewall rules**
   ```bash
   sudo ufw status
   sudo ufw allow PORT/tcp comment 'DESCRIPTION'
   ```

### Web Server

1. **Change MySQL root password**
   ```bash
   sudo mysql
   ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'newpassword';
   ```

2. **Configure SSL**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

### VS Code Server

1. **Change password**
   ```bash
   sudo nano /etc/systemd/system/code-server.service
   # Change PASSWORD= line
   sudo systemctl restart code-server
   ```

### VPN Server

1. **Add client**
   ```bash
   wg genkey | tee client_private.key | wg pubkey > client_public.key
   # Add to /etc/wireguard/wg0.conf
   systemctl restart wg-quick@wg0
   ```

### Database Server

1. **Create databases and users**
   ```bash
   # PostgreSQL
   sudo -u postgres createuser myuser
   sudo -u postgres createdb mydb
   
   # MySQL
   sudo mysql -e "CREATE DATABASE mydb;"
   sudo mysql -e "CREATE USER 'myuser'@'%' IDENTIFIED BY 'password';"
   sudo mysql -e "GRANT ALL ON mydb.* TO 'myuser'@'%';"
   ```

## 📚 Documentation

- **Main README**: `/home/ubuntu/SecureOS/README.md`
- **Advanced Features**: `/home/ubuntu/SecureOS/advanced-features/README.md`
- **APT Repository**: `/home/ubuntu/SecureOS/apt-repo/README.md`
- **Build Guide**: `/home/ubuntu/SecureOS/BUILD.md`

## 🐛 Troubleshooting

### Live ISO won't boot
- Try "Safe Graphics" option from GRUB menu
- Disable secure boot in BIOS
- Verify ISO checksum

### Installer crashes
- Check system has enough RAM (2GB+)
- Boot in safe graphics mode
- Check logs: `/var/log/installer/`

### Server role installation fails
- Check internet connection
- Verify disk space: `df -h`
- Review role logs in `/var/log/secureos/`

### Service won't start
```bash
# Check status
sudo systemctl status SERVICE

# View logs
sudo journalctl -u SERVICE -n 50

# Check firewall
sudo ufw status
```

## 🔄 Upgrading from v2.0.0

```bash
cd /home/ubuntu/SecureOS
git pull
sudo bash scripts/post_install_hardening.sh
```

New features can be installed individually:
```bash
# Add server roles to existing install
sudo bash v3.0.0/server-roles/install-roles.sh
```

## 🌐 Integration with GitHub

All v3.0.0 features are available via:
- **GitHub Releases**: Download pre-built ISOs
- **APT Repository**: Install packages
- **Source Code**: Build from source

```bash
# From GitHub Releases
curl -L https://github.com/ssfdre38/SecureOS/releases/download/v3.0.0/secureos-3.0.0-live-amd64.iso -o secureos.iso

# From APT Repository
curl -L https://github.com/ssfdre38/secureos-packages/releases/download/latest/install-client.sh | sudo bash
```

## 🤝 Contributing

We welcome contributions!

- Report bugs: https://github.com/ssfdre38/SecureOS/issues
- Submit PRs: https://github.com/ssfdre38/SecureOS/pulls
- Discussions: https://github.com/ssfdre38/SecureOS/discussions

## 📄 License

SecureOS is open source. Individual packages retain their original licenses.

## 🎉 Credits

Built with ❤️ for security and privacy enthusiasts

- Base: Ubuntu 24.04 LTS
- Desktop: XFCE
- Security: AppArmor, UFW, fail2ban, AIDE
- Packages: Hosted on GitHub

---

**SecureOS v3.0.0** - Your Security, Your Choice, Your Server
