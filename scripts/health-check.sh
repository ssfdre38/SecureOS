#!/bin/bash
#
# SecureOS System Health Monitor
# Comprehensive system health check and reporting
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          SecureOS System Health Monitor v5.0.0            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# System Information
echo -e "${GREEN}[System Information]${NC}"
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# CPU and Memory
echo -e "${GREEN}[CPU & Memory]${NC}"
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY_TOTAL=$(free -h | awk 'NR==2{print $2}')
MEMORY_USED=$(free -h | awk 'NR==2{print $3}')
MEMORY_PERCENT=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')

echo "CPU Usage: ${CPU_USAGE}%"
echo "Memory: ${MEMORY_USED}/${MEMORY_TOTAL} (${MEMORY_PERCENT}%)"
echo ""

# Disk Usage
echo -e "${GREEN}[Disk Usage]${NC}"
df -h | grep -E '^/dev/' | awk '{printf "%-20s %5s / %5s (%s)\n", $1, $3, $2, $5}'
echo ""

# Security Services Status
echo -e "${GREEN}[Security Services]${NC}"
check_service() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 is running"
    else
        echo -e "  ${RED}✗${NC} $1 is not running"
    fi
}

check_service "ufw"
check_service "fail2ban"
check_service "apparmor"
check_service "auditd"
check_service "clamav-freshclam"

# Check v5.0.0 services if installed
if [ -f /usr/local/bin/secureos ]; then
    echo -e "${GREEN}[v5.0.0 Components]${NC}"
    
    if [ -f /usr/local/bin/secureos-ai ]; then
        echo -e "  ${GREEN}✓${NC} AI Threat Detection installed"
    fi
    
    if [ -f /usr/local/bin/secureos-blockchain ]; then
        echo -e "  ${GREEN}✓${NC} Blockchain Audit installed"
    fi
    
    if [ -f /usr/local/bin/secureos-pqc ]; then
        echo -e "  ${GREEN}✓${NC} Quantum Cryptography installed"
    fi
    
    if [ -f /usr/local/bin/secureos-heal ]; then
        echo -e "  ${GREEN}✓${NC} Self-Healing installed"
        check_service "secureos-self-healing"
    fi
    
    if [ -f /usr/local/bin/secureos-sandbox ]; then
        echo -e "  ${GREEN}✓${NC} Malware Sandbox installed"
    fi
fi
echo ""

# Firewall Status
echo -e "${GREEN}[Firewall Rules]${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    echo "$UFW_STATUS"
    echo "Active rules: $(ufw status numbered 2>/dev/null | grep -c '\[')"
else
    echo -e "${RED}UFW not installed${NC}"
fi
echo ""

# Failed Login Attempts
echo -e "${GREEN}[Security Events]${NC}"
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
echo "Failed login attempts (recent): $FAILED_LOGINS"

if command -v fail2ban-client &> /dev/null; then
    BANNED_IPS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*://;s/\s//g' | tr ',' '\n' | wc -l)
    echo "Fail2ban banned IPs: $BANNED_IPS"
fi
echo ""

# Updates Available
echo -e "${GREEN}[System Updates]${NC}"
if [ -f /var/lib/apt/lists/lock ]; then
    echo "Checking for updates..."
    apt-get update -qq 2>/dev/null || true
fi

UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)

if [ "$UPDATES" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} $UPDATES updates available ($SECURITY_UPDATES security updates)"
else
    echo -e "${GREEN}✓${NC} System is up to date"
fi
echo ""

# Blockchain Integrity (if installed)
if [ -f /usr/local/bin/secureos-blockchain ]; then
    echo -e "${GREEN}[Blockchain Audit Status]${NC}"
    if [ -f /var/lib/secureos/blockchain/audit.db ]; then
        BLOCKS=$(sqlite3 /var/lib/secureos/blockchain/audit.db "SELECT COUNT(*) FROM blocks" 2>/dev/null || echo "0")
        echo "Total blocks: $BLOCKS"
        
        # Verify integrity
        /usr/local/bin/secureos-blockchain verify &>/dev/null && \
            echo -e "${GREEN}✓${NC} Blockchain integrity verified" || \
            echo -e "${RED}✗${NC} Blockchain integrity check failed"
    else
        echo "Blockchain not initialized"
    fi
    echo ""
fi

# AI Threat Detection (if installed)
if [ -f /usr/local/bin/secureos-ai ]; then
    echo -e "${GREEN}[AI Threat Detection Status]${NC}"
    if [ -d /var/lib/secureos/ai/models ]; then
        MODEL_COUNT=$(find /var/lib/secureos/ai/models -name "*.pkl" 2>/dev/null | wc -l)
        echo "ML models loaded: $MODEL_COUNT"
    else
        echo "AI engine not trained yet"
    fi
    echo ""
fi

# Network Connections
echo -e "${GREEN}[Active Network Connections]${NC}"
ESTABLISHED=$(ss -tan | grep ESTAB | wc -l)
LISTENING=$(ss -tln | grep LISTEN | wc -l)
echo "Established connections: $ESTABLISHED"
echo "Listening ports: $LISTENING"
echo ""

# Recent Security Logs
echo -e "${GREEN}[Recent Security Events (last 24h)]${NC}"
if [ -f /var/log/auth.log ]; then
    echo "Authentication events:"
    grep -i "authentication failure" /var/log/auth.log | tail -3 || echo "  No authentication failures"
fi
echo ""

# Disk Health
echo -e "${GREEN}[Disk Health]${NC}"
if command -v smartctl &> /dev/null; then
    for disk in $(lsblk -d -n -o NAME | grep -E '^sd|^nvme'); do
        HEALTH=$(smartctl -H /dev/$disk 2>/dev/null | grep "PASSED" || echo "SMART not available")
        echo "/dev/$disk: $HEALTH"
    done
else
    echo "smartmontools not installed (install: apt install smartmontools)"
fi
echo ""

# Overall Health Score
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Health Summary                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

SCORE=100

# Deduct points for issues
[ "$UPDATES" -gt 10 ] && SCORE=$((SCORE - 10))
[ "$SECURITY_UPDATES" -gt 0 ] && SCORE=$((SCORE - 15))
[ "$FAILED_LOGINS" -gt 50 ] && SCORE=$((SCORE - 10))
[ "$(echo "$MEMORY_PERCENT > 90" | bc)" -eq 1 ] && SCORE=$((SCORE - 10))
[ "$(echo "$CPU_USAGE > 80" | bc)" -eq 1 ] && SCORE=$((SCORE - 10))

systemctl is-active --quiet ufw || SCORE=$((SCORE - 20))
systemctl is-active --quiet fail2ban || SCORE=$((SCORE - 5))

if [ "$SCORE" -ge 90 ]; then
    echo -e "${GREEN}Overall Health: $SCORE/100 - Excellent${NC}"
elif [ "$SCORE" -ge 70 ]; then
    echo -e "${YELLOW}Overall Health: $SCORE/100 - Good${NC}"
elif [ "$SCORE" -ge 50 ]; then
    echo -e "${YELLOW}Overall Health: $SCORE/100 - Fair (action recommended)${NC}"
else
    echo -e "${RED}Overall Health: $SCORE/100 - Poor (immediate action required)${NC}"
fi

echo ""
echo "Report generated: $(date)"
echo ""
