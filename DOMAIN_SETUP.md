# SecureOS Domain Configuration Guide

**Domain**: secureos.xyz  
**Part of**: Barrer Software  
**Date**: October 2025

## Overview

SecureOS now has a custom domain `secureos.xyz` configured to work with GitHub Pages. This document explains the setup and configuration required.

## Domain Structure

- **Main Website**: https://secureos.xyz → GitHub Pages (ssfdre38/secureos.github.io)
- **Package Repository**: https://packages.secureos.xyz → Package hosting
- **API/Downloads**: https://api.secureos.xyz → Future API endpoints

## GitHub Pages Configuration

### 1. Repository Setup

The website repository is: `ssfdre38/secureos.github.io`

Files included:
- `index.html` - Main website
- `style.css` - Styling
- `script.js` - JavaScript functionality
- `404.html` - Custom 404 page
- `CNAME` - Contains domain name
- `README.md` - Repository documentation

### 2. CNAME File

The CNAME file contains:
```
secureos.xyz
```

This tells GitHub Pages to serve the site from the custom domain.

## DNS Configuration Required

You need to configure DNS records for secureos.xyz. Here's what to set up:

### For GitHub Pages (Main Website)

**Option 1: Using CNAME (Recommended)**
```
Type: CNAME
Name: www
Value: ssfdre38.github.io
TTL: 3600
```

**Option 2: Using A Records (for apex domain)**
```
Type: A
Name: @
Value: 185.199.108.153
TTL: 3600

Type: A
Name: @
Value: 185.199.109.153
TTL: 3600

Type: A
Name: @
Value: 185.199.110.153
TTL: 3600

Type: A
Name: @
Value: 185.199.111.153
TTL: 3600
```

**CNAME for www to apex redirect:**
```
Type: CNAME
Name: www
Value: secureos.xyz
TTL: 3600
```

### For Package Repository Subdomain

```
Type: CNAME
Name: packages
Value: ssfdre38.github.io
TTL: 3600
```

Or point to your VPS if hosting packages there:
```
Type: A
Name: packages
Value: [YOUR_VPS_IP]
TTL: 3600
```

## GitHub Pages Settings

After DNS is configured, enable GitHub Pages in repository settings:

1. Go to https://github.com/ssfdre38/secureos.github.io/settings/pages
2. Under "Custom domain", enter: `secureos.xyz`
3. Check "Enforce HTTPS" (after DNS propagates)
4. Branch should be set to: `main` / `root`

## Verification Steps

### 1. Check DNS Propagation

```bash
# Check CNAME record
dig secureos.xyz CNAME

# Check A records
dig secureos.xyz A

# Check www subdomain
dig www.secureos.xyz CNAME
```

### 2. Test HTTPS

After DNS propagates (can take 24-48 hours):
```bash
curl -I https://secureos.xyz
```

Should return:
```
HTTP/2 200
server: GitHub.com
```

### 3. Verify CNAME File

```bash
curl https://raw.githubusercontent.com/ssfdre38/secureos.github.io/main/CNAME
```

Should output: `secureos.xyz`

## SSL/TLS Certificate

GitHub Pages automatically provisions SSL certificates via Let's Encrypt once:
1. DNS is properly configured
2. DNS has propagated
3. "Enforce HTTPS" is enabled in settings

This usually takes a few minutes after DNS propagation.

## Subdomain Setup

### packages.secureos.xyz

For the APT package repository:

**Option 1: GitHub Pages**
Create `ssfdre38/packages.secureos.xyz` repo with CNAME file containing `packages.secureos.xyz`

**Option 2: VPS Hosting (Recommended for packages)**
1. Point DNS to VPS IP
2. Configure nginx/Apache to serve packages
3. Set up SSL with Let's Encrypt

Example nginx config:
```nginx
server {
    listen 80;
    server_name packages.secureos.xyz;
    
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name packages.secureos.xyz;
    
    ssl_certificate /etc/letsencrypt/live/packages.secureos.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/packages.secureos.xyz/privkey.pem;
    
    root /var/www/packages.secureos.xyz;
    autoindex on;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## Troubleshooting

### Website not loading

1. **Check DNS**: `dig secureos.xyz`
2. **Check CNAME file**: Must exist in repo root
3. **Check GitHub Pages settings**: Custom domain must be set
4. **Wait for propagation**: Can take 24-48 hours

### HTTPS not working

1. **Wait for DNS propagation**: Usually 24-48 hours
2. **Uncheck and recheck "Enforce HTTPS"** in GitHub Pages settings
3. **Verify DNS records** are correct
4. **Clear browser cache**

### 404 errors

1. **Check repository name**: Must be `username.github.io`
2. **Check branch**: Should be `main` or `master`
3. **Check file names**: Must be lowercase
4. **Verify CNAME**: Should contain only domain name

## Current Status

✅ Website repository created: `ssfdre38/secureos.github.io`  
✅ Website files uploaded (index.html, style.css, script.js, 404.html)  
✅ CNAME file created with `secureos.xyz`  
✅ README.md added  
✅ Code pushed to GitHub  
⏳ DNS configuration (you need to do this in your domain registrar)  
⏳ GitHub Pages custom domain setup (after DNS)  
⏳ HTTPS enforcement (automatic after DNS)

## Next Steps

1. **Configure DNS** at your domain registrar (where you bought secureos.xyz)
2. **Wait for DNS propagation** (24-48 hours)
3. **Enable GitHub Pages** with custom domain in repository settings
4. **Enable HTTPS** enforcement
5. **Test the website** at https://secureos.xyz

## Package Repository Setup

Once the main domain is working, set up package repository:

```bash
# Create packages subdirectory structure
mkdir -p /var/www/packages.secureos.xyz/{pool,dists}

# Set up nginx to serve packages
# Install certbot for SSL
sudo certbot --nginx -d packages.secureos.xyz

# Configure APT repository structure
# Update packages as needed
```

## Links

- Main Repository: https://github.com/ssfdre38/SecureOS
- Website Repository: https://github.com/ssfdre38/secureos.github.io
- Package Repository: https://github.com/ssfdre38/secureos-packages
- GitHub Pages Docs: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

## Support

For issues with domain configuration:
- Check GitHub Pages documentation
- Verify DNS records with `dig` or online DNS checkers
- Wait sufficient time for DNS propagation
- Contact domain registrar if DNS issues persist

---

**Copyright © 2025 Barrer Software. All rights reserved.**
