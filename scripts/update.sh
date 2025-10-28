#!/bin/bash
#
# SecureOS Update Script
# Update SecureOS to the latest version
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}SecureOS Update Utility${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Backup first
echo -e "${YELLOW}[1/5] Creating backup...${NC}"
if [ -f scripts/backup.sh ]; then
    bash scripts/backup.sh
else
    echo "Backup script not found, skipping..."
fi

echo ""
echo -e "${YELLOW}[2/5] Updating repository...${NC}"
git fetch origin
git pull origin master

echo ""
echo -e "${YELLOW}[3/5] Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

echo ""
echo -e "${YELLOW}[4/5] Updating Python dependencies...${NC}"
if [ -f requirements.txt ]; then
    pip3 install --upgrade -r requirements.txt
fi

echo ""
echo -e "${YELLOW}[5/5] Running post-update checks...${NC}"
if [ -f scripts/test-suite.sh ]; then
    bash scripts/test-suite.sh || echo -e "${YELLOW}Some tests failed, but update completed${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Update completed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Current version: $(git describe --tags --always)"
echo ""
echo "To apply kernel changes, reboot is recommended:"
echo "  sudo reboot"
