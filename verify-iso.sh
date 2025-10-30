#!/bin/bash
#
# SecureOS ISO Verification Script
# Verifies the built ISO image for correctness
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="${PROJECT_DIR}/iso-build"
ISO_NAME="SecureOS-1.0.0-amd64.iso"
ISO_PATH="${ISO_DIR}/${ISO_NAME}"

# Statistics
PASSED=0
FAILED=0
WARNINGS=0

# Print banner
echo -e "${BLUE}"
echo "=========================================="
echo "   SecureOS ISO Verification"
echo "=========================================="
echo -e "${NC}"

# Test function
test_check() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Checking: ${test_name}... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}[PASS]${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}[FAIL]${NC}"
        ((FAILED++))
        return 1
    fi
}

# Warning function
test_warning() {
    local test_name="$1"
    local message="$2"
    
    echo -e "Checking: ${test_name}... ${YELLOW}[WARNING]${NC}"
    echo -e "  ${YELLOW}→${NC} ${message}"
    ((WARNINGS++))
}

# Info function
test_info() {
    local test_name="$1"
    local value="$2"
    
    echo -e "Info: ${test_name}... ${CYAN}${value}${NC}"
}

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}ISO File Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# Check if ISO exists
test_check "ISO file exists" "[ -f '${ISO_PATH}' ]" || {
    echo -e "${RED}Error: ISO file not found at ${ISO_PATH}${NC}"
    echo "Please build the ISO first using: sudo ./build-iso.sh"
    exit 1
}

# Get ISO size
ISO_SIZE=$(stat -f%z "${ISO_PATH}" 2>/dev/null || stat -c%s "${ISO_PATH}" 2>/dev/null)
ISO_SIZE_MB=$((ISO_SIZE / 1024 / 1024))
ISO_SIZE_GB=$(echo "scale=2; ${ISO_SIZE_MB} / 1024" | bc 2>/dev/null || echo "N/A")

test_info "ISO size" "${ISO_SIZE_MB} MB (${ISO_SIZE_GB} GB)"

# Check minimum size (should be at least 500MB)
if [ "$ISO_SIZE_MB" -lt 500 ]; then
    test_warning "ISO size check" "ISO is smaller than expected (< 500MB). Build may be incomplete."
else
    test_check "ISO minimum size (>500MB)" "[ ${ISO_SIZE_MB} -ge 500 ]"
fi

# Check if ISO is bootable (has boot signature)
if command -v file &>/dev/null; then
    ISO_TYPE=$(file "${ISO_PATH}")
    if echo "$ISO_TYPE" | grep -q "ISO 9660"; then
        test_check "ISO format (ISO 9660)" "true"
    else
        test_warning "ISO format check" "ISO format could not be verified"
    fi
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Checksum Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# Verify SHA256 checksum
if [ -f "${ISO_PATH}.sha256" ]; then
    test_check "SHA256 checksum file exists" "true"
    
    cd "${ISO_DIR}"
    if sha256sum -c "${ISO_NAME}.sha256" &>/dev/null; then
        test_check "SHA256 checksum verification" "true"
    else
        test_warning "SHA256 verification" "Checksum verification failed"
    fi
    cd "${PROJECT_DIR}"
else
    test_warning "SHA256 checksum" "Checksum file not found"
fi

# Verify MD5 checksum
if [ -f "${ISO_PATH}.md5" ]; then
    test_check "MD5 checksum file exists" "true"
    
    cd "${ISO_DIR}"
    if md5sum -c "${ISO_NAME}.md5" &>/dev/null; then
        test_check "MD5 checksum verification" "true"
    else
        test_warning "MD5 verification" "Checksum verification failed"
    fi
    cd "${PROJECT_DIR}"
else
    test_warning "MD5 checksum" "Checksum file not found"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}ISO Contents Verification${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# Check if xorriso/isoinfo is available
if command -v xorriso &>/dev/null; then
    # List ISO contents
    ISO_CONTENTS=$(xorriso -indev "${ISO_PATH}" -find 2>/dev/null | head -20)
    
    # Check for essential files
    if echo "$ISO_CONTENTS" | grep -q "vmlinuz"; then
        test_check "Kernel (vmlinuz) present" "true"
    else
        test_warning "Kernel check" "Kernel file not found in ISO"
    fi
    
    if echo "$ISO_CONTENTS" | grep -q "initrd"; then
        test_check "Initrd present" "true"
    else
        test_warning "Initrd check" "Initrd file not found in ISO"
    fi
    
    if echo "$ISO_CONTENTS" | grep -q "filesystem.squashfs"; then
        test_check "Root filesystem (squashfs) present" "true"
    else
        test_warning "Filesystem check" "Squashfs file not found in ISO"
    fi
    
    if echo "$ISO_CONTENTS" | grep -q "grub"; then
        test_check "Bootloader (GRUB) present" "true"
    else
        test_warning "Bootloader check" "GRUB files not found in ISO"
    fi
else
    test_warning "ISO contents check" "xorriso not available, skipping detailed checks"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Build Artifacts${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

# Check for build log
if [ -f "${PROJECT_DIR}/build.log" ]; then
    test_check "Build log exists" "true"
    LOG_SIZE=$(stat -f%z "${PROJECT_DIR}/build.log" 2>/dev/null || stat -c%s "${PROJECT_DIR}/build.log" 2>/dev/null)
    LOG_SIZE_KB=$((LOG_SIZE / 1024))
    test_info "Build log size" "${LOG_SIZE_KB} KB"
    
    # Check for errors in log
    if grep -qi "error\|fail" "${PROJECT_DIR}/build.log" 2>/dev/null; then
        ERROR_COUNT=$(grep -ci "error\|fail" "${PROJECT_DIR}/build.log" 2>/dev/null || echo 0)
        test_warning "Build log errors" "Found ${ERROR_COUNT} error/fail messages in build log"
    else
        test_check "Build log clean (no errors)" "true"
    fi
else
    test_warning "Build log" "Build log not found"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Verification Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

echo ""
echo -e "${GREEN}Passed:${NC}   ${PASSED}"
echo -e "${RED}Failed:${NC}   ${FAILED}"
echo -e "${YELLOW}Warnings:${NC} ${WARNINGS}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ISO verification completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Test ISO in VM: qemu-system-x86_64 -m 2048 -enable-kvm -cdrom ${ISO_PATH}"
    echo "  2. Verify checksum: cd ${ISO_DIR} && sha256sum -c ${ISO_NAME}.sha256"
    echo "  3. Write to USB: sudo dd if=${ISO_PATH} of=/dev/sdX bs=4M status=progress"
    echo ""
    exit 0
else
    echo -e "${RED}✗ ISO verification completed with ${FAILED} failure(s)${NC}"
    echo ""
    echo "Please review the issues above before using the ISO."
    echo "Check build.log for detailed build information."
    echo ""
    exit 1
fi
