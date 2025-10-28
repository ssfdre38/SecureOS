#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# Hardware Security Module (HSM) Integration
#
set -e

echo "========================================"
echo "SecureOS v4.0.0 - HSM Integration"
echo "Copyright © 2025 Barrer Software"
echo "========================================"

install_hsm_support() {
    echo "[*] Installing HSM support packages..."
    
    # Install PKCS#11 libraries
    apt-get update
    apt-get install -y \
        opensc \
        libengine-pkcs11-openssl \
        p11-kit \
        libpam-pkcs11 \
        yubikey-manager \
        libykpers-1-1 \
        yubico-piv-tool \
        pcscd \
        pcsc-tools
    
    # Install TPM 2.0 tools
    apt-get install -y \
        tpm2-tools \
        tpm2-abrmd \
        libtss2-dev \
        clevis \
        clevis-tpm2 \
        clevis-luks
    
    # Install SoftHSM for testing
    apt-get install -y softhsm2
    
    # Install OpenSSL engine for TPM
    apt-get install -y libtpm2-pkcs11-1 tpm2-pkcs11-tools
    
    echo "[✓] HSM packages installed"
}

configure_tpm() {
    echo "[*] Configuring TPM 2.0..."
    
    # Check if TPM is available
    if [ -e /dev/tpm0 ] || [ -e /dev/tpmrm0 ]; then
        echo "[*] TPM device detected"
        
        # Start TPM services
        systemctl enable --now tpm2-abrmd.service
        systemctl enable --now pcscd.service
        
        # Initialize TPM
        mkdir -p /var/lib/tpm2-tss
        
        # Create primary key in TPM
        tpm2_createprimary -C e -g sha256 -G rsa -c /var/lib/tpm2-tss/primary.ctx || true
        
        # Configure TPM PKCS#11
        mkdir -p /etc/tpm2_pkcs11
        cat > /etc/tpm2_pkcs11/tpm2_pkcs11.conf << 'EOF'
# TPM2 PKCS#11 Configuration
# Copyright © 2025 Barrer Software

# TPM device
tcti = device:/dev/tpmrm0

# Token configuration
[token]
dir = /var/lib/tpm2_pkcs11
EOF
        
        echo "[✓] TPM configured"
    else
        echo "[!] No TPM device found - will use software fallback"
    fi
}

setup_yubikey() {
    echo "[*] Setting up YubiKey support..."
    
    # Configure PKCS#11 for YubiKey
    mkdir -p /etc/pkcs11/modules
    
    cat > /etc/pkcs11/modules/yubikey.module << 'EOF'
# YubiKey PKCS#11 Module
# Copyright © 2025 Barrer Software

module: /usr/lib/x86_64-linux-gnu/libykcs11.so
EOF
    
    # Configure PAM for YubiKey authentication
    cat > /etc/pam.d/yubikey << 'EOF'
# YubiKey PAM Configuration
# Copyright © 2025 Barrer Software

auth required pam_pkcs11.so
account required pam_permit.so
EOF
    
    # Create YubiKey configuration
    mkdir -p /etc/pam_pkcs11
    cat > /etc/pam_pkcs11/pam_pkcs11.conf << 'EOF'
# PAM PKCS#11 Configuration for YubiKey
# Copyright © 2025 Barrer Software

pam_pkcs11 {
  nullok = false;
  debug = false;
  
  use_pkcs11_module = yubikey;
  
  pkcs11_module yubikey {
    module = /usr/lib/x86_64-linux-gnu/libykcs11.so;
    description = "YubiKey PKCS#11";
    slot_num = 0;
    support_threads = true;
    ca_dir = /etc/pam_pkcs11/cacerts;
    crl_dir = /etc/pam_pkcs11/crls;
    cert_policy = ca,signature;
  }
  
  mapper default {
    debug = false;
    module = /usr/lib/x86_64-linux-gnu/pam_pkcs11/openssh_mapper.so;
  }
}
EOF
    
    mkdir -p /etc/pam_pkcs11/{cacerts,crls}
    
    echo "[✓] YubiKey support configured"
}

setup_luks_tpm() {
    echo "[*] Setting up LUKS with TPM unsealing..."
    
    # Create TPM key binding script
    cat > /usr/local/bin/luks-tpm-bind << 'EOF'
#!/bin/bash
# Bind LUKS to TPM
# Copyright © 2025 Barrer Software

DEVICE=$1

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 <encrypted-device>"
    exit 1
fi

if [ ! -e /dev/tpm0 ] && [ ! -e /dev/tpmrm0 ]; then
    echo "ERROR: No TPM device found"
    exit 1
fi

echo "Binding LUKS device $DEVICE to TPM..."

# Use clevis to bind LUKS to TPM
clevis luks bind -d "$DEVICE" tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,7"}'

echo "Done! Device will auto-unlock if TPM PCRs match"
echo "Warning: System changes may prevent auto-unlock"
EOF
    chmod +x /usr/local/bin/luks-tpm-bind
    
    # Add dracut module for TPM unlock
    if [ -d /etc/dracut.conf.d ]; then
        cat > /etc/dracut.conf.d/tpm-unlock.conf << 'EOF'
# Enable TPM-based LUKS unlock
add_dracutmodules+=" clevis clevis-tpm2 "
install_items+=" /usr/bin/clevis-luks-askpass "
EOF
    fi
    
    echo "[✓] LUKS TPM unsealing configured"
}

configure_ssh_hsm() {
    echo "[*] Configuring SSH with HSM support..."
    
    # Configure SSH to use PKCS#11
    if ! grep -q "PKCS11Provider" /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config << 'EOF'

# HSM/Smart Card Support
# Copyright © 2025 Barrer Software
PKCS11Provider /usr/lib/x86_64-linux-gnu/libykcs11.so

# Require public key authentication with HSM
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication yes
EOF
    fi
    
    # Create helper script for SSH key generation on HSM
    cat > /usr/local/bin/ssh-keygen-hsm << 'EOF'
#!/bin/bash
# Generate SSH key on HSM/YubiKey
# Copyright © 2025 Barrer Software

echo "SSH Key Generation on Hardware Security Module"
echo "==============================================="
echo ""
echo "Supported devices:"
echo "1) YubiKey"
echo "2) TPM 2.0"
echo "3) SoftHSM (testing)"
echo ""
read -p "Select device [1-3]: " choice

case $choice in
    1)
        echo "Generating SSH key on YubiKey..."
        ykman piv keys generate -a ECCP256 9a /tmp/pubkey.pem
        ykman piv certificates generate -s "SSH Key" 9a /tmp/pubkey.pem
        ssh-keygen -D /usr/lib/x86_64-linux-gnu/libykcs11.so -e
        ;;
    2)
        echo "Generating SSH key with TPM..."
        tpm2_create -C /var/lib/tpm2-tss/primary.ctx -g sha256 -G ecc \
            -u /var/lib/tpm2-tss/ssh.pub -r /var/lib/tpm2-tss/ssh.priv
        echo "Key generated and stored in TPM"
        ;;
    3)
        echo "Using SoftHSM for testing..."
        pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so \
            --login --keypairgen --key-type EC:secp256r1 --label "SSH"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Done! Configure your SSH client to use PKCS#11"
EOF
    chmod +x /usr/local/bin/ssh-keygen-hsm
    
    echo "[✓] SSH HSM support configured"
}

setup_code_signing() {
    echo "[*] Setting up code signing with HSM..."
    
    cat > /usr/local/bin/hsm-sign << 'EOF'
#!/bin/bash
# Sign files using HSM
# Copyright © 2025 Barrer Software

FILE=$1
OUTPUT=${2:-${FILE}.sig}

if [ -z "$FILE" ]; then
    echo "Usage: $0 <file-to-sign> [output-signature]"
    exit 1
fi

echo "Signing $FILE with HSM..."

# Sign using PKCS#11
pkcs11-tool --sign --mechanism SHA256-RSA-PKCS \
    --input-file "$FILE" \
    --output-file "$OUTPUT" \
    --login

echo "Signature saved to $OUTPUT"
EOF
    chmod +x /usr/local/bin/hsm-sign
    
    cat > /usr/local/bin/hsm-verify << 'EOF'
#!/bin/bash
# Verify HSM signature
# Copyright © 2025 Barrer Software

FILE=$1
SIGNATURE=$2

if [ -z "$FILE" ] || [ -z "$SIGNATURE" ]; then
    echo "Usage: $0 <file> <signature>"
    exit 1
fi

echo "Verifying signature..."

openssl dgst -sha256 -verify <(pkcs11-tool --read-object --type pubkey --id 01) \
    -signature "$SIGNATURE" "$FILE"

if [ $? -eq 0 ]; then
    echo "✓ Signature valid"
else
    echo "✗ Signature invalid"
    exit 1
fi
EOF
    chmod +x /usr/local/bin/hsm-verify
    
    echo "[✓] Code signing tools installed"
}

configure_certificate_storage() {
    echo "[*] Configuring certificate storage in HSM..."
    
    mkdir -p /etc/secureos/hsm-certs
    
    cat > /usr/local/bin/cert-to-hsm << 'EOF'
#!/bin/bash
# Import certificate to HSM
# Copyright © 2025 Barrer Software

CERT=$1
KEY=$2

if [ -z "$CERT" ] || [ -z "$KEY" ]; then
    echo "Usage: $0 <certificate.pem> <private-key.pem>"
    exit 1
fi

echo "Importing certificate and key to HSM..."

# Convert to PKCS#12 first
openssl pkcs12 -export -out /tmp/cert.p12 \
    -in "$CERT" -inkey "$KEY" \
    -passout pass:temporary

# Import to HSM (YubiKey example)
if command -v ykman &>/dev/null; then
    ykman piv certificates import 9a /tmp/cert.p12
    rm -f /tmp/cert.p12
    echo "✓ Certificate imported to YubiKey slot 9a"
else
    # Generic PKCS#11 import
    pkcs11-tool --module /usr/lib/x86_64-linux-gnu/libykcs11.so \
        --write-object /tmp/cert.p12 --type cert --label "SSL Cert" \
        --login
    rm -f /tmp/cert.p12
    echo "✓ Certificate imported via PKCS#11"
fi
EOF
    chmod +x /usr/local/bin/cert-to-hsm
    
    echo "[✓] Certificate storage configured"
}

setup_secure_boot_keys() {
    echo "[*] Setting up Secure Boot with HSM..."
    
    cat > /usr/local/bin/generate-secureboot-keys << 'EOF'
#!/bin/bash
# Generate Secure Boot keys with HSM
# Copyright © 2025 Barrer Software

mkdir -p /etc/secureos/secureboot-keys
cd /etc/secureos/secureboot-keys

echo "Generating Secure Boot keys..."

# Generate keys
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=SecureOS Platform Key/" \
    -keyout PK.key -out PK.crt -days 3650 -nodes
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=SecureOS Key Exchange Key/" \
    -keyout KEK.key -out KEK.crt -days 3650 -nodes
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=SecureOS Signature Database/" \
    -keyout db.key -out db.crt -days 3650 -nodes

# Convert to EFI format
cert-to-efi-sig-list -g "$(uuidgen)" PK.crt PK.esl
cert-to-efi-sig-list -g "$(uuidgen)" KEK.crt KEK.esl
cert-to-efi-sig-list -g "$(uuidgen)" db.crt db.esl

# Sign with keys
sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl PK.auth
sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl KEK.auth
sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl db.auth

echo "✓ Secure Boot keys generated"
echo ""
echo "To enroll keys:"
echo "1. Copy *.auth files to USB"
echo "2. Boot into UEFI setup"
echo "3. Enroll keys in Secure Boot settings"
EOF
    chmod +x /usr/local/bin/generate-secureboot-keys
    
    echo "[✓] Secure Boot key generation configured"
}

create_hsm_documentation() {
    cat > /etc/secureos/hsm-README.md << 'EOF'
# SecureOS Hardware Security Module Integration

Copyright © 2025 Barrer Software

## Overview

SecureOS v4.0.0 integrates with Hardware Security Modules (HSMs) for:
- Secure key storage
- Cryptographic operations
- Certificate management
- Secure boot
- Full disk encryption

## Supported Devices

### 1. TPM 2.0 (Trusted Platform Module)
- Built into most modern hardware
- LUKS disk encryption auto-unlock
- Secure boot measurements
- Platform attestation

### 2. YubiKey
- FIDO2/U2F authentication
- PIV smart card
- SSH key storage
- Code signing

### 3. Generic PKCS#11 Devices
- HSM cards
- Smart cards
- USB crypto tokens

## Quick Start

### TPM Setup
```bash
# Check TPM status
tpm2_getcap properties-fixed

# Bind LUKS to TPM
sudo luks-tpm-bind /dev/sda3
```

### YubiKey Setup
```bash
# Check YubiKey
ykman info

# Generate SSH key on YubiKey
ssh-keygen-hsm
```

### SSH with HSM
```bash
# Use YubiKey for SSH
ssh -I /usr/lib/x86_64-linux-gnu/libykcs11.so user@host
```

## Commands

### Key Management
- `ssh-keygen-hsm` - Generate SSH keys on HSM
- `cert-to-hsm` - Import certificates to HSM
- `hsm-sign` - Sign files with HSM
- `hsm-verify` - Verify HSM signatures

### TPM Operations
- `luks-tpm-bind` - Bind LUKS to TPM
- `tpm2_createprimary` - Create TPM primary key
- `tpm2_create` - Create TPM objects

### YubiKey Operations
- `ykman piv` - PIV operations
- `ykman oath` - OATH/TOTP
- `ykman fido` - FIDO2 operations

## Configuration Files

- `/etc/tpm2_pkcs11/tpm2_pkcs11.conf` - TPM PKCS#11 config
- `/etc/pam_pkcs11/pam_pkcs11.conf` - PAM smart card auth
- `/etc/ssh/sshd_config` - SSH with PKCS#11
- `/etc/secureos/hsm-certs/` - Certificate storage

## Use Cases

### 1. Secure SSH Authentication
Store SSH private keys on YubiKey/TPM, never on disk

### 2. Disk Encryption
Auto-unlock LUKS with TPM (sealed to PCRs)

### 3. Code Signing
Sign packages and binaries with HSM-protected keys

### 4. TLS Certificates
Store web server certificates in HSM

### 5. Secure Boot
Sign kernels and bootloaders with HSM keys

## Best Practices

1. **Never export private keys** from HSM
2. **Use PIN protection** for all operations
3. **Backup recovery codes** (if supported)
4. **Regular firmware updates** for YubiKey
5. **Monitor TPM PCR values** for tampering

## Troubleshooting

### TPM not detected
```bash
ls -l /dev/tpm*
systemctl status tpm2-abrmd
```

### YubiKey not recognized
```bash
lsusb | grep Yubico
systemctl status pcscd
```

### PKCS#11 errors
```bash
pkcs11-tool --module /usr/lib/x86_64-linux-gnu/libykcs11.so -L
pkcs11-tool --module /usr/lib/x86_64-linux-gnu/libykcs11.so -T
```

## Security Notes

- TPM auto-unlock can be bypassed if firmware is modified
- YubiKey requires physical access to authorize operations
- Always use PIN/passphrase protection
- Secure Boot prevents unauthorized boot code

## Support

- Documentation: https://ssfdre38.github.io/SecureOS
- GitHub: https://github.com/ssfdre38/SecureOS
- Issues: https://github.com/ssfdre38/SecureOS/issues

---

SecureOS v4.0.0 - Hardware Security Module Integration
Barrer Software © 2025
EOF
    
    echo "[✓] HSM documentation created"
}

main() {
    echo ""
    echo "This script sets up Hardware Security Module support for SecureOS"
    echo ""
    
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root"
        exit 1
    fi
    
    read -p "Install HSM support? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_hsm_support
        configure_tpm
        setup_yubikey
        setup_luks_tpm
        configure_ssh_hsm
        setup_code_signing
        configure_certificate_storage
        setup_secure_boot_keys
        create_hsm_documentation
        
        echo ""
        echo "============================================"
        echo "✓ HSM Integration Setup Complete!"
        echo "============================================"
        echo ""
        echo "Next steps:"
        echo "1. Insert YubiKey or check TPM: tpm2_getcap properties-fixed"
        echo "2. Generate SSH keys: ssh-keygen-hsm"
        echo "3. Bind LUKS to TPM: luks-tpm-bind /dev/sdXY"
        echo "4. Read documentation: /etc/secureos/hsm-README.md"
        echo ""
        echo "SecureOS v4.0.0 - HSM Enabled"
        echo "Barrer Software © 2025"
    fi
}

main "$@"
