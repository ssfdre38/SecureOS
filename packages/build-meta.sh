#!/bin/bash
# Build SecureOS metapackage

PACKAGE_NAME="secureos-meta"
VERSION="1.1.0"
MAINTAINER="SecureOS Team <team@secureos.local>"
DESCRIPTION="SecureOS metapackage - installs all security and privacy tools"

BUILD_DIR="/tmp/build-$PACKAGE_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"

# Create control file
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: metapackages
Priority: optional
Architecture: all
Maintainer: $MAINTAINER
Depends: ufw, apparmor, apparmor-utils, auditd, aide, rkhunter, chkrootkit, fail2ban, clamav, clamav-daemon, firejail, bleachbit, cryptsetup, ecryptfs-utils, tor, privoxy, macchanger, mat2, wireguard, wireguard-tools, openvpn, unattended-upgrades
Recommends: secureos-tools, secureos-hardening, secureos-vpn
Description: $DESCRIPTION
 This metapackage installs all recommended security and privacy tools
 for SecureOS including:
  - Firewall (UFW)
  - MAC (AppArmor)
  - Audit logging (auditd)
  - Intrusion detection (AIDE, rkhunter, fail2ban)
  - Antivirus (ClamAV)
  - Privacy tools (Tor, Privoxy, MAC changer)
  - Encryption (cryptsetup, LUKS)
  - VPN support (WireGuard, OpenVPN)
EOF

# Build package
dpkg-deb --build "$BUILD_DIR" "${PACKAGE_NAME}_${VERSION}_all.deb"
echo "Package built: ${PACKAGE_NAME}_${VERSION}_all.deb"
