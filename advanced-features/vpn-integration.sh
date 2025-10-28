#!/bin/bash
# SecureOS VPN Integration
# Supports WireGuard and OpenVPN with secure defaults

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Installing VPN packages..."
apt-get update -qq
apt-get install -y wireguard wireguard-tools openvpn network-manager-openvpn \
    network-manager-openvpn-gnome resolvconf

# WireGuard Configuration
log "Configuring WireGuard..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

cat > /etc/wireguard/wg0.conf.template << 'EOF'
[Interface]
# Client private key (generate with: wg genkey)
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 9.9.9.9, 149.112.112.112

# Prevent DNS leaks
PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT

[Peer]
# Server public key
PublicKey = YOUR_SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

success "WireGuard template created at /etc/wireguard/wg0.conf.template"

# OpenVPN hardening
log "Configuring OpenVPN security..."
mkdir -p /etc/openvpn/client

cat > /etc/openvpn/client-hardening.conf << 'EOF'
# OpenVPN Client Security Hardening
# Include this in your .ovpn config with: config client-hardening.conf

# Cryptographic hardening
cipher AES-256-GCM
auth SHA512
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384

# Security
remote-cert-tls server
verify-x509-name server_name name
ns-cert-type server

# DNS leak protection
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf

# IPv6 leak protection
pull-filter ignore "ifconfig-ipv6"
pull-filter ignore "route-ipv6"

# Kill switch (drop all traffic if VPN disconnects)
route-up /etc/openvpn/killswitch-up.sh
route-pre-down /etc/openvpn/killswitch-down.sh
EOF

# VPN Kill Switch
log "Creating VPN kill switch..."
cat > /etc/openvpn/killswitch-up.sh << 'EOF'
#!/bin/bash
# Block all traffic except through VPN
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow VPN interface
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT

# Allow VPN connection
iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -p udp --sport 1194 -j ACCEPT

# Allow local network (adjust as needed)
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
EOF

cat > /etc/openvpn/killswitch-down.sh << 'EOF'
#!/bin/bash
# Restore firewall when VPN disconnects
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
EOF

chmod +x /etc/openvpn/killswitch-*.sh

# DNS leak prevention
log "Configuring DNS leak prevention..."
cat > /etc/openvpn/update-resolv-conf << 'EOF'
#!/bin/bash
case "$script_type" in
    up)
        echo "nameserver 9.9.9.9" > /etc/resolv.conf
        echo "nameserver 149.112.112.112" >> /etc/resolv.conf
        ;;
    down)
        systemctl restart systemd-resolved
        ;;
esac
EOF
chmod +x /etc/openvpn/update-resolv-conf

# VPN connection helper script
log "Creating VPN helper script..."
cat > /usr/local/bin/secureos-vpn << 'EOF'
#!/bin/bash
# SecureOS VPN Manager

show_help() {
    echo "SecureOS VPN Manager"
    echo ""
    echo "Usage: secureos-vpn <command> [options]"
    echo ""
    echo "WireGuard Commands:"
    echo "  wg-generate       Generate WireGuard keypair"
    echo "  wg-connect        Connect WireGuard VPN"
    echo "  wg-disconnect     Disconnect WireGuard VPN"
    echo "  wg-status         Show WireGuard status"
    echo ""
    echo "OpenVPN Commands:"
    echo "  ovpn-connect      Connect OpenVPN"
    echo "  ovpn-disconnect   Disconnect OpenVPN"
    echo "  ovpn-status       Show OpenVPN status"
    echo ""
    echo "General:"
    echo "  check-leak        Check for DNS/IP leaks"
    echo "  status            Show all VPN status"
}

wg_generate() {
    echo "Generating WireGuard keypair..."
    PRIVATE=$(wg genkey)
    PUBLIC=$(echo "$PRIVATE" | wg pubkey)
    echo ""
    echo "Private Key: $PRIVATE"
    echo "Public Key:  $PUBLIC"
    echo ""
    echo "Add private key to /etc/wireguard/wg0.conf"
    echo "Share public key with VPN server admin"
}

wg_connect() {
    if [ ! -f /etc/wireguard/wg0.conf ]; then
        echo "Error: /etc/wireguard/wg0.conf not found"
        echo "Copy template: cp /etc/wireguard/wg0.conf.template /etc/wireguard/wg0.conf"
        echo "Then edit with your VPN credentials"
        exit 1
    fi
    wg-quick up wg0
    echo "WireGuard VPN connected"
}

wg_disconnect() {
    wg-quick down wg0
    echo "WireGuard VPN disconnected"
}

check_leak() {
    echo "Checking for DNS/IP leaks..."
    echo ""
    echo "Your IP address:"
    curl -s https://ifconfig.me
    echo ""
    echo ""
    echo "DNS servers:"
    cat /etc/resolv.conf | grep nameserver
    echo ""
    echo "If VPN is active, IP should be VPN server's IP"
    echo "DNS should be VPN's DNS servers (not ISP)"
}

case "$1" in
    wg-generate) wg_generate ;;
    wg-connect) wg_connect ;;
    wg-disconnect) wg_disconnect ;;
    wg-status) wg show ;;
    ovpn-connect) sudo openvpn --config "${2:-/etc/openvpn/client.ovpn}" ;;
    ovpn-disconnect) sudo killall openvpn ;;
    ovpn-status) systemctl status openvpn@client ;;
    check-leak) check_leak ;;
    status) 
        echo "WireGuard:"
        wg show 2>/dev/null || echo "  Not connected"
        echo ""
        echo "OpenVPN:"
        systemctl is-active openvpn@client 2>/dev/null || echo "  Not connected"
        ;;
    *) show_help ;;
esac
EOF
chmod +x /usr/local/bin/secureos-vpn

# Enable IP forwarding (optional, for VPN server)
cat >> /etc/sysctl.d/99-secureos-vpn.conf << EOF
# VPN client hardening
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

sysctl -p /etc/sysctl.d/99-secureos-vpn.conf

success "VPN integration complete!"
echo ""
log "Next steps:"
echo "  1. For WireGuard: secureos-vpn wg-generate"
echo "  2. Edit /etc/wireguard/wg0.conf with your VPN settings"
echo "  3. Connect: secureos-vpn wg-connect"
echo "  4. Check for leaks: secureos-vpn check-leak"
echo ""
log "For OpenVPN:"
echo "  1. Place your .ovpn file in /etc/openvpn/client.ovpn"
echo "  2. Connect: secureos-vpn ovpn-connect"
