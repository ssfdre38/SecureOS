#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS Advanced Intrusion Detection System
# Real-time monitoring and automated response

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Installing advanced intrusion detection..."
apt-get update -qq
apt-get install -y \
    aide \
    tripwire \
    ossec-hids \
    suricata \
    snort \
    python3-scapy \
    python3-psutil

# Configure AIDE
log "Configuring AIDE file integrity monitoring..."
cat > /etc/aide/aide.conf << 'EOF'
# SecureOS AIDE Configuration

# Database paths
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
database_new=file:/var/lib/aide/aide.db.new
gzip_dbout=yes

# Rules
All = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha512
Logs = p+i+n+u+g+acl+selinux
ConfFiles = p+i+n+u+g+acl+selinux+sha512

# Directories to monitor
/etc ConfFiles
/bin All
/sbin All
/lib All
/lib64 All
/usr/bin All
/usr/sbin All
/usr/lib All
/usr/lib64 All
/boot All

# Exclude volatile directories
!/var/log
!/var/cache
!/var/tmp
!/tmp
!/proc
!/sys
!/dev
!/run
EOF

# Initialize AIDE database
log "Initializing AIDE database (this may take a while)..."
aideinit -y -f || true

# Create automated response system
log "Creating automated intrusion response system..."
cat > /usr/local/bin/secureos-ids-response << 'EOF'
#!/usr/bin/env python3
"""
SecureOS Intrusion Detection and Response System
Monitors for threats and automatically responds
"""

import os
import sys
import time
import subprocess
import json
from datetime import datetime
from pathlib import Path

class IDSResponse:
    def __init__(self):
        self.log_file = '/var/log/secureos-ids.log'
        self.banned_ips = set()
        self.alert_threshold = 5
        
    def log(self, message, level='INFO'):
        timestamp = datetime.now().isoformat()
        log_msg = f"[{timestamp}] {level}: {message}"
        print(log_msg)
        
        with open(self.log_file, 'a') as f:
            f.write(log_msg + '\n')
    
    def block_ip(self, ip_address):
        """Block an IP address using UFW"""
        if ip_address in self.banned_ips:
            return
        
        try:
            subprocess.run(['ufw', 'deny', 'from', ip_address], 
                         check=True, capture_output=True)
            self.banned_ips.add(ip_address)
            self.log(f"Blocked IP address: {ip_address}", 'ALERT')
            
            # Send notification
            self.send_notification(f"Blocked suspicious IP: {ip_address}")
        except subprocess.CalledProcessError as e:
            self.log(f"Failed to block IP {ip_address}: {e}", 'ERROR')
    
    def unblock_ip(self, ip_address):
        """Unblock an IP address"""
        try:
            subprocess.run(['ufw', 'delete', 'deny', 'from', ip_address],
                         check=True, capture_output=True)
            self.banned_ips.discard(ip_address)
            self.log(f"Unblocked IP address: {ip_address}", 'INFO')
        except subprocess.CalledProcessError as e:
            self.log(f"Failed to unblock IP {ip_address}: {e}", 'ERROR')
    
    def send_notification(self, message):
        """Send security notification"""
        # Log to syslog
        subprocess.run(['logger', '-t', 'SecureOS-IDS', message])
        
        # Could integrate with email, SMS, etc.
        self.log(f"Notification: {message}", 'NOTIFY')
    
    def monitor_auth_logs(self):
        """Monitor authentication logs for suspicious activity"""
        auth_log = '/var/log/auth.log'
        failed_attempts = {}
        
        if not os.path.exists(auth_log):
            self.log("Auth log not found", 'WARNING')
            return
        
        self.log("Monitoring authentication logs...")
        
        # Watch for failed login attempts
        with open(auth_log, 'r') as f:
            for line in f:
                if 'Failed password' in line:
                    # Extract IP address
                    parts = line.split()
                    if 'from' in parts:
                        idx = parts.index('from') + 1
                        if idx < len(parts):
                            ip = parts[idx]
                            failed_attempts[ip] = failed_attempts.get(ip, 0) + 1
                            
                            if failed_attempts[ip] >= self.alert_threshold:
                                self.log(f"Multiple failed login attempts from {ip}", 'ALERT')
                                self.block_ip(ip)
    
    def check_file_integrity(self):
        """Check file integrity with AIDE"""
        self.log("Running AIDE integrity check...")
        try:
            result = subprocess.run(['aide', '--check'], 
                                  capture_output=True, text=True)
            
            if 'changed' in result.stdout.lower() or 'added' in result.stdout.lower():
                self.log("File integrity violations detected!", 'ALERT')
                self.send_notification("AIDE detected file system changes")
                
                # Log changes
                with open('/var/log/aide-changes.log', 'a') as f:
                    f.write(f"\n=== {datetime.now()} ===\n")
                    f.write(result.stdout)
                    
        except Exception as e:
            self.log(f"AIDE check failed: {e}", 'ERROR')
    
    def scan_open_ports(self):
        """Scan for unexpected open ports"""
        self.log("Scanning for open ports...")
        try:
            result = subprocess.run(['ss', '-tulpn'], 
                                  capture_output=True, text=True, check=True)
            
            # Define allowed ports (adjust as needed)
            allowed_ports = {22, 80, 443}
            
            for line in result.stdout.split('\n'):
                if 'LISTEN' in line:
                    parts = line.split()
                    for part in parts:
                        if ':' in part:
                            try:
                                port = int(part.split(':')[-1])
                                if port not in allowed_ports and port > 1024:
                                    self.log(f"Unexpected port open: {port}", 'WARNING')
                            except:
                                pass
        except Exception as e:
            self.log(f"Port scan failed: {e}", 'ERROR')
    
    def run(self):
        """Main monitoring loop"""
        self.log("SecureOS IDS Response System started", 'INFO')
        
        while True:
            try:
                self.monitor_auth_logs()
                self.scan_open_ports()
                
                # Run AIDE check every hour
                if int(time.time()) % 3600 < 60:
                    self.check_file_integrity()
                
                time.sleep(60)  # Check every minute
                
            except KeyboardInterrupt:
                self.log("IDS Response System stopping...", 'INFO')
                break
            except Exception as e:
                self.log(f"Error in monitoring loop: {e}", 'ERROR')
                time.sleep(60)

if __name__ == '__main__':
    if os.geteuid() != 0:
        print("Error: Must run as root")
        sys.exit(1)
    
    ids = IDSResponse()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == 'check':
            ids.monitor_auth_logs()
            ids.check_file_integrity()
            ids.scan_open_ports()
        elif sys.argv[1] == 'unblock' and len(sys.argv) > 2:
            ids.unblock_ip(sys.argv[2])
    else:
        ids.run()
EOF
chmod +x /usr/local/bin/secureos-ids-response

# Create systemd service
cat > /etc/systemd/system/secureos-ids.service << 'EOF'
[Unit]
Description=SecureOS Intrusion Detection and Response
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/secureos-ids-response
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable secureos-ids.service

success "Advanced intrusion detection configured!"
echo ""
log "Features enabled:"
echo "  ✓ AIDE file integrity monitoring"
echo "  ✓ Real-time authentication monitoring"
echo "  ✓ Automated IP blocking"
echo "  ✓ Port scan detection"
echo "  ✓ Automated threat response"
echo ""
log "Control IDS:"
echo "  sudo systemctl start secureos-ids    # Start monitoring"
echo "  sudo systemctl status secureos-ids   # Check status"
echo "  sudo tail -f /var/log/secureos-ids.log  # View logs"
echo ""
log "Manual checks:"
echo "  sudo secureos-ids-response check    # Run manual check"
echo "  sudo aide --check                   # Check file integrity"
