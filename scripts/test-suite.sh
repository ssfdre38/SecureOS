#!/bin/bash
#
# SecureOS v5.0.0 Test Suite
# Comprehensive testing for all components
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         SecureOS v5.0.0 Test Suite                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "Testing: $test_name ... "
    
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

skip_test() {
    local test_name="$1"
    echo -e "Testing: $test_name ... ${YELLOW}SKIP${NC}"
    ((SKIPPED++))
}

echo -e "${BLUE}[Base System Tests]${NC}"
run_test "Python 3 installed" "command -v python3"
run_test "Git installed" "command -v git"
run_test "SQLite installed" "command -v sqlite3"
run_test "Sufficient RAM (4GB+)" "[ \$(free -g | awk 'NR==2{print \$2}') -ge 4 ]"
echo ""

echo -e "${BLUE}[Security Tools Tests]${NC}"
run_test "UFW installed" "command -v ufw"
run_test "Fail2ban installed" "command -v fail2ban-client"
run_test "AppArmor installed" "command -v apparmor_status"
run_test "Auditd installed" "command -v auditctl"
run_test "ClamAV installed" "command -v clamscan"
echo ""

echo -e "${BLUE}[v5.0.0 Components]${NC}"

# AI Engine Tests
if [ -f /usr/local/bin/secureos-ai ]; then
    run_test "AI engine executable" "[ -x /usr/local/bin/secureos-ai ]"
    run_test "AI status command" "/usr/local/bin/secureos-ai status"
    run_test "AI models directory" "[ -d /var/lib/secureos/ai ]"
    
    # Test AI functionality
    if python3 -c "import tensorflow, sklearn" 2>/dev/null; then
        run_test "AI dependencies installed" "true"
        run_test "AI test command" "/usr/local/bin/secureos-ai test"
    else
        skip_test "AI dependencies (not installed)"
    fi
else
    skip_test "AI engine (not installed)"
fi
echo ""

# Blockchain Tests
if [ -f /usr/local/bin/secureos-blockchain ]; then
    run_test "Blockchain executable" "[ -x /usr/local/bin/secureos-blockchain ]"
    run_test "Blockchain directory" "[ -d /var/lib/secureos/blockchain ]"
    
    # Test blockchain functionality
    if [ -f /var/lib/secureos/blockchain/audit.db ]; then
        run_test "Blockchain database exists" "true"
        run_test "Blockchain stats command" "/usr/local/bin/secureos-blockchain stats"
        run_test "Blockchain verify command" "/usr/local/bin/secureos-blockchain verify"
    else
        skip_test "Blockchain database (not initialized)"
    fi
else
    skip_test "Blockchain audit (not installed)"
fi
echo ""

# PQC Tests
if [ -f /usr/local/bin/secureos-pqc ]; then
    run_test "PQC executable" "[ -x /usr/local/bin/secureos-pqc ]"
    run_test "PQC directory" "[ -d /var/lib/secureos/pqc ]"
    run_test "PQC list command" "/usr/local/bin/secureos-pqc list"
    run_test "PQC init command" "/usr/local/bin/secureos-pqc init"
else
    skip_test "Quantum crypto (not installed)"
fi
echo ""

# Self-Healing Tests
if [ -f /usr/local/bin/secureos-heal ]; then
    run_test "Self-healing executable" "[ -x /usr/local/bin/secureos-heal ]"
    run_test "Self-healing directory" "[ -d /var/lib/secureos/self-healing ]"
    run_test "Self-healing config command" "/usr/local/bin/secureos-heal config"
    run_test "Self-healing status command" "/usr/local/bin/secureos-heal status"
    
    # Test service
    if [ -f /etc/systemd/system/secureos-self-healing.service ]; then
        run_test "Self-healing service file exists" "true"
    else
        skip_test "Self-healing service (not configured)"
    fi
else
    skip_test "Self-healing (not installed)"
fi
echo ""

# Sandbox Tests
if [ -f /usr/local/bin/secureos-sandbox ]; then
    run_test "Sandbox executable" "[ -x /usr/local/bin/secureos-sandbox ]"
    run_test "Sandbox directory" "[ -d /var/lib/secureos/sandbox ]"
    run_test "Sandbox list command" "/usr/local/bin/secureos-sandbox list"
else
    skip_test "Malware sandbox (not installed)"
fi
echo ""

# Unified CLI Tests
if [ -f /usr/local/bin/secureos ]; then
    run_test "Unified CLI installed" "[ -x /usr/local/bin/secureos ]"
    run_test "Unified CLI version command" "/usr/local/bin/secureos version"
else
    skip_test "Unified CLI (not installed)"
fi
echo ""

echo -e "${BLUE}[Configuration Tests]${NC}"
run_test "Config directory exists" "[ -d /etc/secureos ]"
run_test "Data directory exists" "[ -d /var/lib/secureos ]"
run_test "Logs directory exists" "[ -d /var/log/secureos ]"
echo ""

echo -e "${BLUE}[Security Configuration Tests]${NC}"
if [ -f /etc/sysctl.d/99-secureos-hardening.conf ]; then
    run_test "Kernel hardening config exists" "true"
    run_test "IP forwarding disabled" "[ \$(sysctl -n net.ipv4.ip_forward) -eq 0 ]"
    run_test "Source routing disabled" "[ \$(sysctl -n net.ipv4.conf.all.accept_source_route) -eq 0 ]"
else
    skip_test "Kernel hardening (not configured)"
fi

if command -v ufw &> /dev/null; then
    run_test "UFW firewall enabled" "ufw status | grep -q 'Status: active'"
else
    skip_test "UFW firewall (not installed)"
fi
echo ""

echo -e "${BLUE}[File Integrity Tests]${NC}"
run_test "Install script exists" "[ -f /home/ubuntu/SecureOS/v5.0.0/install.sh ]"
run_test "Install script executable" "[ -x /home/ubuntu/SecureOS/v5.0.0/install.sh ]"
run_test "README exists" "[ -f /home/ubuntu/SecureOS/v5.0.0/README.md ]"
run_test "QUICKSTART exists" "[ -f /home/ubuntu/SecureOS/v5.0.0/QUICKSTART.md ]"
run_test "CHANGELOG exists" "[ -f /home/ubuntu/SecureOS/v5.0.0/CHANGELOG.md ]"
echo ""

echo -e "${BLUE}[Documentation Tests]${NC}"
run_test "Main README exists" "[ -f /home/ubuntu/SecureOS/README.md ]"
run_test "v5.0.0 README exists" "[ -f /home/ubuntu/SecureOS/v5.0.0/README.md ]"
run_test "Quick reference exists" "[ -f /home/ubuntu/SECUREOS_V5_QUICK_REFERENCE.txt ]"
echo ""

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""

TOTAL=$((PASSED + FAILED + SKIPPED))
if [ $TOTAL -gt 0 ]; then
    SUCCESS_RATE=$((PASSED * 100 / (PASSED + FAILED)))
    echo "Success Rate: ${SUCCESS_RATE}%"
fi

echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
