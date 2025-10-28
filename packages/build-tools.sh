#!/bin/bash
# Build SecureOS tools package

PACKAGE_NAME="secureos-tools"
VERSION="1.1.0"
MAINTAINER="SecureOS Team <team@secureos.local>"
DESCRIPTION="SecureOS management and security tools"

BUILD_DIR="/tmp/build-$PACKAGE_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/usr/share/doc/$PACKAGE_NAME"

# Create control file
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Maintainer: $MAINTAINER
Depends: python3, bash (>= 4.0)
Description: $DESCRIPTION
 Collection of security management tools for SecureOS:
  - secureos-audit: Security audit tool
  - secureos-vpn: VPN management
  - secureos-mac: MAC address management
  - secureos-container: Container security
  - secureos-repo: Repository management
EOF

# Create tools
cat > "$BUILD_DIR/usr/local/bin/secureos-cli" << 'EOF'
#!/bin/bash
# SecureOS Command Line Interface

VERSION="1.1.0"

show_banner() {
    cat << 'BANNER'
╔═══════════════════════════════════════════════════╗
║              SecureOS CLI v1.1.0                  ║
║     Security & Privacy Management Tool            ║
╚═══════════════════════════════════════════════════╝
BANNER
}

show_menu() {
    echo ""
    echo "Available Tools:"
    echo "  1. Security Audit       (secureos-audit)"
    echo "  2. VPN Management       (secureos-vpn)"
    echo "  3. MAC Randomization    (secureos-mac)"
    echo "  4. Container Security   (secureos-container)"
    echo "  5. System Hardening     (secureos-harden)"
    echo "  6. Privacy Check        (secureos-privacy)"
    echo ""
    echo "  0. Exit"
    echo ""
}

privacy_check() {
    echo "SecureOS Privacy Check"
    echo "======================"
    echo ""
    
    echo "[*] Checking for telemetry..."
    if systemctl is-active whoopsie &>/dev/null; then
        echo "  ⚠  Ubuntu error reporting active"
        echo "     Disable with: sudo systemctl disable whoopsie"
    else
        echo "  ✓  No error reporting"
    fi
    
    echo ""
    echo "[*] Checking DNS configuration..."
    NAMESERVERS=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
    echo "  Current DNS: $NAMESERVERS"
    if echo "$NAMESERVERS" | grep -q "9.9.9.9\|149.112.112.112\|1.1.1.1"; then
        echo "  ✓  Using privacy-focused DNS"
    else
        echo "  ⚠  Consider using privacy DNS (Quad9: 9.9.9.9)"
    fi
    
    echo ""
    echo "[*] Checking for MAC randomization..."
    if [ -f /etc/NetworkManager/conf.d/99-random-mac.conf ]; then
        echo "  ✓  MAC randomization configured"
    else
        echo "  ⚠  MAC randomization not configured"
    fi
    
    echo ""
    echo "[*] Checking browser privacy..."
    if command -v firefox &>/dev/null; then
        echo "  ✓  Firefox installed"
        if [ -d ~/.mozilla/firefox ]; then
            echo "     Consider: Privacy Badger, uBlock Origin, HTTPS Everywhere"
        fi
    fi
    
    echo ""
    echo "[*] Checking for Tor..."
    if systemctl is-active tor &>/dev/null; then
        echo "  ✓  Tor service running"
    else
        echo "  ⚠  Tor not running (start with: sudo systemctl start tor)"
    fi
}

harden_system() {
    echo "SecureOS System Hardening"
    echo "========================="
    echo ""
    echo "This will apply additional security hardening."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    echo "[*] Disabling unnecessary services..."
    sudo systemctl disable bluetooth 2>/dev/null || true
    sudo systemctl disable cups 2>/dev/null || true
    
    echo "[*] Setting secure permissions..."
    sudo chmod 700 /root
    sudo chmod 600 /etc/ssh/sshd_config 2>/dev/null || true
    
    echo "[*] Configuring firewall..."
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    echo "✓ System hardening complete!"
}

if [ "$1" = "--version" ]; then
    echo "SecureOS CLI version $VERSION"
    exit 0
fi

if [ "$1" = "privacy" ]; then
    privacy_check
    exit 0
fi

if [ "$1" = "harden" ]; then
    harden_system
    exit 0
fi

show_banner

while true; do
    show_menu
    read -p "Select option: " choice
    
    case $choice in
        1) secureos-audit ;;
        2) secureos-vpn ;;
        3) secureos-mac ;;
        4) secureos-container ;;
        5) harden_system ;;
        6) privacy_check ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
EOF

chmod +x "$BUILD_DIR/usr/local/bin/secureos-cli"

# Create documentation
cat > "$BUILD_DIR/usr/share/doc/$PACKAGE_NAME/README.md" << 'EOF'
# SecureOS Tools

Management and security tools for SecureOS.

## Tools Included

- `secureos-cli`: Interactive command-line interface
- `secureos-audit`: Security audit tool
- `secureos-vpn`: VPN management
- `secureos-mac`: MAC address randomization
- `secureos-container`: Container security management

## Usage

Run the interactive CLI:
```bash
secureos-cli
```

Or use tools directly:
```bash
secureos-audit
secureos-vpn status
secureos-mac random wlan0
```

## Documentation

Full documentation: https://github.com/ssfdre38/SecureOS
EOF

# Create postinst script
cat > "$BUILD_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

echo "SecureOS tools installed successfully!"
echo "Run 'secureos-cli' to get started."
EOF
chmod +x "$BUILD_DIR/DEBIAN/postinst"

# Build package
dpkg-deb --build "$BUILD_DIR" "${PACKAGE_NAME}_${VERSION}_all.deb"
echo "Package built: ${PACKAGE_NAME}_${VERSION}_all.deb"
