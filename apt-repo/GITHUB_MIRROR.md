# GitHub APT Mirror Strategy

## Problem: GitHub Limitations

Traditional mirroring won't work on GitHub because:

| Limitation | Impact |
|-----------|---------|
| 100 GB repository size | Can't store full Ubuntu mirror (150+ GB) |
| Large file warnings (>50 MB) | Most .deb packages trigger warnings |
| Git LFS costs money | $5/month per 50 GB after first 1 GB |
| Slow for large files | Git isn't optimized for binaries |

## Solution: GitHub Releases + Pages

Instead of storing packages in Git, use **GitHub Releases**:

### ✅ Advantages

1. **Unlimited Storage**: No limit on release assets
2. **2 GB per file**: Plenty for package archives
3. **Free**: For public repositories
4. **Fast Downloads**: Global CDN
5. **No Git overhead**: Direct file downloads
6. **GitHub Pages for metadata**: Free APT repository hosting

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Repository (secureos-packages)                  │
│                                                          │
│  ┌────────────────────┐    ┌─────────────────────────┐ │
│  │  Releases          │    │  GitHub Pages (gh-pages)│ │
│  │                    │    │                          │ │
│  │  v20241028-        │    │  dists/noble/           │ │
│  │  security.tar.gz   │◄───┤    Release              │ │
│  │  (1.5 GB)          │    │    Packages.gz          │ │
│  │                    │    │                          │ │
│  │  Packages.gz       │    │  index.html             │ │
│  │  install-client.sh │    │  .nojekyll              │ │
│  └────────────────────┘    └─────────────────────────┘ │
│                                        ▲                │
└────────────────────────────────────────┼────────────────┘
                                         │
                                         │ apt update
                    ┌────────────────────┴───────────┐
                    │  Client Machine                │
                    │  /etc/apt/sources.list.d/      │
                    │  secureos-github.list          │
                    └────────────────────────────────┘
```

## How It Works

### 1. Package Organization

Packages are organized into **collections** (releases):

```
v20241028-security-essentials
├── ufw_0.36.2-1_all.deb
├── apparmor_3.0.4-2ubuntu2_amd64.deb
├── fail2ban_0.11.2-3_all.deb
└── ... (compressed as security-essentials.tar.gz)

v20241028-privacy-tools
├── tor_0.4.7.13-1_amd64.deb
├── wireguard_1.0.20210914-1ubuntu2_all.deb
└── ... (compressed as privacy-tools.tar.gz)
```

### 2. APT Repository Metadata

GitHub Pages hosts the APT repository structure:

```
https://username.github.io/secureos-packages/
├── dists/noble/
│   ├── Release
│   ├── InRelease
│   └── main/binary-amd64/
│       ├── Packages
│       └── Packages.gz
└── index.html
```

### 3. Client Configuration

Clients add repository:
```bash
deb [trusted=yes] https://username.github.io/secureos-packages/ ./
```

APT fetches metadata from Pages, packages from Releases.

## Usage

### Create Mirror

```bash
sudo bash apt-repo/github-mirror.sh
```

Interactive prompts:
1. GitHub repo (e.g., `yourname/secureos-packages`)
2. Collection name (`security-essentials`, `privacy-tools`, `dev-tools`)
3. Script downloads packages, creates release, sets up Pages

### Collections

**Predefined Collections:**

1. **security-essentials**
   - ufw, apparmor, auditd, fail2ban, aide, rkhunter
   - ~500 MB compressed

2. **privacy-tools**
   - tor, privoxy, macchanger, wireguard, openvpn
   - ~300 MB compressed

3. **dev-tools**
   - vim, git, docker, nodejs, python3-pip
   - ~1 GB compressed

**Custom Collections:**
Add packages manually to `/tmp/github-mirror-*/packages/`

### Update Mirror

```bash
# Create new collection/version
sudo bash apt-repo/github-mirror.sh
# Select different collection or update existing
```

Each run creates a new release with timestamp.

## Client Setup

### Method 1: Automated

```bash
curl -L https://github.com/USER/REPO/releases/latest/download/install-client.sh | sudo bash
```

### Method 2: Manual

```bash
echo "deb [trusted=yes] https://USER.github.io/REPO/ ./" | sudo tee /etc/apt/sources.list.d/secureos-github.list
sudo apt update
sudo apt install ufw apparmor fail2ban
```

### Method 3: Offline Download

```bash
# Download release archive
curl -L https://github.com/USER/REPO/releases/download/v20241028-security/security.tar.gz -o packages.tar.gz

# Extract and install
tar xzf packages.tar.gz
sudo dpkg -i *.deb
sudo apt-get install -f  # Fix dependencies
```

## Advantages vs Traditional Mirror

| Aspect | Traditional | GitHub Releases |
|--------|------------|-----------------|
| Storage | 100+ GB | Split into releases |
| Cost | VPS/server fees | Free |
| Bandwidth | Limited by host | Unlimited (GitHub CDN) |
| Speed | Depends on server | Fast (global CDN) |
| Maintenance | Self-managed | GitHub manages |
| Updates | Manual sync | Create new release |
| Offline | Requires download | Download releases |

## Limitations

### Size Constraints

- **2 GB per file**: Split large collections
- **No full mirror**: Can't host entire Ubuntu archive
- **Selective packages**: Choose important ones

**Workaround**: Create multiple releases:
```
v20241028-security-part1.tar.gz (2 GB)
v20241028-security-part2.tar.gz (1.5 GB)
```

### No Automatic Updates

GitHub doesn't auto-sync with Ubuntu:
- Create releases manually
- Use GitHub Actions to automate
- Update on schedule (weekly/monthly)

**Workaround**: GitHub Actions workflow (see below)

### Package Discovery

Clients can't browse all available packages:
- Only packages in Packages.gz are listed
- `apt search` works but limited to included packages

**Workaround**: Good documentation of collections

## GitHub Actions Automation

Create `.github/workflows/update-packages.yml`:

```yaml
name: Update Package Collections

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday 2 AM
  workflow_dispatch:  # Manual trigger

jobs:
  update:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Download packages
        run: |
          mkdir -p packages
          cd packages
          apt-get download ufw apparmor fail2ban tor
      
      - name: Create release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          TAG="v$(date +%Y%m%d)-security"
          tar czf security.tar.gz packages/*.deb
          gh release create "$TAG" security.tar.gz \
            --title "Security Packages $(date +%Y-%m-%d)" \
            --notes "Weekly security package update"
```

## Advanced: Git LFS Alternative

For smaller mirrors (<10 GB), consider **Git LFS**:

```bash
git lfs install
git lfs track "*.deb"
git add .gitattributes
git add packages/*.deb
git commit -m "Add packages"
git push
```

**Costs:**
- Free: 1 GB storage, 1 GB/month bandwidth
- $5/month: 50 GB storage, 50 GB/month bandwidth

## Security Considerations

### GPG Signing

Packages from Ubuntu are already GPG-signed:
```bash
# Verify package signature
dpkg-sig --verify package.deb
```

### Trusted Repository

Using `[trusted=yes]` bypasses GPG checks:
```bash
# Better: Import GPG key
curl -L https://github.com/USER/REPO/raw/main/REPO.gpg | sudo apt-key add -
# Then remove [trusted=yes]
```

### HTTPS

GitHub serves over HTTPS automatically:
- Encrypted downloads
- Verified by GitHub's certificate

## Best Practices

### 1. Organize Collections Logically

```
security-core
security-monitoring  
security-audit
privacy-essential
privacy-advanced
dev-minimal
dev-full
```

### 2. Version Tags

Use semantic versioning:
```
v2024.10.28-security-essentials
v1.0.0-privacy-tools
v2.1.0-dev-complete
```

### 3. Documentation

Include in each release:
- Package list
- Installation instructions
- Dependencies
- Changelog

### 4. Client Script

Always provide `install-client.sh`:
```bash
#!/bin/bash
# One-line setup for users
echo "deb [trusted=yes] https://user.github.io/repo/ ./" | sudo tee /etc/apt/sources.list.d/secureos.list
sudo apt update
```

### 5. README

Update repository README:
```markdown
## Available Collections

- **security-essentials**: Core security tools (500 MB)
- **privacy-tools**: Privacy and anonymity (300 MB)
- **dev-tools**: Development environment (1 GB)

## Quick Install

\`\`\`bash
curl -L https://github.com/USER/REPO/releases/latest/download/install-client.sh | sudo bash
\`\`\`
```

## Example Repositories

Real-world examples:

1. **Personal Package Archive**
   ```
   yourname/my-packages
   - Custom built packages
   - Development snapshots
   - Backports
   ```

2. **Organization Mirror**
   ```
   company/ubuntu-mirror
   - Approved packages only
   - Security vetted
   - Compliance tagged
   ```

3. **Specialized Distribution**
   ```
   secureos/packages
   - Security-hardened versions
   - Privacy-enhanced configs
   - Pre-configured tools
   ```

## Monitoring

Track usage via GitHub Insights:
- Download counts
- Release views
- Traffic sources

## Conclusion

GitHub Releases provide a viable alternative for hosting APT repositories:

✅ **Pros:**
- Free unlimited storage
- Global CDN
- No server maintenance
- Easy updates

❌ **Cons:**
- Can't host full Ubuntu mirror
- Manual/scheduled updates
- 2 GB per file limit

**Perfect for:**
- Curated package collections
- Specialized distributions
- Offline installation kits
- Personal package archives

---

**SecureOS GitHub Mirror** - Free, Fast, Forever
