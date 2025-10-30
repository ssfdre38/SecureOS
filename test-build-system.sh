#!/bin/bash
#
# SecureOS Build System Test Script
# Tests the build system setup without requiring root access
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

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASSED=0
FAILED=0

echo -e "${BLUE}"
echo "=========================================="
echo "   SecureOS Build System Tests"
echo "=========================================="
echo -e "${NC}"
echo "Project Directory: ${PROJECT_DIR}"
echo ""

# Test function
test_check() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: ${test_name}... "
    
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

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Build Script Files${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "Main build script exists" "[ -f '${PROJECT_DIR}/build-iso.sh' ]"
test_check "Main build script is executable" "[ -x '${PROJECT_DIR}/build-iso.sh' ]"
test_check "Standard build script exists" "[ -f '${PROJECT_DIR}/scripts/build_iso.sh' ]"
test_check "Fast build script exists" "[ -f '${PROJECT_DIR}/scripts/build_iso_fast.sh' ]"
test_check "Verify script exists" "[ -f '${PROJECT_DIR}/verify-iso.sh' ]"
test_check "Verify script is executable" "[ -x '${PROJECT_DIR}/verify-iso.sh' ]"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Build Script Syntax${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "Main build script syntax" "bash -n '${PROJECT_DIR}/build-iso.sh'"
test_check "Standard build script syntax" "bash -n '${PROJECT_DIR}/scripts/build_iso.sh'"
test_check "Fast build script syntax" "bash -n '${PROJECT_DIR}/scripts/build_iso_fast.sh'"
test_check "Verify script syntax" "bash -n '${PROJECT_DIR}/verify-iso.sh'"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}No Hard-Coded Paths${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "No /home/ubuntu paths in build-iso.sh" "! grep -q '/home/ubuntu' '${PROJECT_DIR}/build-iso.sh'"
test_check "No /home/ubuntu paths in build_iso.sh" "! grep -q '/home/ubuntu' '${PROJECT_DIR}/scripts/build_iso.sh'"
test_check "No /home/ubuntu paths in build_iso_fast.sh" "! grep -q '/home/ubuntu' '${PROJECT_DIR}/scripts/build_iso_fast.sh'"
test_check "No /mnt/projects paths in build.sh" "! grep -q '/mnt/projects' '${PROJECT_DIR}/build.sh'"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Documentation Files${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "BUILD.md exists" "[ -f '${PROJECT_DIR}/BUILD.md' ]"
test_check "README.md exists" "[ -f '${PROJECT_DIR}/README.md' ]"
test_check "Scripts README exists" "[ -f '${PROJECT_DIR}/scripts/README.md' ]"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}CI/CD Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "GitHub Actions workflow exists" "[ -f '${PROJECT_DIR}/.github/workflows/build-iso.yml' ]"
test_check "Workflow uses build-iso.sh" "grep -q './build-iso.sh' '${PROJECT_DIR}/.github/workflows/build-iso.yml'"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}v5.0.0 Security Features${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "v5.0.0 directory exists" "[ -d '${PROJECT_DIR}/v5.0.0' ]"
test_check "Quantum crypto module exists" "[ -f '${PROJECT_DIR}/v5.0.0/quantum-crypto/secureos-pqc.py' ]"
test_check "Blockchain audit module exists" "[ -f '${PROJECT_DIR}/v5.0.0/blockchain-audit/secureos-blockchain.py' ]"
test_check "AI threat detection exists" "[ -f '${PROJECT_DIR}/v5.0.0/ai-threat-detection/secureos-ai-engine.py' ]"
test_check "Self-healing module exists" "[ -f '${PROJECT_DIR}/v5.0.0/self-healing/secureos-self-healing.py' ]"
test_check "Malware sandbox exists" "[ -f '${PROJECT_DIR}/v5.0.0/malware-sandbox/secureos-sandbox.py' ]"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Configuration Files${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "Config directory exists" "[ -d '${PROJECT_DIR}/config' ]"
test_check "Security defaults config exists" "[ -f '${PROJECT_DIR}/config/security-defaults.conf' ]"
test_check ".gitignore exists" "[ -f '${PROJECT_DIR}/.gitignore' ]"
test_check "Build output in .gitignore" "grep -q 'build-output' '${PROJECT_DIR}/.gitignore'"
test_check "ISO build dir in .gitignore" "grep -q 'iso-build' '${PROJECT_DIR}/.gitignore'"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Build Script Features${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

test_check "Dynamic PROJECT_DIR in build-iso.sh" "grep -q 'PROJECT_DIR=.*dirname' '${PROJECT_DIR}/build-iso.sh'"
test_check "Dependency checking in build-iso.sh" "grep -q 'check_dependencies' '${PROJECT_DIR}/build-iso.sh'"
test_check "Error handling in build-iso.sh" "grep -q 'error_exit' '${PROJECT_DIR}/build-iso.sh'"
test_check "Logging functionality in build-iso.sh" "grep -q 'log_success' '${PROJECT_DIR}/build-iso.sh'"
test_check "v5.0.0 features copy in build-iso.sh" "grep -q 'copy_security_features' '${PROJECT_DIR}/build-iso.sh'"

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Test Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

echo ""
echo -e "${GREEN}Passed:${NC}  ${PASSED}"
echo -e "${RED}Failed:${NC}  ${FAILED}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Build system is properly configured.${NC}"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Review BUILD.md for build instructions"
    echo "  2. Run build: sudo ./build-iso.sh"
    echo "  3. Verify ISO: ./verify-iso.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the issues above.${NC}"
    echo ""
    exit 1
fi
