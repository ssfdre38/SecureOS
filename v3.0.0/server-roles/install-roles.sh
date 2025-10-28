#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# SecureOS v3.0.0 - Server Role Installer
# Installs selected server roles with pre-configured security

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[*]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Read configuration
if [ ! -f /tmp/secureos-install-config.txt ]; then
    error "Configuration file not found!"
    exit 1
fi

source /tmp/secureos-install-config.txt

log "Installing server roles: $SERVER_ROLES"

# Base installation (always included)
install_base() {
    log "Installing base server packages..."
    apt-get update
    apt-get install -y \
        vim nano git curl wget \
        htop iotop nethogs \
        net-tools dnsutils \
        ufw fail2ban \
        unattended-upgrades \
        apt-transport-https \
        ca-certificates \
        gnupg lsb-release
    
    # Configure firewall
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp comment 'SSH'
    
    success "Base server installed"
}

# Web hosting role
install_web() {
    log "Installing web hosting stack..."
    
    # Install nginx, Apache, PHP, MySQL
    apt-get install -y \
        nginx apache2 \
        php8.3-fpm php8.3-cli php8.3-mysql php8.3-curl \
        php8.3-gd php8.3-mbstring php8.3-xml php8.3-zip \
        mysql-server mysql-client \
        certbot python3-certbot-nginx
    
    # Disable Apache by default (use nginx)
    systemctl stop apache2
    systemctl disable apache2
    
    # Configure nginx
    cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX
    
    systemctl restart nginx
    systemctl restart php8.3-fpm
    
    # Secure MySQL
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'changeme';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Allow HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    success "Web hosting stack installed"
    log "MySQL root password set to: changeme (CHANGE THIS!)"
}

# VPN server role
install_vpn() {
    log "Installing VPN server..."
    
    apt-get install -y wireguard wireguard-tools openvpn easy-rsa
    
    # Generate WireGuard keys
    mkdir -p /etc/wireguard
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    chmod 600 /etc/wireguard/server_private.key
    
    PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
    
    # Create WireGuard config
    cat > /etc/wireguard/wg0.conf << WGCONF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
WGCONF
    
    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p
    
    # Firewall rules
    ufw allow 51820/udp comment 'WireGuard'
    ufw allow 1194/udp comment 'OpenVPN'
    
    success "VPN server installed"
    log "WireGuard config: /etc/wireguard/wg0.conf"
    log "Start with: systemctl start wg-quick@wg0"
}

# Development environment
install_dev() {
    log "Installing development environment..."
    
    apt-get install -y \
        build-essential \
        python3 python3-pip python3-venv \
        nodejs npm \
        golang-go \
        git git-lfs \
        docker.io docker-compose \
        postgresql-client \
        redis-tools
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    systemctl enable docker
    systemctl start docker
    
    success "Development environment installed"
}

# VS Code Server (web-based IDE)
install_vscode_web() {
    log "Installing VS Code Server..."
    
    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Create systemd service
    cat > /etc/systemd/system/code-server.service << 'CODESERVER'
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=secureos
WorkingDirectory=/home/secureos
Environment="PASSWORD=changeme"
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth password
Restart=always

[Install]
WantedBy=multi-user.target
CODESERVER
    
    systemctl daemon-reload
    systemctl enable code-server
    systemctl start code-server
    
    ufw allow 8080/tcp comment 'VS Code Server'
    
    success "VS Code Server installed"
    log "Access at: http://YOUR_IP:8080"
    log "Password: changeme (CHANGE THIS in /etc/systemd/system/code-server.service)"
}

# File server with ZFS
install_file() {
    log "Installing file server..."
    
    apt-get install -y \
        samba samba-common-bin \
        nfs-kernel-server \
        zfsutils-linux
    
    # Configure Samba
    cat >> /etc/samba/smb.conf << 'SAMBA'

[shared]
    path = /srv/samba/shared
    browseable = yes
    read only = no
    guest ok = no
    create mask = 0644
    directory mask = 0755
SAMBA
    
    mkdir -p /srv/samba/shared
    chmod 2770 /srv/samba/shared
    
    # NFS exports
    cat > /etc/exports << 'NFS'
/srv/nfs    *(rw,sync,no_subtree_check,no_root_squash)
NFS
    
    mkdir -p /srv/nfs
    exportfs -ra
    
    # Firewall
    ufw allow 445/tcp comment 'Samba'
    ufw allow 139/tcp comment 'Samba'
    ufw allow 2049/tcp comment 'NFS'
    
    systemctl restart smbd nmbd nfs-server
    
    success "File server installed"
    log "Samba share: //YOUR_IP/shared"
    log "NFS export: YOUR_IP:/srv/nfs"
}

# ZFS Web Interface (Cockpit)
install_zfs_web() {
    log "Installing ZFS web interface..."
    
    apt-get install -y \
        cockpit cockpit-storaged \
        zfsutils-linux
    
    # Install Cockpit ZFS plugin
    git clone https://github.com/optimans/cockpit-zfs-manager.git /tmp/cockpit-zfs
    cp -r /tmp/cockpit-zfs/zfs /usr/share/cockpit/
    
    systemctl enable cockpit.socket
    systemctl start cockpit.socket
    
    ufw allow 9090/tcp comment 'Cockpit'
    
    success "ZFS web interface installed"
    log "Access Cockpit at: https://YOUR_IP:9090"
}

# Mail server
install_mail() {
    log "Installing mail server..."
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        postfix dovecot-core dovecot-imapd dovecot-pop3d \
        opendkim opendkim-tools
    
    # Basic Postfix config
    postconf -e 'myhostname = mail.secureos.local'
    postconf -e 'mydestination = $myhostname, localhost.$mydomain, localhost'
    postconf -e 'inet_interfaces = all'
    
    # Firewall
    ufw allow 25/tcp comment 'SMTP'
    ufw allow 587/tcp comment 'Submission'
    ufw allow 993/tcp comment 'IMAPS'
    ufw allow 995/tcp comment 'POP3S'
    
    systemctl restart postfix dovecot
    
    success "Mail server installed"
    warn "Further configuration required for production use!"
}

# Database server
install_database() {
    log "Installing database servers..."
    
    apt-get install -y \
        postgresql postgresql-contrib \
        mysql-server \
        redis-server
    
    # Configure PostgreSQL to listen on all interfaces
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
    
    # Allow remote connections
    echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf
    
    systemctl restart postgresql mysql redis-server
    
    # Firewall
    ufw allow 5432/tcp comment 'PostgreSQL'
    ufw allow 3306/tcp comment 'MySQL'
    ufw allow 6379/tcp comment 'Redis'
    
    success "Database servers installed"
    log "PostgreSQL, MySQL, and Redis are running"
}

# Monitoring stack
install_monitoring() {
    log "Installing monitoring stack..."
    
    # Install Prometheus
    wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-*-linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
    tar xzf /tmp/prometheus.tar.gz -C /opt/
    mv /opt/prometheus-* /opt/prometheus
    
    # Install Grafana
    apt-get install -y apt-transport-https software-properties-common
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update
    apt-get install -y grafana
    
    # Install Node Exporter
    apt-get install -y prometheus-node-exporter
    
    systemctl enable grafana-server
    systemctl start grafana-server
    
    ufw allow 3000/tcp comment 'Grafana'
    ufw allow 9090/tcp comment 'Prometheus'
    ufw allow 9100/tcp comment 'Node Exporter'
    
    success "Monitoring stack installed"
    log "Grafana: http://YOUR_IP:3000 (admin/admin)"
}

# Container host
install_container() {
    log "Installing container platform..."
    
    apt-get install -y \
        docker.io docker-compose \
        containerd
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Install k3s (lightweight Kubernetes)
    curl -sfL https://get.k3s.io | sh -
    
    systemctl enable docker containerd
    systemctl start docker containerd
    
    success "Container platform installed"
    log "Docker and k3s (Kubernetes) are ready"
}

# Backup server
install_backup() {
    log "Installing backup server..."
    
    apt-get install -y \
        bacula-server bacula-client \
        rsync \
        borgbackup
    
    mkdir -p /backup
    
    success "Backup server installed"
    log "Backup directory: /backup"
}

# Main installation
if [[ $INSTALL_TYPE == "server" ]]; then
    log "Starting server role installation..."
    
    for role in ${SERVER_ROLES//,/ }; do
        case $role in
            base) install_base ;;
            web) install_web ;;
            vpn) install_vpn ;;
            dev) install_dev ;;
            vscode-web) install_vscode_web ;;
            file) install_file ;;
            zfs-web) install_zfs_web ;;
            mail) install_mail ;;
            database) install_database ;;
            monitoring) install_monitoring ;;
            container) install_container ;;
            backup) install_backup ;;
            *) warn "Unknown role: $role" ;;
        esac
    done
    
    success "All server roles installed successfully!"
    echo ""
    log "Server is ready! Check the logs above for access details."
    log "Remember to change default passwords!"
else
    log "Desktop installation - no server roles to install"
fi
