# SecureOS v5.0.0 - Quick Start Guide

## Installation

### Prerequisites
- Ubuntu 24.04 LTS (or compatible)
- 8GB RAM minimum (16GB recommended)
- 100GB disk space
- Python 3.8+
- Root access

### Install All Components
```bash
cd /home/ubuntu/SecureOS
sudo bash v5.0.0/install.sh
# Select option 1 for all components
```

### Install Individual Components
```bash
sudo bash v5.0.0/install.sh
# Select option 7 for custom selection
```

---

## AI Threat Detection

### Check Status
```bash
secureos ai status
```

### Analyze Event
```bash
secureos ai analyze --event '{"syscall_count": 150, "network_connections": 5}'
```

### Train Model
```bash
secureos ai train --dataset training_data.json
```

### Run Benchmark
```bash
secureos ai benchmark
```

---

## Blockchain Audit System

### Initialize
```bash
secureos blockchain init
```

### Add Security Event
```bash
secureos blockchain add --event '{"type": "login", "user": "admin", "status": "success"}'
```

### Verify Chain Integrity
```bash
secureos blockchain verify
```

### Export Compliance Report
```bash
secureos blockchain export --start 2025-01-01 --end 2025-12-31 --output report.json
```

### View Statistics
```bash
secureos blockchain stats
```

---

## Post-Quantum Cryptography

### List Available Algorithms
```bash
secureos pqc list
```

### Generate Key Pair
```bash
secureos pqc keygen --algorithm kyber-1024 --key-id my-server-key
```

### Audit Crypto Usage
```bash
secureos pqc audit
```

### Migration Planning
```bash
secureos pqc migrate --dry-run
```

### Benchmark Algorithm
```bash
secureos pqc benchmark --algorithm dilithium3 --iterations 100
```

---

## Self-Healing Security System

### Scan for Issues
```bash
secureos heal scan
```

### Auto-Heal System
```bash
secureos heal heal --auto
```

### View Status
```bash
secureos heal status
```

### View Remediation History
```bash
secureos heal history
```

### Enable Automatic Healing
```bash
sudo systemctl enable --now secureos-self-healing
```

---

## Malware Sandbox

### Analyze Suspicious File
```bash
secureos sandbox analyze --file suspicious.exe
```

### View Analysis Report
```bash
secureos sandbox report --id <analysis-id>
```

### List All Analyses
```bash
secureos sandbox list
```

### Clean Sandbox Data
```bash
secureos sandbox clean
```

---

## Integration Examples

### Combined Security Pipeline

```bash
#!/bin/bash
# Complete security analysis pipeline

# 1. Scan system for issues
echo "Scanning for security issues..."
secureos heal scan

# 2. Auto-remediate
echo "Auto-healing..."
secureos heal heal --auto

# 3. Verify blockchain integrity
echo "Verifying audit log integrity..."
secureos blockchain verify

# 4. Run AI threat detection
echo "Running AI threat detection..."
secureos ai analyze --event '{"syscall_count": 200, "network_connections": 10}'

# 5. Check quantum crypto readiness
echo "Checking quantum crypto status..."
secureos pqc audit
```

### Automated Security Monitoring

```bash
#!/bin/bash
# Add to cron: */5 * * * * /opt/secureos/monitor.sh

# Log security event to blockchain
EVENT="{\"timestamp\": \"$(date -Iseconds)\", \"type\": \"health_check\"}"
secureos blockchain add --event "$EVENT"

# Run self-healing scan
secureos heal scan > /var/log/secureos/health-check.log
```

---

## Configuration

### AI Engine Config
`/etc/secureos/v5/ai-config.conf`
```ini
[ai_engine]
enabled = true
confidence_threshold = 0.85
auto_response = true
```

### Blockchain Config
`/etc/secureos/v5/blockchain-config.conf`
```ini
[blockchain]
enabled = true
difficulty = 4
block_size = 100
```

### PQC Config
`/etc/secureos/v5/pqc-config.json`
```json
{
  "enabled": true,
  "kem_algorithm": "kyber-1024",
  "signature_algorithm": "dilithium3",
  "hybrid_mode": true
}
```

### Self-Healing Config
`/etc/secureos/v5/self-healing.json`
```json
{
  "enabled": true,
  "auto_remediate": true,
  "min_severity_auto": "medium",
  "scan_interval_minutes": 60
}
```

---

## Troubleshooting

### AI Engine Issues
```bash
# Check logs
tail -f /var/log/secureos/v5/ai-engine.log

# Test ML models
secureos ai test

# Retrain models
secureos ai train --dataset /var/lib/secureos/ai/training_data.json
```

### Blockchain Issues
```bash
# Verify integrity
secureos blockchain verify

# Check database
sqlite3 /var/lib/secureos/blockchain/audit.db "SELECT * FROM blocks LIMIT 5;"
```

### PQC Issues
```bash
# List stored keys
ls -la /var/lib/secureos/pqc/keys/

# Re-initialize
secureos pqc init
```

---

## Performance Tuning

### AI Engine Optimization
```bash
# Disable GPU if causing issues
export CUDA_VISIBLE_DEVICES=""

# Reduce model complexity
# Edit /etc/secureos/v5/ai-config.conf
# Set smaller models
```

### Blockchain Optimization
```bash
# Adjust difficulty for faster mining
# Edit blockchain config, set difficulty = 2
```

---

## Security Best Practices

1. **Regular Scans**: Run `secureos heal scan` daily
2. **Verify Blockchain**: Check integrity weekly with `secureos blockchain verify`
3. **Update AI Models**: Retrain with new threat data monthly
4. **Review Logs**: Check `/var/log/secureos/v5/` regularly
5. **Test Sandbox**: Validate with known malware samples (in isolated environment)

---

## Uninstallation

```bash
# Stop services
sudo systemctl stop secureos-self-healing

# Remove binaries
sudo rm /usr/local/bin/secureos*

# Remove data (WARNING: Deletes all logs and models)
sudo rm -rf /var/lib/secureos/
sudo rm -rf /etc/secureos/v5/
sudo rm -rf /opt/secureos/v5.0.0/
```

---

## Support

- **Documentation**: `/opt/secureos/v5.0.0/README.md`
- **Website**: https://secureos.xyz
- **GitHub**: https://github.com/barrersoftware/SecureOS
- **Email**: support@secureos.xyz

---

**SecureOS v5.0.0** - The Future of Autonomous Security  
**Barrer Software** © 2025
