# SignPath Foundation Code Signing Setup

This guide walks you through setting up free code signing via SignPath Foundation.

## Prerequisites

1. GitHub account with MFA enabled
2. This repository pushed to GitHub (public)

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `GuildShopSync`
3. Visibility: **Public** (required for free signing)
4. Click "Create repository"
5. Push this code to the repository:

```bash
cd GuildShopSync-Installer
git init
git add .
git commit -m "Initial commit - GuildShopSync v2.5"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/GuildShopSync.git
git push -u origin main
```

## Step 2: Apply to SignPath Foundation

1. Go to https://signpath.org/pricing
2. Click "Apply now" under "Open Source" (Free tier)
3. Fill out the application:
   - **Project URL**: Your GitHub repo URL
   - **License**: MIT (already included)
   - **Description**: "WoW addon sync tool for guild websites"
   - **Maintainer email**: Your email
4. Submit and wait for approval (usually 1-3 business days)

## Step 3: Configure SignPath (After Approval)

Once approved, you'll receive access to SignPath:

1. Log in to https://app.signpath.io
2. Create a new project:
   - Name: `GuildShopSync`
   - Slug: `guildshopsync`
3. Connect GitHub:
   - Go to Project Settings > Integrations
   - Click "Connect GitHub"
   - Authorize SignPath access to your repo
4. Create signing policy:
   - Name: `release-signing`
   - Trigger: GitHub tags matching `v*`
5. Get your credentials:
   - Go to Settings > API Tokens
   - Create new token with signing permissions
   - Copy the Organization ID

## Step 4: Add GitHub Secrets

In your GitHub repository:

1. Go to Settings > Secrets and variables > Actions
2. Add these secrets:
   - `SIGNPATH_API_TOKEN`: Your SignPath API token
   - `SIGNPATH_ORGANIZATION_ID`: Your SignPath org ID

## Step 5: Create a Signed Release

1. Update version in `GuildShopSync.iss` if needed
2. Create and push a tag:

```bash
git tag v2.5
git push origin v2.5
```

3. GitHub Actions will:
   - Build the installer
   - Submit to SignPath for signing
   - Create a GitHub release with the signed installer

## Step 6: Download Signed Installer

1. Go to your GitHub repo's Releases page
2. Download the signed `GuildShopSync-Setup-v2.5.exe`
3. Upload to your website

## Verification

After signing, Windows SmartScreen will no longer warn users because:
- The EXE is signed with a trusted certificate
- SignPath Foundation uses DigiCert certificates
- The signature builds reputation over time

## Troubleshooting

**"SignPath approval pending"**
- Wait 1-3 business days for manual review
- Ensure your repo is public and has a proper license

**"Build failed"**
- Check GitHub Actions logs
- Ensure Inno Setup script compiles locally first

**"Signing request rejected"**
- Verify your SignPath project configuration
- Check that tag matches the signing policy

## Alternative: Self-Sign (Not Recommended)

If SignPath doesn't work, you can self-sign, but this won't bypass SmartScreen:

```powershell
# Create self-signed cert (NOT trusted by Windows)
New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=GuildShopSync" -CertStoreLocation "Cert:\CurrentUser\My"
```

Self-signed certs don't help with SmartScreen - you need a trusted CA.

## Questions?

Contact guild leadership on Discord.
