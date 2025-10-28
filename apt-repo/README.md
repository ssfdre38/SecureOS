# APT Repository & Package Mirroring

This directory contains tools for managing APT repositories and package mirrors.

## Overview

SecureOS provides two approaches for package management:

1. **Custom Repository** - Host your own SecureOS packages
2. **Ubuntu Mirror** - Mirror Ubuntu 24.04 packages locally

## Scripts

### 1. setup-repo.sh
Creates a custom APT repository for SecureOS packages.

**Features:**
- GPG package signing
- reprepro management
- nginx web server
- Custom package hosting

**Usage:**
```bash
sudo bash apt-repo/setup-repo.sh
```

### 2. mirror-ubuntu-packages.sh (NEW!)
Mirror Ubuntu 24.04 packages for offline/local use.

**Three Mirror Types:**

#### Full Mirror (100-150 GB)
- Complete Ubuntu archive
- All packages and versions
- Perfect for enterprise/airgapped networks
- Takes 2-8 hours to download

```bash
sudo bash apt-repo/mirror-ubuntu-packages.sh
# Select option 1 (Full)
```

#### Selective Mirror (10-50 GB)
- Main, restricted, and universe components
- Excludes less common packages
- Good balance of size vs coverage
- Takes 1-3 hours to download

```bash
sudo bash apt-repo/mirror-ubuntu-packages.sh
# Select option 2 (Selective)
```

#### Minimal Mirror (2-5 GB)
- Security essentials only
- Pre-selected important packages
- Fast to download and deploy
- Takes 10-30 minutes

```bash
sudo bash apt-repo/mirror-ubuntu-packages.sh
# Select option 3 (Minimal)
```

## Why Mirror Ubuntu Packages?

### Use Cases

1. **Offline Environments**
   - Air-gapped networks
   - No internet access
   - Secure facilities

2. **Bandwidth Conservation**
   - Multiple machines on slow connection
   - Metered internet
   - Reduce redundant downloads

3. **Version Control**
   - Freeze package versions
   - Consistent deployments
   - Compliance requirements

4. **Speed**
   - Local network speeds (gigabit)
   - No internet latency
   - Faster updates

5. **Redundancy**
   - Backup if Ubuntu servers down
   - Network isolation
   - Disaster recovery

## How It Works

### Full Mirror (apt-mirror)
```
Ubuntu Archive (archive.ubuntu.com)
         ↓
   [apt-mirror sync]
         ↓
Local Mirror (/var/www/html/ubuntu-mirror)
         ↓
   [nginx serves]
         ↓
Client Machines (apt update)
```

### Selective Mirror (debmirror)
```
Ubuntu Archive
         ↓
[debmirror with filters]
         ↓
Local Mirror (main, restricted, universe only)
         ↓
Client Machines
```

### Minimal Mirror (manual download)
```
Package List (predefined)
         ↓
[apt-get download + dependencies]
         ↓
Local Repository
         ↓
Client Machines
```

## Client Configuration

After setting up mirror, configure clients:

### Method 1: Replace sources.list

```bash
# Backup original
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# Use mirror
sudo tee /etc/apt/sources.list << 'EOF'
deb http://mirror.secureos.local noble main restricted universe multiverse
deb http://mirror.secureos.local noble-updates main restricted universe multiverse
deb http://mirror.secureos.local noble-security main restricted universe multiverse
deb http://mirror.secureos.local noble-backports main restricted universe multiverse
EOF

# Update
sudo apt update
```

### Method 2: Add to /etc/hosts

```bash
# Add mirror IP
echo "192.168.1.100  mirror.secureos.local" | sudo tee -a /etc/hosts
```

### Method 3: Offline USB Repository

```bash
# Copy mirror to USB
rsync -av /var/www/html/ubuntu-mirror /media/usb/

# On offline machine
sudo tee /etc/apt/sources.list << 'EOF'
deb file:///media/usb/ubuntu-mirror noble main
EOF

sudo apt update
```

## Disk Space Requirements

| Mirror Type | Initial Size | Growth Rate |
|-------------|--------------|-------------|
| Full | 100-150 GB | 1-2 GB/month |
| Selective | 10-50 GB | 500 MB/month |
| Minimal | 2-5 GB | 100 MB/month |

## Bandwidth Requirements

| Mirror Type | Initial Download | Daily Updates |
|-------------|-----------------|---------------|
| Full | 100-150 GB | 500 MB - 2 GB |
| Selective | 10-50 GB | 100-500 MB |
| Minimal | 2-5 GB | 10-50 MB |

## Update Schedule

Mirrors are updated automatically via cron:

```bash
# Default: Daily at 2 AM
/etc/cron.d/ubuntu-mirror
```

Manual update:
```bash
sudo update-ubuntu-mirror
```

## Monitoring

### Check Mirror Status

```bash
# Disk usage
df -h /var/www/html/ubuntu-mirror

# Last sync
cat /var/log/ubuntu-mirror.log

# Web access
curl http://localhost/
```

### View in Browser

```
http://mirror.secureos.local
http://192.168.1.100
```

## Combining Custom Repo + Mirror

You can run both simultaneously:

```bash
# Setup custom repo for SecureOS packages
sudo bash apt-repo/setup-repo.sh

# Setup Ubuntu mirror
sudo bash apt-repo/mirror-ubuntu-packages.sh
```

Client configuration:
```bash
# Custom SecureOS packages
deb http://repo.secureos.local noble main security

# Ubuntu mirror
deb http://mirror.secureos.local noble main restricted universe multiverse
```

## Advanced: Partial Mirror

Download only specific packages:

```bash
# Create directory
mkdir -p /var/www/html/custom-mirror/pool

# Download packages
cd /var/www/html/custom-mirror/pool
apt-get download vim nginx docker.io

# Include dependencies
apt-cache depends vim | grep Depends | awk '{print $2}' | xargs apt-get download

# Create index
cd ..
dpkg-scanpackages pool /dev/null | gzip -9c > pool/Packages.gz
```

## Troubleshooting

### Mirror sync fails
- Check disk space: `df -h`
- Check network: `ping archive.ubuntu.com`
- View logs: `tail -f /var/log/ubuntu-mirror.log`

### Clients can't connect
- Check nginx: `systemctl status nginx`
- Check firewall: `sudo ufw allow 80/tcp`
- Verify network: `ping mirror.secureos.local`

### Package not found
- Full mirror: Should have everything
- Selective: May need to add component
- Minimal: Manually download package

### Disk space issues
- Selective mirror: Remove multiverse
- Enable cleanup: Edit `/etc/apt/mirror.list`
- Manual cleanup: Remove old versions

## Security Considerations

### Mirror Security

1. **GPG Verification**
   - Packages verified from Ubuntu
   - GPG keys included in mirror

2. **HTTPS** (Optional)
   ```bash
   # Install cert
   sudo apt install certbot python3-certbot-nginx
   
   # Get certificate
   sudo certbot --nginx -d mirror.secureos.local
   ```

3. **Access Control**
   ```nginx
   # Restrict to local network
   location / {
       allow 192.168.1.0/24;
       deny all;
   }
   ```

4. **Firewall Rules**
   ```bash
   # Allow only local network
   sudo ufw allow from 192.168.1.0/24 to any port 80
   ```

## Performance Optimization

### Nginx Caching

```nginx
# Add to nginx config
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=apt_cache:10m;
proxy_cache apt_cache;
proxy_cache_valid 200 1d;
```

### Faster Sync

```bash
# Increase threads in /etc/apt/mirror.list
set nthreads 40  # Default is 20
```

### SSD Storage

Place mirror on SSD for faster access:
```bash
# Move to SSD
mv /var/www/html/ubuntu-mirror /mnt/ssd/ubuntu-mirror
ln -s /mnt/ssd/ubuntu-mirror /var/www/html/ubuntu-mirror
```

## Examples

### Enterprise Deployment

```bash
# Mirror server (one time)
sudo bash apt-repo/mirror-ubuntu-packages.sh  # Choose Full

# 100 client machines
for ip in 192.168.1.{10..110}; do
    ssh $ip "echo '192.168.1.5 mirror.secureos.local' | sudo tee -a /etc/hosts"
    ssh $ip "sudo sed -i 's/archive.ubuntu.com/mirror.secureos.local/g' /etc/apt/sources.list"
    ssh $ip "sudo apt update"
done
```

### USB Repository for Airgapped System

```bash
# On internet-connected system
sudo bash apt-repo/mirror-ubuntu-packages.sh  # Minimal or Selective
rsync -av /var/www/html/ubuntu-mirror /media/usb/

# On airgapped system
sudo tee /etc/apt/sources.list << 'EOF'
deb file:///media/usb/ubuntu-mirror noble main
EOF
sudo apt update
```

## References

- [apt-mirror documentation](https://apt-mirror.github.io/)
- [debmirror man page](https://manpages.ubuntu.com/manpages/noble/man1/debmirror.1.html)
- [Ubuntu Mirror HOWTO](https://help.ubuntu.com/community/Rsyncmirror)
- [Creating Private APT Repository](https://wiki.debian.org/DebianRepository/Setup)

---

**SecureOS APT Repository Tools** - Package Management Made Easy
