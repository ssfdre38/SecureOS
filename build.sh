#!/bin/bash
set -e

echo "========================================="
echo "SecureOS Build Script"
echo "========================================="
echo ""

# Change to the project directory
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"
BUILD_OUTPUT="/mnt/projects/builds/packages"

echo "Project Directory: $PROJECT_DIR"
echo "Build Output: $BUILD_OUTPUT"
echo ""

# Create output directory
mkdir -p "$BUILD_OUTPUT"

# Check if we have the necessary tools
echo "Checking dependencies..."
command -v dpkg-deb >/dev/null 2>&1 || { echo "Error: dpkg-deb not found. Install it with: sudo apt install dpkg-dev"; exit 1; }

# Run the ISO build if available
if [ -f "iso/build-iso.sh" ]; then
    echo ""
    echo "Building SecureOS ISO..."
    cd iso
    bash build-iso.sh
    cd "$PROJECT_DIR"
fi

# Build packages if available
if [ -d "apt-repo" ]; then
    echo ""
    echo "Building SecureOS packages..."
    cd apt-repo
    
    # Build meta package
    if [ -d "secureos-meta_1.1.0" ]; then
        echo "Building secureos-meta..."
        dpkg-deb --build secureos-meta_1.1.0
        mv secureos-meta_1.1.0.deb "$BUILD_OUTPUT/" 2>/dev/null || true
    fi
    
    # Build tools package
    if [ -d "secureos-tools_1.1.0" ]; then
        echo "Building secureos-tools..."
        dpkg-deb --build secureos-tools_1.1.0
        mv secureos-tools_1.1.0.deb "$BUILD_OUTPUT/" 2>/dev/null || true
    fi
    
    cd "$PROJECT_DIR"
fi

# Update repository if setup exists
if [ -f "setup-repo.sh" ]; then
    echo ""
    echo "Updating SecureOS repository..."
    bash setup-repo.sh
fi

echo ""
echo "========================================="
echo "SecureOS Build Complete!"
echo "========================================="
echo ""
echo "Build artifacts:"
ls -lh "$BUILD_OUTPUT"/*.deb 2>/dev/null || echo "No .deb packages found"
echo ""
echo "Build finished at: $(date)"
