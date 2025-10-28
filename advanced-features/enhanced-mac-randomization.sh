#!/bin/bash
# SecureOS Enhanced MAC Randomization
# Advanced privacy protection through MAC address randomization

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

log "Installing MAC randomization tools..."
apt-get update -qq
apt-get install -y macchanger network-manager

# Configure NetworkManager MAC randomization
log "Configuring NetworkManager MAC randomization..."
cat > /etc/NetworkManager/conf.d/99-random-mac.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
# Randomize MAC for WiFi
wifi.cloned-mac-address=random
# Randomize MAC for Ethernet
ethernet.cloned-mac-address=random

[connection-mac-randomization]
# Generate different MAC for each connection
wifi.generate-mac-address-mask=FE:FF:FF:00:00:00
EOF

# Create systemd service for MAC randomization on boot
log "Creating MAC randomization service..."
cat > /etc/systemd/system/mac-randomize.service << 'EOF'
[Unit]
Description=Randomize MAC addresses
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/secureos-mac-randomize
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create MAC randomization script
cat > /usr/local/bin/secureos-mac-randomize << 'EOF'
#!/bin/bash
# Randomize MAC addresses for all interfaces

INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)

for iface in $INTERFACES; do
    # Skip virtual interfaces
    if [[ ! $iface =~ ^(docker|veth|br-|virbr) ]]; then
        echo "Randomizing MAC for $iface..."
        ip link set dev "$iface" down
        macchanger -r "$iface" 2>/dev/null || true
        ip link set dev "$iface" up
    fi
done
EOF
chmod +x /usr/local/bin/secureos-mac-randomize

# Create MAC management tool
cat > /usr/local/bin/secureos-mac << 'EOF'
#!/bin/bash
# SecureOS MAC Address Manager

show_help() {
    echo "SecureOS MAC Address Manager"
    echo ""
    echo "Usage: secureos-mac <command> [interface]"
    echo ""
    echo "Commands:"
    echo "  show [iface]      Show current MAC address"
    echo "  random [iface]    Randomize MAC address"
    echo "  restore [iface]   Restore original MAC address"
    echo "  permanent         Show permanent MAC address"
    echo "  list              List all network interfaces"
    echo ""
    echo "Examples:"
    echo "  secureos-mac show wlan0"
    echo "  secureos-mac random eth0"
    echo "  secureos-mac list"
}

show_mac() {
    if [ -z "$1" ]; then
        ip link show | grep -E "^[0-9]+:" | awk '{print $2, $0}' | grep -oP '\w+(?=:)|\w{2}:\w{2}:\w{2}:\w{2}:\w{2}:\w{2}'
    else
        ip link show "$1" | grep -oP '(?<=link/ether )\w{2}:\w{2}:\w{2}:\w{2}:\w{2}:\w{2}'
    fi
}

random_mac() {
    local iface="$1"
    if [ -z "$iface" ]; then
        echo "Error: Interface required"
        exit 1
    fi
    
    echo "Randomizing MAC for $iface..."
    sudo ip link set dev "$iface" down
    sudo macchanger -r "$iface"
    sudo ip link set dev "$iface" up
    echo "New MAC: $(show_mac $iface)"
}

restore_mac() {
    local iface="$1"
    if [ -z "$iface" ]; then
        echo "Error: Interface required"
        exit 1
    fi
    
    echo "Restoring permanent MAC for $iface..."
    sudo ip link set dev "$iface" down
    sudo macchanger -p "$iface"
    sudo ip link set dev "$iface" up
    echo "Restored MAC: $(show_mac $iface)"
}

permanent_mac() {
    local iface="$1"
    if [ -z "$iface" ]; then
        echo "Error: Interface required"
        exit 1
    fi
    
    macchanger -s "$iface" | grep -i permanent | awk '{print $3}'
}

list_interfaces() {
    echo "Network Interfaces:"
    ip -o link show | awk -F': ' '{print "  " $2}' | grep -v lo
}

case "$1" in
    show) show_mac "$2" ;;
    random) random_mac "$2" ;;
    restore) restore_mac "$2" ;;
    permanent) permanent_mac "$2" ;;
    list) list_interfaces ;;
    *) show_help ;;
esac
EOF
chmod +x /usr/local/bin/secureos-mac

# Enable service
systemctl daemon-reload
systemctl enable mac-randomize.service

# Restart NetworkManager to apply changes
systemctl restart NetworkManager

success "Enhanced MAC randomization configured!"
echo ""
log "Features enabled:"
echo "  ✓ Automatic MAC randomization on boot"
echo "  ✓ Different MAC per WiFi network"
echo "  ✓ NetworkManager integration"
echo ""
log "Usage:"
echo "  secureos-mac list              # List interfaces"
echo "  secureos-mac show wlan0        # Show current MAC"
echo "  secureos-mac random wlan0      # Randomize MAC"
echo "  secureos-mac restore wlan0     # Restore original"
echo ""
log "MAC randomization is active on all connections!"
