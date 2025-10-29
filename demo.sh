#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# Quick Demo - SecureOS Installer
# This demonstrates the interactive installer without building the full ISO

echo "╔═══════════════════════════════════════════════════╗"
echo "║              SecureOS Demo Installer             ║"
echo "║     Security & Privacy Focused Linux Distro       ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "This is a demonstration of the SecureOS installer."
echo "The full ISO build takes 30-60 minutes and requires:"
echo "  - Root/sudo access"
echo "  - 10GB+ free disk space"
echo "  - Fast internet connection"
echo ""
echo "To build the actual ISO, run:"
echo "  sudo bash scripts/build_iso.sh"
echo ""
echo "Features included in SecureOS:"
echo "  ✓ Full disk encryption (LUKS2 + Argon2id)"
echo "  ✓ Hardened kernel with security patches"
echo "  ✓ AppArmor mandatory access control"
echo "  ✓ UFW firewall pre-configured"
echo "  ✓ Audit logging for security events"
echo "  ✓ Privacy-enhanced DNS (DNS over TLS)"
echo "  ✓ Tor and privacy tools included"
echo "  ✓ Automatic security updates"
echo "  ✓ No telemetry or tracking"
echo "  ✓ Fail2ban intrusion prevention"
echo "  ✓ ClamAV antivirus"
echo "  ✓ MAC address randomization"
echo ""
echo "GitHub: https://github.com/barrersoftware/SecureOS"
echo ""
echo "Press Enter to run interactive installer demo..."
read

# Check if running as root for demo purposes
if [ "$EUID" -eq 0 ]; then
    python3 installer/secure_installer.py
else
    echo "Note: Installer requires root privileges for actual installation."
    echo "Running in demo mode..."
    echo ""
    echo "To run the actual installer:"
    echo "  sudo python3 installer/secure_installer.py"
fi
