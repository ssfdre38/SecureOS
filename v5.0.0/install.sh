#!/bin/bash
#
# SecureOS v5.0.0 - Installation Script
# Install next-generation AI security features
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=================================================================="
echo "  SecureOS v5.0.0 - Next-Generation AI Security Platform"
echo "  Installation Script"
echo "=================================================================="
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}Error: Cannot detect operating system${NC}"
    exit 1
fi

echo -e "${GREEN}Detected OS: $OS $VER${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

PREREQS_MET=true

# Check Python 3.8+
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    PREREQS_MET=false
else
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}"
fi

# Check disk space (need ~5GB for ML models)
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
REQUIRED_SPACE=$((5 * 1024 * 1024)) # 5GB in KB

if [ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]; then
    echo -e "${RED}✗ Insufficient disk space (need 5GB)${NC}"
    PREREQS_MET=false
else
    echo -e "${GREEN}✓ Sufficient disk space${NC}"
fi

# Check RAM (need 4GB minimum for AI features)
TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
if [ $TOTAL_RAM -lt 4096 ]; then
    echo -e "${YELLOW}⚠ Warning: Less than 4GB RAM detected. AI features may be slow.${NC}"
else
    echo -e "${GREEN}✓ Sufficient RAM (${TOTAL_RAM}MB)${NC}"
fi

if [ "$PREREQS_MET" = false ]; then
    echo -e "\n${RED}Prerequisites not met. Please fix the issues above.${NC}"
    exit 1
fi

# Installation menu
echo -e "\n${BLUE}Select components to install:${NC}"
echo "1) All components (recommended)"
echo "2) AI Threat Detection only"
echo "3) Blockchain Audit only"
echo "4) Quantum Cryptography only"
echo "5) Self-Healing System only"
echo "6) Malware Sandbox only"
echo "7) Custom selection"

read -p "Choice [1-7]: " INSTALL_CHOICE

INSTALL_AI=false
INSTALL_BLOCKCHAIN=false
INSTALL_PQC=false
INSTALL_SELFHEAL=false
INSTALL_SANDBOX=false

case $INSTALL_CHOICE in
    1)
        INSTALL_AI=true
        INSTALL_BLOCKCHAIN=true
        INSTALL_PQC=true
        INSTALL_SELFHEAL=true
        INSTALL_SANDBOX=true
        ;;
    2) INSTALL_AI=true ;;
    3) INSTALL_BLOCKCHAIN=true ;;
    4) INSTALL_PQC=true ;;
    5) INSTALL_SELFHEAL=true ;;
    6) INSTALL_SANDBOX=true ;;
    7)
        read -p "Install AI Threat Detection? (y/n): " -n 1 -r && echo
        [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_AI=true
        
        read -p "Install Blockchain Audit? (y/n): " -n 1 -r && echo
        [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_BLOCKCHAIN=true
        
        read -p "Install Quantum Cryptography? (y/n): " -n 1 -r && echo
        [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_PQC=true
        
        read -p "Install Self-Healing System? (y/n): " -n 1 -r && echo
        [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_SELFHEAL=true
        
        read -p "Install Malware Sandbox? (y/n): " -n 1 -r && echo
        [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_SANDBOX=true
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Install base dependencies
echo -e "\n${YELLOW}Installing base dependencies...${NC}"
apt-get update -qq
apt-get install -y python3-pip python3-venv git curl wget build-essential \
    sqlite3 libsqlite3-dev jq

# Create SecureOS v5.0.0 directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p /opt/secureos/v5.0.0
mkdir -p /var/lib/secureos/{ai,blockchain,pqc,self-healing,sandbox}
mkdir -p /etc/secureos/v5
mkdir -p /var/log/secureos/v5

# Install Python packages
echo -e "${YELLOW}Installing Python dependencies...${NC}"

if [ "$INSTALL_AI" = true ] || [ "$INSTALL_BLOCKCHAIN" = true ] || \
   [ "$INSTALL_PQC" = true ] || [ "$INSTALL_SELFHEAL" = true ] || \
   [ "$INSTALL_SANDBOX" = true ]; then
    
    pip3 install --upgrade pip
    pip3 install numpy scipy
fi

# Install AI Threat Detection
if [ "$INSTALL_AI" = true ]; then
    echo -e "\n${GREEN}Installing AI Threat Detection Engine...${NC}"
    
    # Install ML libraries
    pip3 install tensorflow scikit-learn joblib pandas
    
    # Copy AI engine
    cp v5.0.0/ai-threat-detection/secureos-ai-engine.py /opt/secureos/v5.0.0/
    chmod +x /opt/secureos/v5.0.0/secureos-ai-engine.py
    ln -sf /opt/secureos/v5.0.0/secureos-ai-engine.py /usr/local/bin/secureos-ai
    
    echo -e "${GREEN}✓ AI Threat Detection installed${NC}"
fi

# Install Blockchain Audit
if [ "$INSTALL_BLOCKCHAIN" = true ]; then
    echo -e "\n${GREEN}Installing Blockchain Audit System...${NC}"
    
    # Copy blockchain engine
    cp v5.0.0/blockchain-audit/secureos-blockchain.py /opt/secureos/v5.0.0/
    chmod +x /opt/secureos/v5.0.0/secureos-blockchain.py
    ln -sf /opt/secureos/v5.0.0/secureos-blockchain.py /usr/local/bin/secureos-blockchain
    
    # Initialize blockchain
    /usr/local/bin/secureos-blockchain init
    
    echo -e "${GREEN}✓ Blockchain Audit System installed${NC}"
fi

# Install Quantum Cryptography
if [ "$INSTALL_PQC" = true ]; then
    echo -e "\n${GREEN}Installing Post-Quantum Cryptography...${NC}"
    
    # Note: In production, install liboqs and liboqs-python
    # pip3 install liboqs-python
    
    # Copy PQC engine
    cp v5.0.0/quantum-crypto/secureos-pqc.py /opt/secureos/v5.0.0/
    chmod +x /opt/secureos/v5.0.0/secureos-pqc.py
    ln -sf /opt/secureos/v5.0.0/secureos-pqc.py /usr/local/bin/secureos-pqc
    
    # Initialize PQC
    /usr/local/bin/secureos-pqc init
    
    echo -e "${GREEN}✓ Post-Quantum Cryptography installed${NC}"
fi

# Install Self-Healing System
if [ "$INSTALL_SELFHEAL" = true ]; then
    echo -e "\n${GREEN}Installing Self-Healing Security System...${NC}"
    
    # Copy self-healing engine
    cp v5.0.0/self-healing/secureos-self-healing.py /opt/secureos/v5.0.0/
    chmod +x /opt/secureos/v5.0.0/secureos-self-healing.py
    ln -sf /opt/secureos/v5.0.0/secureos-self-healing.py /usr/local/bin/secureos-heal
    
    # Create systemd service for auto-healing
    cat > /etc/systemd/system/secureos-self-healing.service << EOF
[Unit]
Description=SecureOS Self-Healing Security System
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/secureos-heal heal
Restart=always
RestartSec=3600

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Self-Healing System installed${NC}"
    echo -e "${YELLOW}  To enable auto-healing: systemctl enable --now secureos-self-healing${NC}"
fi

# Install Malware Sandbox
if [ "$INSTALL_SANDBOX" = true ]; then
    echo -e "\n${GREEN}Installing Malware Sandbox...${NC}"
    
    # Install sandbox dependencies
    apt-get install -y firejail docker.io qemu-system-x86
    
    # Copy sandbox engine
    cp v5.0.0/malware-sandbox/secureos-sandbox.py /opt/secureos/v5.0.0/
    chmod +x /opt/secureos/v5.0.0/secureos-sandbox.py
    ln -sf /opt/secureos/v5.0.0/secureos-sandbox.py /usr/local/bin/secureos-sandbox
    
    echo -e "${GREEN}✓ Malware Sandbox installed${NC}"
fi

# Create unified CLI
echo -e "\n${YELLOW}Creating unified SecureOS CLI...${NC}"
cat > /usr/local/bin/secureos << 'EOF'
#!/bin/bash
# SecureOS v5.0.0 Unified CLI

case "$1" in
    ai)
        shift
        secureos-ai "$@"
        ;;
    blockchain)
        shift
        secureos-blockchain "$@"
        ;;
    pqc|quantum)
        shift
        secureos-pqc "$@"
        ;;
    heal|self-heal)
        shift
        secureos-heal "$@"
        ;;
    sandbox)
        shift
        secureos-sandbox "$@"
        ;;
    version)
        echo "SecureOS v5.0.0 - Next-Generation AI Security Platform"
        ;;
    *)
        echo "SecureOS v5.0.0 - Unified Security CLI"
        echo ""
        echo "Usage: secureos <component> <command> [options]"
        echo ""
        echo "Components:"
        echo "  ai         - AI Threat Detection Engine"
        echo "  blockchain - Blockchain Audit System"
        echo "  pqc        - Post-Quantum Cryptography"
        echo "  heal       - Self-Healing Security System"
        echo "  sandbox    - Malware Sandbox"
        echo ""
        echo "Examples:"
        echo "  secureos ai status"
        echo "  secureos blockchain verify"
        echo "  secureos pqc keygen --algorithm kyber-1024 --key-id my-key"
        echo "  secureos heal scan"
        echo "  secureos sandbox analyze --file suspicious.exe"
        ;;
esac
EOF

chmod +x /usr/local/bin/secureos

# Installation complete
echo -e "\n${BLUE}"
echo "=================================================================="
echo "  SecureOS v5.0.0 Installation Complete!"
echo "=================================================================="
echo -e "${NC}"

echo -e "\n${GREEN}Installed Components:${NC}"
[ "$INSTALL_AI" = true ] && echo "  ✓ AI Threat Detection"
[ "$INSTALL_BLOCKCHAIN" = true ] && echo "  ✓ Blockchain Audit System"
[ "$INSTALL_PQC" = true ] && echo "  ✓ Post-Quantum Cryptography"
[ "$INSTALL_SELFHEAL" = true ] && echo "  ✓ Self-Healing Security System"
[ "$INSTALL_SANDBOX" = true ] && echo "  ✓ Malware Sandbox"

echo -e "\n${YELLOW}Quick Start:${NC}"
echo "  secureos version          - Show version"
echo "  secureos ai status        - Check AI engine status"
echo "  secureos blockchain stats - View blockchain stats"
echo "  secureos pqc list         - List PQC algorithms"
echo "  secureos heal scan        - Scan for security issues"
echo "  secureos sandbox list     - List malware analyses"

echo -e "\n${YELLOW}Documentation:${NC}"
echo "  /opt/secureos/v5.0.0/README.md"
echo "  https://secureos.xyz/docs/v5.0.0"

echo -e "\n${GREEN}Installation log: /var/log/secureos/v5/install.log${NC}"
echo ""
