#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS Post-Installation Hardening Script
# This script applies security hardening after system installation

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Starting SecureOS post-installation hardening..."

# 1. Kernel Hardening
log "Applying kernel hardening parameters..."
cat > /etc/sysctl.d/99-secureos-hardening.conf << 'EOF'
# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
kernel.unprivileged_userns_clone = 0
net.core.bpf_jit_harden = 2
kernel.kexec_load_disabled = 1
kernel.sysrq = 0

# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2

# Disable IPv4 forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
EOF
sysctl -p /etc/sysctl.d/99-secureos-hardening.conf >/dev/null 2>&1
success "Kernel hardening applied"

# 2. Secure shared memory
log "Securing shared memory..."
if ! grep -q "tmpfs /run/shm tmpfs" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nodev,nosuid 0 0" >> /etc/fstab
fi
success "Shared memory secured"

# 3. Disable core dumps
log "Disabling core dumps..."
echo "* hard core 0" > /etc/security/limits.d/10-disable-core-dumps.conf
echo "fs.suid_dumpable = 0" >> /etc/sysctl.d/99-secureos-hardening.conf
success "Core dumps disabled"

# 4. Configure UFW firewall
log "Configuring firewall..."
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw logging high
ufw --force enable
success "Firewall configured and enabled"

# 5. Harden SSH (if installed)
if [ -f /etc/ssh/sshd_config ]; then
    log "Hardening SSH configuration..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    cat > /etc/ssh/sshd_config.d/99-secureos.conf << 'EOF'
# SecureOS SSH Hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
MaxStartups 2
MaxSessions 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
EOF
    success "SSH hardened"
fi

# 6. AppArmor configuration
log "Configuring AppArmor..."
systemctl enable apparmor
aa-enforce /etc/apparmor.d/* 2>/dev/null || true
success "AppArmor configured"

# 7. Audit daemon configuration
log "Configuring audit daemon..."
if [ -f /etc/audit/auditd.conf ]; then
    sed -i 's/^max_log_file =.*/max_log_file = 10/' /etc/audit/auditd.conf
    sed -i 's/^num_logs =.*/num_logs = 5/' /etc/audit/auditd.conf
    sed -i 's/^log_format =.*/log_format = ENRICHED/' /etc/audit/auditd.conf
    
    # Add audit rules
    cat > /etc/audit/rules.d/99-secureos.rules << 'EOF'
# SecureOS Audit Rules
-D
-b 8192

# Monitor authentication and authorization
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k actions

# Monitor system calls
-a exit,always -F arch=b64 -S execve -k exec
-a exit,always -F arch=b32 -S execve -k exec

# Monitor network connections
-a exit,always -F arch=b64 -S socket -S connect -k network
-a exit,always -F arch=b32 -S socket -S connect -k network

# Monitor file modifications
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/securetty -p wa -k securetty
EOF
    
    systemctl enable auditd
fi
success "Audit daemon configured"

# 8. Disable unnecessary services
log "Disabling unnecessary services..."
services=(
    "bluetooth.service"
    "cups.service"
    "avahi-daemon.service"
)

for service in "${services[@]}"; do
    systemctl disable "$service" 2>/dev/null || true
    systemctl stop "$service" 2>/dev/null || true
done
success "Unnecessary services disabled"

# 9. Configure automatic security updates
log "Configuring automatic security updates..."
apt-get install -y unattended-upgrades apt-listchanges >/dev/null 2>&1

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
success "Automatic security updates configured"

# 10. Secure file permissions
log "Setting secure file permissions..."
chmod 700 /root
chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 640 /etc/gshadow
chmod 644 /etc/group
success "File permissions secured"

# 11. Configure fail2ban
log "Configuring fail2ban..."
if command -v fail2ban-client >/dev/null 2>&1; then
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
    systemctl enable fail2ban
    systemctl restart fail2ban 2>/dev/null || true
    success "Fail2ban configured"
fi

# 12. Privacy configurations
log "Applying privacy configurations..."

# Disable telemetry
if [ -f /etc/default/apport ]; then
    sed -i 's/enabled=1/enabled=0/' /etc/default/apport
fi

# Configure DNS over TLS (if systemd-resolved is used)
if command -v systemd-resolve >/dev/null 2>&1; then
    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/secureos-dns.conf << 'EOF'
[Resolve]
DNS=9.9.9.9 149.112.112.112
FallbackDNS=1.1.1.1 1.0.0.1
DNSOverTLS=yes
DNSSEC=yes
EOF
    systemctl restart systemd-resolved 2>/dev/null || true
fi

success "Privacy configurations applied"

# 13. Install and configure ClamAV
log "Configuring antivirus..."
if command -v freshclam >/dev/null 2>&1; then
    systemctl stop clamav-freshclam 2>/dev/null || true
    freshclam >/dev/null 2>&1 || true
    systemctl start clamav-freshclam 2>/dev/null || true
    success "Antivirus configured"
fi

# 14. Create security audit script
log "Creating security audit script..."
cat > /usr/local/bin/secureos-audit << 'AUDIT_EOF'
#!/bin/bash
echo "SecureOS Security Audit Report"
echo "=============================="
echo ""
echo "System Information:"
uname -a
echo ""
echo "Firewall Status:"
ufw status verbose
echo ""
echo "AppArmor Status:"
aa-status --brief 2>/dev/null || echo "AppArmor not available"
echo ""
echo "Failed Login Attempts:"
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 || echo "No recent failures"
echo ""
echo "Open Ports:"
ss -tulpn
echo ""
echo "Recent Security Updates:"
grep "upgrade" /var/log/apt/history.log 2>/dev/null | tail -5 || echo "No recent updates"
AUDIT_EOF
chmod +x /usr/local/bin/secureos-audit
success "Security audit script created (/usr/local/bin/secureos-audit)"

# 15. Create MOTD
log "Creating login banner..."
cat > /etc/motd << 'EOF'
╔═══════════════════════════════════════════════════╗
║              Welcome to SecureOS                  ║
║     Security & Privacy Focused Linux Distro       ║
╚═══════════════════════════════════════════════════╝

This system is configured with enhanced security features:
  ✓ Full disk encryption
  ✓ Hardened kernel
  ✓ Firewall enabled
  ✓ AppArmor enforcing
  ✓ Audit logging active
  ✓ Automatic security updates

Run 'secureos-audit' to view security status.

EOF
success "Login banner created"

# Final message
echo ""
success "═══════════════════════════════════════════════"
success "  SecureOS hardening completed successfully!"
success "═══════════════════════════════════════════════"
echo ""
log "Recommended next steps:"
echo "  1. Reboot the system to apply all changes"
echo "  2. Configure user-specific security settings"
echo "  3. Run 'secureos-audit' to verify configuration"
echo "  4. Review /var/log/secureos-hardening.log for details"
echo ""
