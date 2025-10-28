#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS APT Repository Setup
# Creates and configures a custom APT repository for SecureOS packages

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

REPO_DIR="/var/www/html/secureos"
REPO_NAME="secureos"
REPO_CODENAME="noble"
REPO_COMPONENTS="main security"
GPG_KEY_NAME="SecureOS Repository"
GPG_KEY_EMAIL="repo@secureos.local"

if [ "$EUID" -ne 0 ]; then 
    error "Please run as root"
    exit 1
fi

log "Installing APT repository tools..."
apt-get update -qq
apt-get install -y \
    dpkg-dev \
    reprepro \
    gnupg \
    nginx \
    apache2-utils

# Create repository structure
log "Creating repository structure..."
mkdir -p "$REPO_DIR"/{conf,incoming,pool,dists}
cd "$REPO_DIR"

# Generate GPG key for signing
log "Generating GPG key for package signing..."
if ! gpg --list-keys "$GPG_KEY_EMAIL" &>/dev/null; then
    cat > /tmp/gpg-gen.conf << EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $GPG_KEY_NAME
Name-Email: $GPG_KEY_EMAIL
Expire-Date: 0
EOF
    gpg --batch --generate-key /tmp/gpg-gen.conf
    rm /tmp/gpg-gen.conf
fi

GPG_KEY_ID=$(gpg --list-keys "$GPG_KEY_EMAIL" | grep -A1 pub | tail -1 | tr -d ' ')

# Export public key
gpg --armor --export "$GPG_KEY_EMAIL" > "$REPO_DIR/secureos-repo.gpg"

# Configure reprepro
log "Configuring reprepro..."
cat > "$REPO_DIR/conf/distributions" << EOF
Origin: SecureOS
Label: SecureOS Repository
Codename: $REPO_CODENAME
Architectures: amd64 arm64 source
Components: $REPO_COMPONENTS
Description: SecureOS Security and Privacy Packages
SignWith: $GPG_KEY_ID
EOF

cat > "$REPO_DIR/conf/options" << EOF
verbose
basedir $REPO_DIR
ask-passphrase
EOF

cat > "$REPO_DIR/conf/incoming" << EOF
Name: incoming
IncomingDir: incoming
TempDir: /tmp
Allow: $REPO_CODENAME
Cleanup: on_deny on_error
EOF

# Create nginx configuration
log "Configuring nginx web server..."
cat > /etc/nginx/sites-available/secureos-repo << EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name repo.secureos.local;
    root $REPO_DIR;
    
    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    location ~ /(db|conf)/ {
        deny all;
        return 404;
    }
    
    # Enable directory listings for pool and dists
    location /pool/ {
        autoindex on;
    }
    
    location /dists/ {
        autoindex on;
    }
}
EOF

ln -sf /etc/nginx/sites-available/secureos-repo /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Set permissions
chown -R www-data:www-data "$REPO_DIR"
chmod -R 755 "$REPO_DIR"

# Create helper script for package management
cat > /usr/local/bin/secureos-repo << 'EOF'
#!/bin/bash
# SecureOS Repository Manager

REPO_DIR="/var/www/html/secureos"

show_help() {
    echo "SecureOS Repository Manager"
    echo ""
    echo "Usage: secureos-repo <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add <package.deb>     Add package to repository"
    echo "  remove <package>      Remove package from repository"
    echo "  list                  List all packages"
    echo "  update                Update repository metadata"
    echo "  export-key            Export repository public key"
    echo "  client-setup          Show client setup instructions"
    echo ""
    echo "Examples:"
    echo "  secureos-repo add mypackage_1.0_amd64.deb"
    echo "  secureos-repo list"
}

add_package() {
    local deb="$1"
    if [ ! -f "$deb" ]; then
        echo "Error: Package file not found: $deb"
        exit 1
    fi
    
    echo "Adding package to repository..."
    cd "$REPO_DIR"
    reprepro includedeb noble "$deb"
    echo "Package added successfully"
}

remove_package() {
    local package="$1"
    if [ -z "$package" ]; then
        echo "Error: Package name required"
        exit 1
    fi
    
    echo "Removing package from repository..."
    cd "$REPO_DIR"
    reprepro remove noble "$package"
    echo "Package removed successfully"
}

list_packages() {
    echo "Packages in repository:"
    cd "$REPO_DIR"
    reprepro list noble
}

update_repo() {
    echo "Updating repository metadata..."
    cd "$REPO_DIR"
    reprepro export noble
    echo "Repository updated"
}

export_key() {
    local keyfile="$REPO_DIR/secureos-repo.gpg"
    if [ -f "$keyfile" ]; then
        cat "$keyfile"
    else
        echo "Error: Repository key not found"
        exit 1
    fi
}

client_setup() {
    echo "SecureOS Repository - Client Setup Instructions"
    echo "================================================"
    echo ""
    echo "1. Download and add repository key:"
    echo "   wget -qO - http://repo.secureos.local/secureos-repo.gpg | sudo apt-key add -"
    echo ""
    echo "2. Add repository to sources:"
    echo "   echo 'deb http://repo.secureos.local noble main security' | sudo tee /etc/apt/sources.list.d/secureos.list"
    echo ""
    echo "3. Update package list:"
    echo "   sudo apt update"
    echo ""
    echo "4. Install SecureOS packages:"
    echo "   sudo apt install <package-name>"
    echo ""
    echo "For HTTPS (recommended):"
    echo "  - Configure nginx with SSL certificate"
    echo "  - Use https://repo.secureos.local in sources.list"
}

case "$1" in
    add) add_package "$2" ;;
    remove) remove_package "$2" ;;
    list) list_packages ;;
    update) update_repo ;;
    export-key) export_key ;;
    client-setup) client_setup ;;
    *) show_help ;;
esac
EOF
chmod +x /usr/local/bin/secureos-repo

success "APT repository setup complete!"
echo ""
log "Repository location: $REPO_DIR"
log "Repository URL: http://repo.secureos.local"
echo ""
log "Next steps:"
echo "  1. Add packages: secureos-repo add package.deb"
echo "  2. Update metadata: secureos-repo update"
echo "  3. Setup clients: secureos-repo client-setup"
echo ""
log "Public key location: $REPO_DIR/secureos-repo.gpg"
