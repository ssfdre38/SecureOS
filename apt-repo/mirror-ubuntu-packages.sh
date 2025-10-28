#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS APT Mirror - Mirror Ubuntu 24.04 Packages
# Creates a local mirror of Ubuntu packages for offline/local use

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

# Configuration
MIRROR_BASE="/var/www/html/ubuntu-mirror"
UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu"
UBUNTU_RELEASE="noble"  # 24.04
ARCHITECTURES="amd64"
COMPONENTS="main restricted universe multiverse"
SECTIONS="$UBUNTU_RELEASE $UBUNTU_RELEASE-updates $UBUNTU_RELEASE-security $UBUNTU_RELEASE-backports"

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║          SecureOS APT Mirror Setup                                ║
║          Mirror Ubuntu 24.04 Packages Locally                     ║
╚═══════════════════════════════════════════════════════════════════╝

This script can:
1. Create a FULL mirror (100+ GB) - All packages
2. Create a SELECTIVE mirror (10-50 GB) - Important packages only
3. Create a MINIMAL mirror (2-5 GB) - Security essentials only

WARNING: Full mirror requires significant disk space and bandwidth!
EOF

echo ""
read -p "Select mirror type (1=Full, 2=Selective, 3=Minimal): " MIRROR_TYPE

case $MIRROR_TYPE in
    1) MIRROR_MODE="full" ;;
    2) MIRROR_MODE="selective" ;;
    3) MIRROR_MODE="minimal" ;;
    *) error "Invalid choice"; exit 1 ;;
esac

log "Installing mirror tools..."
apt-get update -qq
apt-get install -y apt-mirror debmirror nginx rsync wget

# Method 1: Using apt-mirror (Simple, Full Mirror)
if [ "$MIRROR_MODE" = "full" ]; then
    log "Setting up FULL mirror with apt-mirror..."
    
    cat > /etc/apt/mirror.list << EOF
############# config ##################
set base_path    $MIRROR_BASE
set mirror_path  \$base_path/mirror
set skel_path    \$base_path/skel
set var_path     \$base_path/var
set cleanscript  \$var_path/clean.sh
set defaultarch  $ARCHITECTURES
set postmirror_script \$var_path/postmirror.sh
set run_postmirror 0
set nthreads     20
set _tilde 0

############# end config ##############

# Ubuntu 24.04 Noble
deb $UBUNTU_MIRROR $UBUNTU_RELEASE main restricted universe multiverse
deb $UBUNTU_MIRROR $UBUNTU_RELEASE-updates main restricted universe multiverse
deb $UBUNTU_MIRROR $UBUNTU_RELEASE-security main restricted universe multiverse
deb $UBUNTU_MIRROR $UBUNTU_RELEASE-backports main restricted universe multiverse

# Source packages (optional, adds significant size)
# deb-src $UBUNTU_MIRROR $UBUNTU_RELEASE main restricted universe multiverse

clean $UBUNTU_MIRROR
EOF

    mkdir -p "$MIRROR_BASE"
    
    warn "This will download 100+ GB of data!"
    warn "Estimated time: 2-8 hours depending on connection"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    log "Starting mirror sync (this will take a long time)..."
    apt-mirror
    
    REPO_PATH="$MIRROR_BASE/mirror/archive.ubuntu.com/ubuntu"

# Method 2: Using debmirror (Selective Mirror)
elif [ "$MIRROR_MODE" = "selective" ]; then
    log "Setting up SELECTIVE mirror with debmirror..."
    
    REPO_PATH="$MIRROR_BASE"
    mkdir -p "$REPO_PATH"
    
    # Define important package sections
    SECTIONS_FILTER="main,restricted,universe"
    
    warn "This will download 10-50 GB of data!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    log "Mirroring packages (this may take 1-3 hours)..."
    debmirror \
        --host=archive.ubuntu.com \
        --root=/ubuntu \
        --dist=$UBUNTU_RELEASE,$UBUNTU_RELEASE-updates,$UBUNTU_RELEASE-security \
        --section=$SECTIONS_FILTER \
        --arch=$ARCHITECTURES \
        --method=http \
        --progress \
        --nosource \
        "$REPO_PATH"

# Method 3: Download specific packages only (Minimal)
else
    log "Setting up MINIMAL mirror with specific packages..."
    
    REPO_PATH="$MIRROR_BASE"
    mkdir -p "$REPO_PATH"/{pool,dists}
    
    # Essential security packages
    PACKAGES=(
        # Security
        ufw apparmor apparmor-utils auditd aide rkhunter chkrootkit
        fail2ban clamav clamav-daemon firejail
        
        # Encryption
        cryptsetup ecryptfs-utils
        
        # Privacy
        tor privoxy macchanger mat2
        
        # VPN
        wireguard wireguard-tools openvpn network-manager-openvpn
        
        # System
        linux-image-generic linux-headers-generic
        unattended-upgrades apt-transport-https
        
        # Tools
        curl wget git vim htop tmux
    )
    
    log "Downloading essential packages..."
    cd "$REPO_PATH/pool"
    
    for package in "${PACKAGES[@]}"; do
        log "Downloading: $package"
        apt-get download "$package" 2>/dev/null || warn "Failed to download $package"
        
        # Also get dependencies
        apt-cache depends "$package" | grep "Depends:" | cut -d: -f2 | tr -d ' ' | while read dep; do
            apt-get download "$dep" 2>/dev/null || true
        done
    done
    
    log "Creating repository metadata..."
    cd "$REPO_PATH"
    dpkg-scanpackages pool /dev/null | gzip -9c > pool/Packages.gz
    
    # Create Release file
    cat > dists/Release << EOF
Origin: SecureOS Mirror
Label: SecureOS Ubuntu Mirror
Suite: $UBUNTU_RELEASE
Codename: $UBUNTU_RELEASE
Architectures: $ARCHITECTURES
Components: main
Description: SecureOS Essential Packages Mirror
EOF
fi

# Configure nginx
log "Configuring web server..."
cat > /etc/nginx/sites-available/ubuntu-mirror << EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name mirror.secureos.local ubuntu-mirror.local;
    root $REPO_PATH;
    
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /pool/ {
        autoindex on;
    }
    
    location /dists/ {
        autoindex on;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ubuntu-mirror /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Create update script
cat > /usr/local/bin/update-ubuntu-mirror << 'SCRIPT'
#!/bin/bash
# Update Ubuntu Mirror

MIRROR_MODE="__MIRROR_MODE__"
REPO_PATH="__REPO_PATH__"

echo "Updating Ubuntu mirror..."

if [ "$MIRROR_MODE" = "full" ]; then
    apt-mirror
elif [ "$MIRROR_MODE" = "selective" ]; then
    debmirror \
        --host=archive.ubuntu.com \
        --root=/ubuntu \
        --dist=noble,noble-updates,noble-security \
        --section=main,restricted,universe \
        --arch=amd64 \
        --method=http \
        --progress \
        --nosource \
        "$REPO_PATH"
else
    echo "Minimal mirror - manual package updates needed"
fi

echo "Mirror update complete!"
SCRIPT

# Substitute variables
sed -i "s|__MIRROR_MODE__|$MIRROR_MODE|g" /usr/local/bin/update-ubuntu-mirror
sed -i "s|__REPO_PATH__|$REPO_PATH|g" /usr/local/bin/update-ubuntu-mirror
chmod +x /usr/local/bin/update-ubuntu-mirror

# Create cron job for automatic updates
log "Setting up automatic updates..."
cat > /etc/cron.d/ubuntu-mirror << EOF
# Update Ubuntu mirror daily at 2 AM
0 2 * * * root /usr/local/bin/update-ubuntu-mirror >> /var/log/ubuntu-mirror.log 2>&1
EOF

# Client configuration instructions
cat > "$REPO_PATH/CLIENT_SETUP.txt" << EOF
SecureOS Ubuntu Mirror - Client Setup
======================================

This mirror is available at:
  http://$(hostname -I | awk '{print $1}')
  http://mirror.secureos.local

Add to /etc/hosts on clients:
  $(hostname -I | awk '{print $1}')  mirror.secureos.local

Configure APT on Client Machines:
----------------------------------

1. Backup current sources:
   sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

2. Replace with mirror:
   sudo tee /etc/apt/sources.list << 'SOURCES'
# SecureOS Ubuntu Mirror
deb http://mirror.secureos.local $UBUNTU_RELEASE main restricted universe multiverse
deb http://mirror.secureos.local $UBUNTU_RELEASE-updates main restricted universe multiverse
deb http://mirror.secureos.local $UBUNTU_RELEASE-security main restricted universe multiverse
deb http://mirror.secureos.local $UBUNTU_RELEASE-backports main restricted universe multiverse
SOURCES

3. Update package list:
   sudo apt update

4. Test installation:
   sudo apt install vim

Offline USB Repository:
-----------------------

To create bootable USB with packages:

1. Copy mirror to USB:
   rsync -av $REPO_PATH /media/usb/ubuntu-mirror/

2. On offline machine:
   sudo tee /etc/apt/sources.list << 'SOURCES'
deb file:///media/usb/ubuntu-mirror $UBUNTU_RELEASE main
SOURCES

   sudo apt update

Disk Space Usage:
-----------------
Full Mirror:    100-150 GB
Selective:      10-50 GB
Minimal:        2-5 GB

Bandwidth Usage:
----------------
Initial sync:   Same as disk space
Daily updates:  100 MB - 2 GB (depending on type)
EOF

success "Ubuntu mirror setup complete!"
echo ""
log "Mirror Information:"
echo "  Type: $MIRROR_MODE"
echo "  Path: $REPO_PATH"
echo "  URL: http://$(hostname -I | awk '{print $1}')"
echo "  Disk usage: $(du -sh $REPO_PATH | cut -f1)"
echo ""
log "Configuration:"
echo "  Client setup: $REPO_PATH/CLIENT_SETUP.txt"
echo "  Update script: /usr/local/bin/update-ubuntu-mirror"
echo "  Cron job: /etc/cron.d/ubuntu-mirror (daily at 2 AM)"
echo ""
log "Update mirror manually:"
echo "  sudo update-ubuntu-mirror"
echo ""
log "View in browser:"
echo "  http://$(hostname -I | awk '{print $1}')"

# Show disk usage warning
if [ "$MIRROR_MODE" = "full" ]; then
    warn "Full mirror will grow over time!"
    warn "Monitor disk space: df -h $MIRROR_BASE"
fi
