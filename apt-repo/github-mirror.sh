#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS GitHub Releases Mirror
# Host APT packages via GitHub Releases (bypasses file size limits)

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

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║          SecureOS GitHub Releases APT Mirror                      ║
║          Host APT Packages on GitHub (Free & Unlimited)           ║
╚═══════════════════════════════════════════════════════════════════╝

GitHub has limitations for traditional mirroring:
1. 100 GB repo size limit (too small for full mirror)
2. Large file warnings at 50 MB
3. Git LFS costs money after 1 GB

SOLUTION: Use GitHub Releases!
✅ Unlimited storage
✅ No bandwidth costs
✅ Global CDN (fast downloads)
✅ 2 GB per file limit
✅ Free for public repos

This script creates:
- Package collections as releases
- APT repository metadata on GitHub Pages
- Automatic client configuration
EOF

echo ""
read -p "Do you have a GitHub repository ready? (y/n): " HAS_REPO

if [[ ! $HAS_REPO =~ ^[Yy]$ ]]; then
    warn "Create a GitHub repository first:"
    echo "  1. Go to https://github.com/new"
    echo "  2. Name it: secureos-packages"
    echo "  3. Make it public"
    echo "  4. Run: gh repo clone USERNAME/secureos-packages"
    exit 0
fi

read -p "Enter your GitHub repository (user/repo): " GITHUB_REPO
read -p "Enter package collection name (e.g., security-essentials): " COLLECTION_NAME

log "Installing dependencies..."
apt-get update -qq
apt-get install -y gh git curl jq

# Verify gh authentication
if ! gh auth status &>/dev/null; then
    log "Please authenticate with GitHub..."
    gh auth login
fi

WORK_DIR="/tmp/github-mirror-$$"
mkdir -p "$WORK_DIR"/{packages,metadata}
cd "$WORK_DIR"

# Download essential packages
log "Downloading package collection: $COLLECTION_NAME"

if [ "$COLLECTION_NAME" = "security-essentials" ]; then
    PACKAGES=(
        ufw apparmor apparmor-utils auditd aide rkhunter
        fail2ban clamav cryptsetup tor wireguard-tools
    )
elif [ "$COLLECTION_NAME" = "privacy-tools" ]; then
    PACKAGES=(
        tor privoxy macchanger mat2 bleachbit
        wireguard wireguard-tools openvpn
    )
elif [ "$COLLECTION_NAME" = "dev-tools" ]; then
    PACKAGES=(
        vim git curl wget build-essential python3-pip
        docker.io docker-compose nodejs npm
    )
else
    warn "Custom collection - add packages manually to $WORK_DIR/packages/"
    PACKAGES=()
fi

cd "$WORK_DIR/packages"

for package in "${PACKAGES[@]}"; do
    log "Downloading: $package"
    apt-get download "$package" 2>/dev/null || warn "Failed: $package"
    
    # Get dependencies
    apt-cache depends "$package" 2>/dev/null | \
        grep "Depends:" | cut -d: -f2 | tr -d ' ' | \
        while read dep; do
            [ -n "$dep" ] && apt-get download "$dep" 2>/dev/null || true
        done
done

# Create repository metadata
log "Creating APT repository metadata..."
cd "$WORK_DIR/metadata"

cat > InRelease << EOF
Origin: SecureOS GitHub Mirror
Label: SecureOS Packages
Suite: noble
Codename: noble
Date: $(date -R)
Architectures: amd64 arm64
Components: main
Description: SecureOS packages hosted on GitHub Releases
EOF

# Create Packages index
cd "$WORK_DIR/packages"
dpkg-scanpackages . /dev/null > ../metadata/Packages
gzip -9c < ../metadata/Packages > ../metadata/Packages.gz

# Calculate file sizes and hashes
cd "$WORK_DIR/metadata"
cat >> InRelease << EOF

MD5Sum:
 $(md5sum Packages | awk '{print $1, length, "Packages"}')
 $(md5sum Packages.gz | awk '{print $1, length, "Packages.gz"}')
SHA256:
 $(sha256sum Packages | awk '{print $1, length, "Packages"}')
 $(sha256sum Packages.gz | awk '{print $1, length, "Packages.gz"}')
EOF

# Create archive of packages (split if > 2GB)
log "Creating package archive..."
cd "$WORK_DIR/packages"

TOTAL_SIZE=$(du -sb . | awk '{print $1}')
MAX_SIZE=$((2 * 1024 * 1024 * 1024))  # 2 GB

if [ "$TOTAL_SIZE" -gt "$MAX_SIZE" ]; then
    warn "Package collection > 2GB, splitting into parts..."
    tar czf - *.deb | split -b 1900M - "../${COLLECTION_NAME}-"
    ARCHIVE_FILES=(../${COLLECTION_NAME}-*)
else
    tar czf "../${COLLECTION_NAME}.tar.gz" *.deb
    ARCHIVE_FILES=("../${COLLECTION_NAME}.tar.gz")
fi

# Create release on GitHub
log "Creating GitHub release..."
RELEASE_TAG="v$(date +%Y%m%d)-${COLLECTION_NAME}"

gh release create "$RELEASE_TAG" \
    --repo "$GITHUB_REPO" \
    --title "SecureOS Packages - $COLLECTION_NAME" \
    --notes "Package collection: $COLLECTION_NAME
    
Packages included:
$(ls *.deb | sed 's/^/- /')

Installation:
\`\`\`bash
# Download and install
curl -L https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/${COLLECTION_NAME}.tar.gz -o packages.tar.gz
tar xzf packages.tar.gz
sudo dpkg -i *.deb
sudo apt-get install -f
\`\`\`

Or add as APT repository:
\`\`\`bash
echo \"deb [trusted=yes] https://raw.githubusercontent.com/$GITHUB_REPO/gh-pages/ ./\" | sudo tee /etc/apt/sources.list.d/secureos-github.list
sudo apt update
\`\`\`
" \
    "${ARCHIVE_FILES[@]}" \
    ../metadata/Packages \
    ../metadata/Packages.gz \
    ../metadata/InRelease

success "Release created: $RELEASE_TAG"

# Setup GitHub Pages for APT repository
log "Setting up GitHub Pages APT repository..."

PAGES_DIR="/tmp/gh-pages-$$"
git clone "https://github.com/$GITHUB_REPO.git" "$PAGES_DIR" || git init "$PAGES_DIR"
cd "$PAGES_DIR"

git checkout gh-pages 2>/dev/null || git checkout -b gh-pages

# Create directory structure
mkdir -p dists/noble/main/binary-amd64

# Copy metadata
cp "$WORK_DIR/metadata/Packages" dists/noble/main/binary-amd64/
cp "$WORK_DIR/metadata/Packages.gz" dists/noble/main/binary-amd64/
cp "$WORK_DIR/metadata/InRelease" dists/noble/

# Create Release file
cat > dists/noble/Release << EOF
Origin: SecureOS GitHub Mirror
Label: SecureOS
Suite: noble
Codename: noble
Date: $(date -R)
Architectures: amd64
Components: main
Description: SecureOS packages from GitHub Releases
EOF

# Create index.html
cat > index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SecureOS APT Repository</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>SecureOS APT Repository</h1>
    <p>Hosted on GitHub Releases with metadata on GitHub Pages</p>
    
    <h2>Quick Setup</h2>
    <pre><code>echo "deb [trusted=yes] https://$(echo $GITHUB_REPO | cut -d/ -f1).github.io/$(echo $GITHUB_REPO | cut -d/ -f2)/ ./" | sudo tee /etc/apt/sources.list.d/secureos-github.list
sudo apt update</code></pre>
    
    <h2>Available Packages</h2>
    <ul>
        $(cd "$WORK_DIR/packages" && ls *.deb | sed 's/^/<li>/' | sed 's/$/<\/li>/')
    </ul>
    
    <h2>Download Collections</h2>
    <p>Visit <a href="https://github.com/$GITHUB_REPO/releases">Releases</a> to download package collections.</p>
    
    <h2>Manual Installation</h2>
    <pre><code># Download specific release
curl -L https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/${COLLECTION_NAME}.tar.gz -o packages.tar.gz
tar xzf packages.tar.gz
sudo dpkg -i *.deb
sudo apt-get install -f</code></pre>
</body>
</html>
EOF

# Create .nojekyll to bypass Jekyll processing
touch .nojekyll

# Commit and push
git add .
git config user.email "github-actions@github.com"
git config user.name "GitHub Actions"
git commit -m "Update APT repository - $COLLECTION_NAME ($RELEASE_TAG)"
git push -u origin gh-pages

success "GitHub Pages repository created!"

# Create client configuration script
cat > "$WORK_DIR/install-client.sh" << 'CLIENT_SCRIPT'
#!/bin/bash
# SecureOS GitHub APT Repository - Client Setup

GITHUB_REPO="__GITHUB_REPO__"
GITHUB_USER="$(echo $GITHUB_REPO | cut -d/ -f1)"
GITHUB_REPO_NAME="$(echo $GITHUB_REPO | cut -d/ -f2)"

echo "Setting up SecureOS GitHub APT repository..."

# Add repository
echo "deb [trusted=yes] https://${GITHUB_USER}.github.io/${GITHUB_REPO_NAME}/ ./" | sudo tee /etc/apt/sources.list.d/secureos-github.list

# Update
sudo apt update

echo "Repository added! Install packages with:"
echo "  sudo apt install <package-name>"
CLIENT_SCRIPT

sed -i "s|__GITHUB_REPO__|$GITHUB_REPO|g" "$WORK_DIR/install-client.sh"
chmod +x "$WORK_DIR/install-client.sh"

# Upload client script to release
gh release upload "$RELEASE_TAG" \
    --repo "$GITHUB_REPO" \
    --clobber \
    "$WORK_DIR/install-client.sh"

success "Setup complete!"
echo ""
log "Summary:"
echo "  Repository: https://github.com/$GITHUB_REPO"
echo "  Releases: https://github.com/$GITHUB_REPO/releases"
echo "  APT Repo: https://$(echo $GITHUB_REPO | cut -d/ -f1).github.io/$(echo $GITHUB_REPO | cut -d/ -f2)/"
echo ""
log "Client setup:"
echo "  curl -L https://github.com/$GITHUB_REPO/releases/download/$RELEASE_TAG/install-client.sh | sudo bash"
echo ""
log "Or manual:"
echo "  echo 'deb [trusted=yes] https://$(echo $GITHUB_REPO | cut -d/ -f1).github.io/$(echo $GITHUB_REPO | cut -d/ -f2)/ ./' | sudo tee /etc/apt/sources.list.d/secureos-github.list"
echo "  sudo apt update"

# Cleanup
rm -rf "$WORK_DIR" "$PAGES_DIR"
