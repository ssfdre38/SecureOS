#!/bin/bash
#
# SecureOS Quick Setup - One-command installation
# Sets up a complete secure system in minutes
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
   ____                            ___  ____  
  / ___|  ___  ___ _   _ _ __ ___ / _ \/ ___| 
  \___ \ / _ \/ __| | | | '__/ _ \ | | \___ \ 
   ___) |  __/ (__| |_| | | |  __/ |_| |___) |
  |____/ \___|\___|\__,_|_|  \___|\___/|____/ 
                                              
  Security & Privacy Enhanced Linux Distribution
  Quick Setup - One Command Installation
  Version 5.0.0 "Quantum Shield"
  
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Please run: sudo bash $0"
   exit 1
fi

# Detect environment
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SECUREOS_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}SecureOS Quick Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "This will set up a complete secure system with:"
echo "  • Base security hardening"
echo "  • Firewall configuration"
echo "  • Intrusion detection"
echo "  • Privacy enhancements"
echo "  • v5.0.0 AI security features (optional)"
echo ""
read -p "Continue with quick setup? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

echo ""
echo -e "${YELLOW}[1/8] Updating system...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

echo -e "${YELLOW}[2/8] Installing base security tools...${NC}"
apt-get install -y -qq \
    ufw \
    fail2ban \
    apparmor \
    apparmor-utils \
    auditd \
    rkhunter \
    chkrootkit \
    aide \
    clamav \
    clamav-daemon \
    unattended-upgrades \
    apt-listchanges \
    needrestart

echo -e "${YELLOW}[3/8] Configuring firewall...${NC}"
# Enable UFW with default deny
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

echo -e "${YELLOW}[4/8] Hardening kernel parameters...${NC}"
cat > /etc/sysctl.d/99-secureos-hardening.conf << 'SYSCTL'
# SecureOS Security Hardening

# IP Forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# ICMP echo requests
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# TCP hardening
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 0

# Kernel security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
fs.suid_dumpable = 0

# IPv6 privacy
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
SYSCTL

sysctl -p /etc/sysctl.d/99-secureos-hardening.conf >/dev/null 2>&1

echo -e "${YELLOW}[5/8] Configuring Fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban

echo -e "${YELLOW}[6/8] Setting up automatic updates...${NC}"
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UNATTENDED'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
UNATTENDED

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTOUPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTOUPGRADES

echo -e "${YELLOW}[7/8] Updating virus definitions...${NC}"
freshclam --quiet || true

echo -e "${YELLOW}[8/8] Creating system utilities...${NC}"

# Create secureos-status command
cat > /usr/local/bin/secureos-status << 'STATUS'
#!/bin/bash
# Quick security status check

echo "═══════════════════════════════════════"
echo "SecureOS Security Status"
echo "═══════════════════════════════════════"
echo ""

# Firewall
ufw status | head -3

echo ""
# Updates
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
echo "Available updates: $UPDATES"

echo ""
# Services
echo "Security Services:"
for svc in ufw fail2ban apparmor auditd; do
    if systemctl is-active --quiet $svc 2>/dev/null; then
        echo "  ✓ $svc"
    else
        echo "  ✗ $svc"
    fi
done

echo ""
# Last scan
if [ -f /var/log/rkhunter.log ]; then
    echo "Last rootkit scan: $(stat -c %y /var/log/rkhunter.log | cut -d' ' -f1)"
fi

echo ""
echo "For detailed report: sudo secureos-health-check"
STATUS

chmod +x /usr/local/bin/secureos-status

# Link health check
if [ -f "$SECUREOS_ROOT/scripts/health-check.sh" ]; then
    chmod +x "$SECUREOS_ROOT/scripts/health-check.sh"
    ln -sf "$SECUREOS_ROOT/scripts/health-check.sh" /usr/local/bin/secureos-health-check
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Quick Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Base security features installed:"
echo "  ✓ Firewall (UFW) enabled"
echo "  ✓ Intrusion detection (Fail2ban) active"
echo "  ✓ Kernel hardened"
echo "  ✓ Automatic security updates enabled"
echo "  ✓ Antivirus (ClamAV) installed"
echo "  ✓ Rootkit detection tools installed"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "1. Check system status:"
echo "   sudo secureos-status"
echo ""
echo "2. Run full health check:"
echo "   sudo secureos-health-check"
echo ""
echo "3. Install v5.0.0 AI features:"
echo "   cd $SECUREOS_ROOT"
echo "   sudo bash v5.0.0/install.sh"
echo ""
echo "4. Run initial security scan:"
echo "   sudo rkhunter --check --skip-keypress"
echo ""
echo "5. Configure firewall rules for your services:"
echo "   sudo ufw allow <port>/tcp"
echo ""
echo -e "${YELLOW}⚠ Important: Reboot recommended to apply all security settings${NC}"
echo ""
read -p "Reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
fi
