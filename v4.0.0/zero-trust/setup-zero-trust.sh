#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# Zero Trust Network Architecture Implementation
#
set -e

echo "========================================"
echo "SecureOS v4.0.0 - Zero Trust Setup"
echo "Copyright © 2025 Barrer Software"
echo "========================================"

# Zero Trust Network Architecture (ZTNA) principles:
# 1. Never trust, always verify
# 2. Assume breach
# 3. Verify explicitly
# 4. Use least privilege access
# 5. Microsegmentation

install_zero_trust() {
    echo "[*] Installing Zero Trust components..."
    
    # Install Open Policy Agent (OPA) for policy enforcement
    curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
    chmod +x /usr/local/bin/opa
    
    # Install StrongSwan for identity-based VPN
    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins
    
    # Install Teleport for zero-trust access
    cd /tmp
    curl -O https://cdn.teleport.dev/teleport-v13.4.3-linux-amd64-bin.tar.gz
    tar -xzf teleport-v13.4.3-linux-amd64-bin.tar.gz
    cd teleport
    ./install
    
    # Install OSQuery for endpoint visibility
    wget https://pkg.osquery.io/deb/osquery_5.10.2-1.linux_amd64.deb
    dpkg -i osquery_5.10.2-1.linux_amd64.deb || apt-get install -f -y
    
    # Install Cilium for network segmentation (if Kubernetes is present)
    if command -v kubectl &> /dev/null; then
        curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
        tar xzvf cilium-linux-amd64.tar.gz
        mv cilium /usr/local/bin/
    fi
    
    echo "[✓] Zero Trust components installed"
}

configure_opa_policies() {
    echo "[*] Configuring OPA policies..."
    
    mkdir -p /etc/opa/policies
    
    # Create default deny policy
    cat > /etc/opa/policies/default.rego << 'EOF'
package secureos.authz

import future.keywords.if
import future.keywords.in

# Default deny
default allow = false

# Allow if user is authenticated and authorized
allow if {
    input.authenticated == true
    input.user.roles[_] == input.required_role
    verify_device_health(input.device)
}

# Device health verification
verify_device_health(device) if {
    device.os_updated == true
    device.av_updated == true
    device.encrypted == true
    not device.jailbroken
}

# Deny if any security violations
deny["Device not compliant"] if {
    not verify_device_health(input.device)
}

deny["User not authenticated"] if {
    not input.authenticated
}
EOF

    # Create network policy
    cat > /etc/opa/policies/network.rego << 'EOF'
package secureos.network

import future.keywords.if

# Microsegmentation rules
allow_connection if {
    input.source.verified == true
    input.destination.service in allowed_services
    verify_encryption(input.protocol)
}

allowed_services = ["web", "api", "database"]

verify_encryption(protocol) if {
    protocol in ["https", "ssh", "wireguard", "ipsec"]
}
EOF

    echo "[✓] OPA policies configured"
}

setup_device_trust() {
    echo "[*] Setting up device trust framework..."
    
    mkdir -p /etc/secureos/device-trust
    
    # Install device attestation
    cat > /etc/secureos/device-trust/verify.sh << 'EOF'
#!/bin/bash
# Device Trust Verification Script
# Copyright © 2025 Barrer Software

verify_device() {
    local device_id=$1
    local result=0
    
    # Check OS updates
    if ! apt-get update -qq && apt list --upgradable 2>/dev/null | grep -q upgradable; then
        echo "WARN: OS updates available"
        result=1
    fi
    
    # Check antivirus status
    if systemctl is-active --quiet clamav-freshclam; then
        echo "OK: Antivirus active"
    else
        echo "FAIL: Antivirus not active"
        result=2
    fi
    
    # Check disk encryption
    if cryptsetup status /dev/mapper/crypt-root &>/dev/null; then
        echo "OK: Disk encrypted"
    else
        echo "WARN: Disk not encrypted"
        result=1
    fi
    
    # Check firewall
    if ufw status | grep -q "Status: active"; then
        echo "OK: Firewall active"
    else
        echo "FAIL: Firewall not active"
        result=2
    fi
    
    # Check for rootkits
    if command -v rkhunter &>/dev/null; then
        rkhunter --check --skip-keypress --report-warnings-only
    fi
    
    return $result
}

verify_device "$@"
EOF
    chmod +x /etc/secureos/device-trust/verify.sh
    
    echo "[✓] Device trust framework configured"
}

configure_microsegmentation() {
    echo "[*] Configuring network microsegmentation..."
    
    # Create separate network zones
    mkdir -p /etc/secureos/network-zones
    
    cat > /etc/secureos/network-zones/rules.conf << 'EOF'
# SecureOS Network Microsegmentation Rules
# Copyright © 2025 Barrer Software

# Define zones
[zones]
dmz = 10.0.1.0/24
trusted = 10.0.2.0/24
restricted = 10.0.3.0/24
management = 10.0.4.0/24

# Zone-to-zone policies
[policies]
dmz -> trusted: deny
dmz -> restricted: deny
dmz -> management: deny
trusted -> dmz: allow(http,https)
trusted -> restricted: deny
trusted -> management: deny
restricted -> dmz: deny
restricted -> trusted: deny
restricted -> management: allow(ssh)
management -> *: allow(ssh,monitoring)
EOF

    # Configure nftables for microsegmentation
    cat > /etc/nftables-zones.conf << 'EOF'
#!/usr/sbin/nft -f
# SecureOS Microsegmentation with nftables
# Copyright © 2025 Barrer Software

flush ruleset

table inet filter {
    set dmz_hosts {
        type ipv4_addr
        flags interval
        elements = { 10.0.1.0/24 }
    }
    
    set trusted_hosts {
        type ipv4_addr
        flags interval
        elements = { 10.0.2.0/24 }
    }
    
    set restricted_hosts {
        type ipv4_addr
        flags interval
        elements = { 10.0.3.0/24 }
    }
    
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established connections
        ct state established,related accept
        
        # Allow loopback
        iif lo accept
        
        # Zone-based filtering
        ip saddr @dmz_hosts jump dmz_input
        ip saddr @trusted_hosts jump trusted_input
        ip saddr @restricted_hosts jump restricted_input
    }
    
    chain dmz_input {
        # DMZ can only receive responses
        ct state established,related accept
        drop
    }
    
    chain trusted_input {
        # Trusted zone has normal access
        tcp dport { 22, 80, 443 } accept
        udp dport { 53, 123 } accept
    }
    
    chain restricted_input {
        # Restricted zone minimal access
        tcp dport 22 accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        
        # Inter-zone forwarding rules
        ip saddr @trusted_hosts ip daddr @dmz_hosts tcp dport { 80, 443 } accept
        ip saddr @restricted_hosts ip daddr @dmz_hosts drop
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
    
    echo "[✓] Microsegmentation configured"
}

setup_identity_aware_proxy() {
    echo "[*] Setting up Identity-Aware Proxy..."
    
    # Install oauth2-proxy for identity-aware access
    cd /tmp
    wget https://github.com/oauth2-proxy/oauth2-proxy/releases/download/v7.5.1/oauth2-proxy-v7.5.1.linux-amd64.tar.gz
    tar -xzf oauth2-proxy-v7.5.1.linux-amd64.tar.gz
    mv oauth2-proxy-v7.5.1.linux-amd64/oauth2-proxy /usr/local/bin/
    
    mkdir -p /etc/oauth2-proxy
    cat > /etc/oauth2-proxy/oauth2-proxy.cfg << 'EOF'
# SecureOS Identity-Aware Proxy Configuration
# Copyright © 2025 Barrer Software

http_address = "0.0.0.0:4180"
upstreams = [
    "http://127.0.0.1:8080/"
]

# Provider config (example with GitHub)
provider = "github"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"

# Cookie settings
cookie_secure = true
cookie_httponly = true
cookie_samesite = "strict"

# Email domain restriction
email_domains = [
    "*"
]

# Session settings
cookie_secret = "CHANGE_THIS_SECRET"
cookie_expire = "168h"

# TLS
ssl_upstream_insecure_skip_verify = false
EOF
    
    # Create systemd service
    cat > /etc/systemd/system/oauth2-proxy.service << 'EOF'
[Unit]
Description=OAuth2 Proxy for SecureOS
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/oauth2-proxy --config=/etc/oauth2-proxy/oauth2-proxy.cfg
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    echo "[✓] Identity-Aware Proxy installed (configure before enabling)"
}

configure_continuous_verification() {
    echo "[*] Setting up continuous verification..."
    
    # Install osquery for continuous monitoring
    cat > /etc/osquery/osquery.conf << 'EOF'
{
  "options": {
    "host_identifier": "hostname",
    "schedule_splay_percent": 10
  },
  "schedule": {
    "device_compliance": {
      "query": "SELECT * FROM system_info;",
      "interval": 300
    },
    "unauthorized_processes": {
      "query": "SELECT pid, name, path, cmdline FROM processes WHERE name NOT IN (SELECT DISTINCT name FROM authorized_processes);",
      "interval": 60
    },
    "file_integrity": {
      "query": "SELECT * FROM file WHERE path IN ('/etc/passwd', '/etc/shadow', '/etc/sudoers');",
      "interval": 300
    },
    "network_connections": {
      "query": "SELECT * FROM process_open_sockets WHERE remote_address != '';",
      "interval": 60
    }
  }
}
EOF
    
    # Create cron job for continuous trust verification
    cat > /etc/cron.d/secureos-trust << 'EOF'
# SecureOS Continuous Trust Verification
# Copyright © 2025 Barrer Software

*/5 * * * * root /etc/secureos/device-trust/verify.sh | logger -t secureos-trust
EOF
    
    echo "[✓] Continuous verification configured"
}

setup_audit_logging() {
    echo "[*] Setting up comprehensive audit logging..."
    
    # Enhanced auditd rules for Zero Trust
    cat >> /etc/audit/rules.d/zero-trust.rules << 'EOF'
# SecureOS Zero Trust Audit Rules
# Copyright © 2025 Barrer Software

# Monitor all authentication attempts
-w /var/log/auth.log -p wa -k auth_log
-w /var/log/faillog -p wa -k failed_login

# Monitor privileged operations
-a always,exit -F arch=b64 -S execve -F uid=0 -k privileged_exec

# Monitor network configuration changes
-w /etc/network/ -p wa -k network_config
-w /etc/netplan/ -p wa -k network_config

# Monitor firewall changes
-w /etc/ufw/ -p wa -k firewall
-w /etc/nftables.conf -p wa -k firewall

# Monitor policy changes
-w /etc/opa/ -p wa -k policy_change
-w /etc/secureos/ -p wa -k secureos_config

# Monitor file access in sensitive directories
-w /etc/ssh/ -p rwa -k ssh_config
-w /root/.ssh/ -p rwa -k root_ssh
-w /etc/ssl/ -p rwa -k ssl_certs
EOF
    
    augenrules --load 2>/dev/null || true
    
    echo "[✓] Audit logging enhanced"
}

create_documentation() {
    echo "[*] Creating Zero Trust documentation..."
    
    cat > /etc/secureos/zero-trust-README.md << 'EOF'
# SecureOS Zero Trust Architecture

Copyright © 2025 Barrer Software

## Overview

SecureOS v4.0.0 implements a comprehensive Zero Trust Network Architecture (ZTNA)
based on the principle: "Never trust, always verify."

## Components

### 1. Open Policy Agent (OPA)
- Policy-based authorization
- Device health verification
- Continuous compliance checking

### 2. Identity-Aware Proxy
- OAuth2-based authentication
- Per-request authorization
- Session management

### 3. Microsegmentation
- Network zones with strict boundaries
- Zone-to-zone policies
- nftables-based enforcement

### 4. Device Trust
- Continuous device verification
- Compliance checking
- Automated remediation

### 5. Continuous Monitoring
- OSQuery for endpoint visibility
- Real-time threat detection
- Audit logging

## Usage

### Verify Device Trust
```bash
/etc/secureos/device-trust/verify.sh
```

### Check OPA Policies
```bash
opa test /etc/opa/policies/
```

### View Audit Logs
```bash
ausearch -k auth_log
ausearch -k privileged_exec
```

### Monitor Compliance
```bash
osqueryi --config_path /etc/osquery/osquery.conf
```

## Network Zones

- **DMZ** (10.0.1.0/24): Public-facing services
- **Trusted** (10.0.2.0/24): Internal applications
- **Restricted** (10.0.3.0/24): High-security workloads
- **Management** (10.0.4.0/24): Administrative access

## Best Practices

1. **Always verify identity**: Use multi-factor authentication
2. **Assume breach**: Monitor all activity
3. **Least privilege**: Grant minimum required access
4. **Encrypt everything**: TLS for all communications
5. **Continuous monitoring**: Real-time threat detection

## Configuration

### OPA Policies
Edit: `/etc/opa/policies/*.rego`
Test: `opa test /etc/opa/policies/`

### Network Zones
Edit: `/etc/secureos/network-zones/rules.conf`
Apply: `nft -f /etc/nftables-zones.conf`

### Identity Proxy
Edit: `/etc/oauth2-proxy/oauth2-proxy.cfg`
Start: `systemctl start oauth2-proxy`

## Troubleshooting

### Check OPA status
```bash
systemctl status opa
```

### Verify device compliance
```bash
/etc/secureos/device-trust/verify.sh
```

### View audit events
```bash
ausearch -ts recent
```

### OSQuery interactive mode
```bash
osqueryi
```

## Support

- Documentation: https://ssfdre38.github.io/SecureOS
- GitHub: https://github.com/ssfdre38/SecureOS
- Issues: https://github.com/ssfdre38/SecureOS/issues

---

SecureOS v4.0.0 - Zero Trust Architecture
Barrer Software © 2025
EOF
    
    echo "[✓] Documentation created"
}

main() {
    echo ""
    echo "This script sets up Zero Trust Network Architecture for SecureOS"
    echo ""
    
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root"
        exit 1
    fi
    
    read -p "Install Zero Trust components? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_zero_trust
        configure_opa_policies
        setup_device_trust
        configure_microsegmentation
        setup_identity_aware_proxy
        configure_continuous_verification
        setup_audit_logging
        create_documentation
        
        echo ""
        echo "============================================"
        echo "✓ Zero Trust Architecture Setup Complete!"
        echo "============================================"
        echo ""
        echo "Next steps:"
        echo "1. Configure OAuth2 Proxy: /etc/oauth2-proxy/oauth2-proxy.cfg"
        echo "2. Review network zones: /etc/secureos/network-zones/rules.conf"
        echo "3. Apply nftables rules: nft -f /etc/nftables-zones.conf"
        echo "4. Start OPA: systemctl start opa"
        echo "5. Start OSQuery: systemctl start osqueryd"
        echo "6. Read documentation: /etc/secureos/zero-trust-README.md"
        echo ""
        echo "SecureOS v4.0.0 - Zero Trust Enabled"
        echo "Barrer Software © 2025"
    fi
}

main "$@"
