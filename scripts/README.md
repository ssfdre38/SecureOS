# SecureOS Scripts Directory

This directory contains utility scripts for managing and maintaining SecureOS.

## Available Scripts

### 🔧 Installation & Setup

#### `quick-setup.sh`
**One-command secure system setup**

```bash
sudo bash scripts/quick-setup.sh
```

Features:
- Installs base security tools (UFW, Fail2ban, AppArmor, etc.)
- Configures firewall with secure defaults
- Hardens kernel parameters
- Sets up automatic security updates
- Initializes intrusion detection

---

### 📊 Monitoring & Health

#### `health-check.sh`
**Comprehensive system health report**

```bash
sudo bash scripts/health-check.sh
```

Checks:
- System resources (CPU, RAM, disk)
- Security services status
- v5.0.0 components status
- Firewall rules
- Failed login attempts
- Available updates
- Blockchain integrity
- Network connections
- Overall health score

---

### 🧪 Testing

#### `test-suite.sh`
**Run all SecureOS tests**

```bash
sudo bash scripts/test-suite.sh
```

Tests:
- Base system requirements
- Security tools installation
- v5.0.0 components functionality
- Configuration files
- File integrity
- Security settings

---

### 💾 Backup & Restore

#### `backup.sh`
**Backup all SecureOS configurations**

```bash
sudo bash scripts/backup.sh
```

Backs up:
- `/etc/secureos` - Configuration files
- `/var/lib/secureos` - Data and databases
- `/var/log/secureos` - Logs
- `/etc/ufw` - Firewall rules
- `/etc/fail2ban` - Intrusion detection config
- `/etc/apparmor.d` - AppArmor profiles
- Kernel hardening settings

Restore:
```bash
sudo tar -xzf /var/backups/secureos/secureos_backup_TIMESTAMP.tar.gz -C /
```

---

### 🔄 Updates

#### `update.sh`
**Update SecureOS to latest version**

```bash
sudo bash scripts/update.sh
```

Process:
1. Creates backup
2. Updates repository
3. Updates system packages
4. Updates Python dependencies
5. Runs post-update tests

---

### 🏗️ Build Scripts

#### `build_iso.sh`
**Build SecureOS bootable ISO**

```bash
sudo bash scripts/build_iso.sh
```

Creates a bootable ISO with all security features pre-configured.

**Note:** Requires ~20GB free space and 30-60 minutes.

---

#### `post_install_hardening.sh`
**Post-installation security hardening**

```bash
sudo bash scripts/post_install_hardening.sh
```

Applies additional security hardening after initial installation.

---

## Usage Examples

### Daily Health Check
```bash
# Quick status
sudo secureos-status

# Full health report
sudo secureos-health-check
```

### Before Major Changes
```bash
# Backup first
sudo bash scripts/backup.sh

# Make changes
sudo bash v5.0.0/install.sh

# Test
sudo bash scripts/test-suite.sh
```

### Weekly Maintenance
```bash
#!/bin/bash
# weekly-maintenance.sh

# Update system
sudo bash scripts/update.sh

# Health check
sudo bash scripts/health-check.sh

# Backup
sudo bash scripts/backup.sh
```

### Add to crontab:
```bash
# Weekly on Sunday at 2 AM
0 2 * * 0 /path/to/SecureOS/scripts/weekly-maintenance.sh
```

---

## Script Permissions

All scripts should be executable:

```bash
chmod +x scripts/*.sh
```

---

## Troubleshooting

### Script Fails to Run
```bash
# Check permissions
ls -l scripts/

# Make executable
chmod +x scripts/script-name.sh

# Check for syntax errors
bash -n scripts/script-name.sh
```

### Missing Dependencies
```bash
# Install base tools
sudo apt-get install -y git python3 sqlite3

# Install Python packages
pip3 install -r requirements.txt
```

---

## Contributing

When adding new scripts:
1. Use bash shebang: `#!/bin/bash`
2. Enable strict mode: `set -e`
3. Add descriptive header comment
4. Include usage examples
5. Update this README
6. Add to test suite

---

## Script Standards

```bash
#!/bin/bash
#
# Script Name - Brief Description
# Detailed description of what the script does
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check root if needed
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Main logic
echo -e "${BLUE}Script Name${NC}"
# ... implementation
```

---

## Security Notes

- Always backup before running destructive operations
- Review scripts before execution
- Scripts should be idempotent (safe to run multiple times)
- Validate inputs
- Check prerequisites
- Provide clear error messages
- Log important actions

---

**SecureOS Scripts**  
**Barrer Software** © 2025
