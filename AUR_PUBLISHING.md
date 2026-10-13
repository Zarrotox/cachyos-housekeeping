# Arch User Repository (AUR) Publication & Maintenance Guide

This document outlines the step-by-step procedures for publishing, validating, and maintaining the **`cachyos-housekeeping`** package on the [Arch User Repository (AUR)](https://aur.archlinux.org/packages/cachyos-housekeeping).

---

## 1. Prerequisites

### A. Register an Account on AUR
1. Create an account at [https://aur.archlinux.org/register](https://aur.archlinux.org/register).
2. Generate an SSH key on your Arch/CachyOS system if you haven't already:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
3. Copy your public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
4. Log in to the AUR website, navigate to **My Account**, and paste your public key into the **SSH Public Key** field.

### B. Configure SSH Client
Add the following snippet to your `~/.ssh/config` file:
```ssh-config
Host aur.archlinux.org
    IdentityFile ~/.ssh/id_ed25519
    User aur
```
Verify your SSH connection:
```bash
ssh -vT aur@aur.archlinux.org
```
*(You should see an interactive welcome message confirming authentication).*

---

## 2. Initial Package Publication

### Step 1: Clone the AUR Repository
When creating a new package on the AUR, you clone the repository namespace directly using SSH:
```bash
git clone ssh://aur@aur.archlinux.org/cachyos-housekeeping.git /tmp/cachyos-housekeeping-aur
cd /tmp/cachyos-housekeeping-aur
```

### Step 2: Copy the Packaging Files
Copy the `PKGBUILD` and `.SRCINFO` files from this project into your local AUR working clone:
```bash
cp /path/to/cachyos-housekeeping/PKGBUILD .
cp /path/to/cachyos-housekeeping/.SRCINFO .
```

### Step 3: Validate and Test Build
Before publishing, run Arch package linter checks:
```bash
# 1. Install packaging tools if not present
sudo pacman -S --needed pacman-contrib namcap

# 2. Check PKGBUILD quality with namcap
namcap PKGBUILD

# 3. Test compilation and installation in a clean environment
makepkg -si
```

### Step 4: Regenerate `.SRCINFO`
Ensure `.SRCINFO` is strictly synchronized with `PKGBUILD`:
```bash
makepkg --printsrcinfo > .SRCINFO
```

### Step 5: Commit and Push to the AUR
```bash
git add PKGBUILD .SRCINFO
git commit -m "feat(aur): initial release v2026.10.15"
git push origin master
```
Once pushed, the package will immediately be live and indexable on [https://aur.archlinux.org/packages/cachyos-housekeeping](https://aur.archlinux.org/packages/cachyos-housekeeping).

Users can now install it using any AUR helper:
```bash
paru -S cachyos-housekeeping
# or
yay -S cachyos-housekeeping
```

---

## 3. Maintenance & Release Update Workflow

When releasing a new version (e.g., when a new release tag `vYYYY.MM.DD` is cut):

### Step 1: Update Version & Sources in `PKGBUILD`
1. Navigate to your AUR clone:
   ```bash
   cd /path/to/cachyos-housekeeping-aur
   ```
2. Pull latest changes:
   ```bash
   git pull origin master
   ```
3. Update `pkgver` in `PKGBUILD`:
   ```bash
   pkgver=NEW_VERSION
   pkgrel=1
   ```

### Step 2: Update Checksums with `updpkgsums`
Fetch the new upstream release archive and generate verified sha256 hashes automatically:
```bash
updpkgsums
```

### Step 3: Regenerate `.SRCINFO`
```bash
makepkg --printsrcinfo > .SRCINFO
```

### Step 4: Verify Clean Build
```bash
# Clean previous artifacts and build
makepkg -C -c -s

# Run namcap on the built package
namcap cachyos-housekeeping-*.pkg.tar.zst
```

### Step 5: Publish Update
```bash
git add PKGBUILD .SRCINFO
git commit -m "chore(release): bump to vNEW_VERSION"
git push origin master
```

---

## 4. Best Practices & Policy Compliance
* **Never commit binary files** or `.tar.*` archives to the AUR git repository. The AUR repository must only track `PKGBUILD`, `.SRCINFO`, and any required local patch or install files.
* **Always run `makepkg --printsrcinfo > .SRCINFO`** before every commit. AUR uses `.SRCINFO` for package metadata parsing; if `.SRCINFO` is out of sync with `PKGBUILD`, AUR builds will fail.
* **Keep dependencies minimal**: Core utilities are in `depends`, optional integrations (`timeshift`, `gum`, `baloo`, `btrfs-progs`, etc.) belong in `optdepends`.
