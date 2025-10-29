# SecureOS - GitHub Actions CI/CD

This directory contains GitHub Actions workflows for automating SecureOS builds and security scanning.

## Workflows

### 1. Build ISO (`build-iso.yml`)
Automatically builds the SecureOS ISO image on:
- Push to master/main branch
- Git tags (for releases)
- Manual trigger via GitHub UI

**Features:**
- Maximizes available disk space (removes unnecessary tools)
- Builds full bootable ISO (~1.5GB)
- Generates SHA256 and MD5 checksums
- Uploads ISO as artifact (downloadable for 30 days)
- Creates GitHub release on tagged commits

**Usage:**
```bash
# Trigger automatically by pushing
git tag v1.0.0
git push --tags

# Or trigger manually:
# Go to Actions tab → Build SecureOS ISO → Run workflow
```

### 2. Security Scan (`security-scan.yml`)
Runs security checks on all code:
- **ShellCheck**: Validates bash scripts for issues
- **Bandit**: Scans Python code for security vulnerabilities
- **Trivy**: Filesystem vulnerability scanner

Runs on:
- Every push to master/main
- Every pull request
- Weekly (Sunday at midnight UTC)

## Manual Workflow Trigger

To manually trigger the ISO build:

1. Go to https://github.com/barrersoftware/SecureOS/actions
2. Click "Build SecureOS ISO" workflow
3. Click "Run workflow" button
4. Select branch and click "Run workflow"

## Build Artifacts

After successful build:
- **Artifacts**: Available in Actions tab for 30 days
- **Releases**: Created automatically for tagged commits

## Download Built ISO

### From Actions (latest build):
1. Go to Actions → Build SecureOS ISO
2. Click on latest successful run
3. Scroll to "Artifacts" section
4. Download "SecureOS-ISO" artifact

### From Releases (stable versions):
1. Go to Releases tab
2. Download latest release
3. Verify checksum before use

## Build Time

Expected build time on GitHub Actions:
- **Setup**: ~5 minutes
- **Bootstrap**: ~10-15 minutes
- **Package installation**: ~20-30 minutes
- **ISO creation**: ~5-10 minutes
- **Total**: ~40-60 minutes

## Resource Requirements

GitHub Actions provides:
- 2-core CPU
- 7 GB RAM
- 14 GB SSD (maximized to ~40GB with cleanup)
- 6 hours max runtime per job

This is sufficient for building SecureOS ISO.

## Troubleshooting

### Build fails with "No space left on device"
- The workflow uses `maximize-build-space` action
- If still failing, reduce installed packages in `build_iso.sh`

### Build timeout (6 hours)
- Optimize package selection
- Consider splitting into multiple jobs

### Artifact too large
- GitHub has 2GB limit per artifact
- Current ISO should be ~1.5GB (within limit)

## Cost

GitHub Actions is **FREE** for public repositories:
- Unlimited minutes for public repos
- 2000 minutes/month for private repos

## Security

All workflows run in isolated containers and are destroyed after completion. No credentials or secrets are stored in the ISO build process.

## Local Testing

To test workflow locally using [act](https://github.com/nektos/act):

```bash
# Install act
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow locally
act -W .github/workflows/build-iso.yml
```

Note: Local testing requires Docker and significant disk space.
