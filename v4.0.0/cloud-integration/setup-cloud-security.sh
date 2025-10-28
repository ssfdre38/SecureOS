#!/bin/bash
#
# SecureOS - Security Enhanced Linux Distribution
# Part of Barrer Software
#
# Copyright (c) 2025 Barrer Software
# Licensed under the MIT License
#
# Cloud Security Integration
#
set -e

echo "========================================="
echo "SecureOS v4.0.0 - Cloud Integration"
echo "Copyright © 2025 Barrer Software"
echo "========================================="

install_cloud_tools() {
    echo "[*] Installing cloud integration tools..."
    
    # AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update || /tmp/aws/install
    
    # Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
    
    # Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
        tee /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
        apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - || true
    apt-get update
    apt-get install -y google-cloud-cli
    
    # Terraform for IaC
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        tee /etc/apt/sources.list.d/hashicorp.list
    apt-get update
    apt-get install -y terraform
    
    # Cloud security tools
    apt-get install -y \
        python3-pip \
        jq \
        awscli
    
    pip3 install \
        prowler \
        ScoutSuite \
        cloudsploit \
        pacu
    
    echo "[✓] Cloud tools installed"
}

setup_aws_security() {
    echo "[*] Configuring AWS security..."
    
    cat > /usr/local/bin/aws-security-audit << 'EOF'
#!/bin/bash
# AWS Security Audit
# Copyright © 2025 Barrer Software

echo "Running AWS Security Audit with Prowler..."
prowler aws --output-directory /var/log/secureos/aws-audit

echo ""
echo "Key findings:"
grep -i "FAIL" /var/log/secureos/aws-audit/prowler-output-*.txt | head -20
EOF
    chmod +x /usr/local/bin/aws-security-audit
    
    # AWS CloudTrail monitoring
    cat > /usr/local/bin/aws-monitor-cloudtrail << 'EOF'
#!/bin/bash
# Monitor AWS CloudTrail for suspicious activity
# Copyright © 2025 Barrer Software

echo "Monitoring AWS CloudTrail..."

# Check for root account usage
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=Username,AttributeValue=root \
    --max-results 10 | jq -r '.Events[] | .EventTime + " " + .EventName'

# Check for IAM changes
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=CreateUser \
    --max-results 10 | jq -r '.Events[] | .EventTime + " " + .Username'

# Check for security group changes
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
    --max-results 10 | jq -r '.Events[] | .EventTime + " " + .CloudTrailEvent'
EOF
    chmod +x /usr/local/bin/aws-monitor-cloudtrail
    
    echo "[✓] AWS security configured"
}

setup_azure_security() {
    echo "[*] Configuring Azure security..."
    
    cat > /usr/local/bin/azure-security-audit << 'EOF'
#!/bin/bash
# Azure Security Audit
# Copyright © 2025 Barrer Software

echo "Running Azure Security Assessment..."
az login --use-device-code

# Get security recommendations
az security assessment list --output table

# Check for security center alerts
az security alert list --output table

# Review network security groups
az network nsg list --output table
EOF
    chmod +x /usr/local/bin/azure-security-audit
    
    echo "[✓] Azure security configured"
}

setup_gcp_security() {
    echo "[*] Configuring GCP security..."
    
    cat > /usr/local/bin/gcp-security-audit << 'EOF'
#!/bin/bash
# GCP Security Audit
# Copyright © 2025 Barrer Software

echo "Running GCP Security Audit with ScoutSuite..."
scout gcp --output-directory /var/log/secureos/gcp-audit

# Check firewall rules
gcloud compute firewall-rules list --format=table

# Check IAM policies
gcloud projects get-iam-policy $(gcloud config get-value project) --format=json | \
    jq -r '.bindings[] | select(.role=="roles/owner") | .members[]'
EOF
    chmod +x /usr/local/bin/gcp-security-audit
    
    echo "[✓] GCP security configured"
}

setup_cloud_workload_protection() {
    echo "[*] Setting up cloud workload protection..."
    
    mkdir -p /etc/secureos/cloud-config
    
    # Install Falco for runtime security
    curl -s https://falco.org/repo/falcosecurity-packages.asc | apt-key add -
    echo "deb https://download.falco.org/packages/deb stable main" | \
        tee /etc/apt/sources.list.d/falcosecurity.list
    apt-get update
    apt-get install -y falco
    
    # Configure Falco for cloud workloads
    cat >> /etc/falco/falco_rules.local.yaml << 'EOF'
# SecureOS Cloud Security Rules
# Copyright © 2025 Barrer Software

- rule: Unauthorized Cloud API Access
  desc: Detect unauthorized access to cloud provider APIs
  condition: spawned_process and proc.name in (aws, az, gcloud) and user.name != root
  output: "Unauthorized cloud API access (user=%user.name command=%proc.cmdline)"
  priority: WARNING

- rule: Cloud Credentials Access
  desc: Detect access to cloud credentials
  condition: open_read and fd.name in (/root/.aws/credentials, /root/.azure/credentials, /root/.config/gcloud/credentials)
  output: "Cloud credentials accessed (user=%user.name file=%fd.name)"
  priority: CRITICAL

- rule: Suspicious Container Activity
  desc: Detect suspicious activity in containers
  condition: container and spawned_process and proc.name in (nc, ncat, socat)
  output: "Suspicious container activity (container=%container.name command=%proc.cmdline)"
  priority: WARNING
EOF
    
    systemctl enable falco
    
    echo "[✓] Cloud workload protection configured"
}

setup_terraform_security() {
    echo "[*] Setting up Terraform security scanning..."
    
    # Install tfsec
    curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
    
    # Install Checkov
    pip3 install checkov
    
    cat > /usr/local/bin/terraform-security-scan << 'EOF'
#!/bin/bash
# Terraform Security Scanner
# Copyright © 2025 Barrer Software

TF_DIR="${1:-.}"

if [ ! -d "$TF_DIR" ]; then
    echo "ERROR: Directory not found: $TF_DIR"
    exit 1
fi

echo "Scanning Terraform configurations..."
echo "====================================="

# Run tfsec
echo ""
echo "[*] Running tfsec..."
tfsec "$TF_DIR"

# Run Checkov
echo ""
echo "[*] Running Checkov..."
checkov -d "$TF_DIR"

echo ""
echo "====================================="
echo "Scan complete!"
EOF
    chmod +x /usr/local/bin/terraform-security-scan
    
    echo "[✓] Terraform security scanning configured"
}

setup_cloud_secrets_management() {
    echo "[*] Setting up cloud secrets management..."
    
    # Install Vault
    apt-get install -y vault
    
    cat > /usr/local/bin/setup-cloud-secrets << 'EOF'
#!/bin/bash
# Setup Cloud Secrets Management
# Copyright © 2025 Barrer Software

echo "Setting up HashiCorp Vault for cloud secrets..."

# Initialize Vault
vault server -dev -dev-root-token-id=secureos &
sleep 3

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='secureos'

# Enable cloud secret engines
vault secrets enable -path=aws aws
vault secrets enable -path=azure azure
vault secrets enable -path=gcp gcp

# Enable KV secrets
vault secrets enable -path=cloud-secrets kv-v2

echo "✓ Vault configured for cloud secrets"
echo ""
echo "Usage:"
echo "  vault kv put cloud-secrets/aws access_key=XXX secret_key=YYY"
echo "  vault kv get cloud-secrets/aws"
EOF
    chmod +x /usr/local/bin/setup-cloud-secrets
    
    echo "[✓] Cloud secrets management configured"
}

setup_cloud_compliance() {
    echo "[*] Setting up cloud compliance monitoring..."
    
    cat > /usr/local/bin/cloud-compliance-check << 'EOF'
#!/bin/bash
# Cloud Compliance Checker
# Copyright © 2025 Barrer Software

echo "========================================"
echo "Cloud Compliance Check"
echo "========================================"

# AWS CIS Benchmark
if command -v aws &>/dev/null; then
    echo ""
    echo "[*] AWS CIS Benchmark..."
    prowler aws -f cis_1.5_aws
fi

# Azure CIS Benchmark
if command -v az &>/dev/null; then
    echo ""
    echo "[*] Azure Security Assessment..."
    az security secure-score list
fi

# GCP Security Health Analytics
if command -v gcloud &>/dev/null; then
    echo ""
    echo "[*] GCP Security Findings..."
    gcloud scc findings list --format=json | jq -r '.[] | .category + ": " + .resourceName'
fi

# Kubernetes security
if command -v kubectl &>/dev/null; then
    echo ""
    echo "[*] Kubernetes Security..."
    kubectl get pods --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.name'
fi

echo ""
echo "========================================"
echo "Compliance check complete!"
EOF
    chmod +x /usr/local/bin/cloud-compliance-check
    
    echo "[✓] Cloud compliance configured"
}

create_cloud_documentation() {
    cat > /etc/secureos/cloud-integration-README.md << 'EOF'
# SecureOS Cloud Security Integration

Copyright © 2025 Barrer Software

## Overview

SecureOS v4.0.0 provides comprehensive security for cloud environments:
- AWS, Azure, and GCP support
- Automated security auditing
- Compliance checking
- Secrets management
- Infrastructure as Code security

## Supported Platforms

- **AWS** (Amazon Web Services)
- **Azure** (Microsoft Azure)
- **GCP** (Google Cloud Platform)
- **Kubernetes** (all platforms)

## Commands

### AWS Security
```bash
# Configure AWS credentials
aws configure

# Run security audit
aws-security-audit

# Monitor CloudTrail
aws-monitor-cloudtrail
```

### Azure Security
```bash
# Login to Azure
az login

# Run security audit
azure-security-audit
```

### GCP Security
```bash
# Login to GCP
gcloud auth login

# Run security audit
gcp-security-audit
```

### Multi-Cloud
```bash
# Run compliance check across all clouds
cloud-compliance-check

# Scan Terraform configurations
terraform-security-scan /path/to/tf

# Setup secrets management
setup-cloud-secrets
```

## Security Tools

### Prowler (AWS)
Comprehensive AWS security auditing
- CIS Benchmarks
- 200+ security checks
- Compliance reporting

### ScoutSuite (Multi-Cloud)
Security audit for AWS, Azure, GCP
- Configuration assessment
- Best practices validation

### Falco (Runtime Security)
Cloud workload protection
- Container monitoring
- Anomaly detection
- Real-time alerts

### tfsec / Checkov (IaC Security)
Terraform security scanning
- Misconfigurations
- Best practices
- Compliance checks

## Cloud Compliance

### CIS Benchmarks
- AWS CIS 1.5
- Azure CIS 1.3
- GCP CIS 1.2

### Standards Supported
- PCI-DSS
- HIPAA
- SOC 2
- ISO 27001
- GDPR

## Best Practices

### AWS
1. Enable CloudTrail in all regions
2. Use MFA for root account
3. Encrypt all S3 buckets
4. Restrict security groups
5. Enable GuardDuty

### Azure
1. Enable Security Center
2. Use Azure AD MFA
3. Encrypt storage accounts
4. Lock down NSGs
5. Enable Azure Sentinel

### GCP
1. Enable Security Command Center
2. Use Cloud IAM conditions
3. Encrypt all data
4. Restrict firewall rules
5. Enable Cloud Armor

### Kubernetes
1. Use RBAC
2. Enable Pod Security Policies
3. Network policies
4. Secrets encryption
5. Runtime monitoring (Falco)

## Secrets Management

### HashiCorp Vault
Store cloud credentials securely:
```bash
# Store AWS credentials
vault kv put cloud-secrets/aws \
    access_key=AKIA... \
    secret_key=...

# Retrieve credentials
vault kv get cloud-secrets/aws
```

## Infrastructure as Code

### Terraform Security
```bash
# Scan before apply
terraform-security-scan .

# Apply securely
terraform plan
terraform apply
```

## Monitoring & Alerts

### CloudTrail Monitoring (AWS)
Monitor for:
- Root account usage
- IAM changes
- Security group modifications
- S3 bucket changes

### Azure Activity Log
Monitor for:
- Role assignments
- Resource deletions
- Network changes

### GCP Cloud Logging
Monitor for:
- IAM policy changes
- Firewall modifications
- VM changes

## Incident Response

### AWS
```bash
# Check recent IAM changes
aws iam list-users --output table

# Review security group rules
aws ec2 describe-security-groups
```

### Azure
```bash
# Check security alerts
az security alert list

# Review activity log
az monitor activity-log list --max-events 50
```

### GCP
```bash
# Check security findings
gcloud scc findings list

# Review audit logs
gcloud logging read "protoPayload.methodName=SetIamPolicy"
```

## Support

- Documentation: https://ssfdre38.github.io/SecureOS
- GitHub: https://github.com/ssfdre38/SecureOS
- Issues: https://github.com/ssfdre38/SecureOS/issues

---

SecureOS v4.0.0 - Cloud Security Integration
Barrer Software © 2025
EOF
    
    echo "[✓] Cloud documentation created"
}

main() {
    echo ""
    echo "This script sets up Cloud Security Integration for SecureOS"
    echo ""
    
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root"
        exit 1
    fi
    
    read -p "Install Cloud Integration components? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_cloud_tools
        setup_aws_security
        setup_azure_security
        setup_gcp_security
        setup_cloud_workload_protection
        setup_terraform_security
        setup_cloud_secrets_management
        setup_cloud_compliance
        create_cloud_documentation
        
        echo ""
        echo "============================================"
        echo "✓ Cloud Integration Setup Complete!"
        echo "============================================"
        echo ""
        echo "Next steps:"
        echo "1. Configure cloud credentials:"
        echo "   - AWS: aws configure"
        echo "   - Azure: az login"
        echo "   - GCP: gcloud auth login"
        echo "2. Run security audits: cloud-compliance-check"
        echo "3. Scan Terraform: terraform-security-scan /path"
        echo "4. Read documentation: /etc/secureos/cloud-integration-README.md"
        echo ""
        echo "SecureOS v4.0.0 - Cloud Security Enabled"
        echo "Barrer Software © 2025"
    fi
}

main "$@"
