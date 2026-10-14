# Migration Strategy: From CachyOS Suite to Universal Linux Housekeeping

This document outlines the systematic strategy for expanding the production CachyOS Housekeeping Suite into a modular, multi-distribution framework.

---

## 1. Distribution Classification & Current Status

### Distribution Tiers
| Tier | Distributions | Package Manager | Snapshot Tooling | Status in Framework |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (Reference)** | CachyOS, Arch Linux, EndeavourOS | `pacman` + `paccache` (AUR: `paru`, `yay`) | Snapper / Timeshift | **Fully Implemented** (Verified Baseline) |
| **Tier 2 (Planned)** | Fedora, Nobara | `dnf` / `dnf5` | Snapper / Timeshift | **Framework Stub** (Phase 2 Target) |
| **Tier 3 (Planned)** | Ubuntu, Linux Mint, Pop!_OS, Debian | `apt` / `apt-get` | Timeshift | **Framework Stub** (Phase 2 Target) |
| **Tier 4 (Planned)** | openSUSE (Tumbleweed, Leap) | `zypper` | Snapper (Default) | **Framework Stub** (Phase 3 Target) |

---

## 2. What Currently Works Universally Across Distros

The following components already adhere to POSIX/GNU standards or FreeDesktop specifications, making them portable without modification:

1. **System Safety & Rollback:**
   - `Timeshift` works identically on Arch, Ubuntu, Mint, Fedora, and Debian.
   - `Snapper` works identically on openSUSE, CachyOS, Arch, and configured Fedora workstations.
2. **Systemd Log Sanitization:**
   - `journalctl --vacuum-size=500M` operates identically on all modern systemd distros.
3. **Core Dump Cleanup:**
   - Standard `/var/lib/systemd/coredump` directory emptying works universally.
4. **Desktop Environment (KDE Plasma):**
   - KDE Baloo indexer (`balooctl6 purge` or `balooctl purge`) is desktop-specific, not distro-specific.
   - FreeDesktop thumbnail cache (`~/.cache/thumbnails`) is identical across all desktop environments.
   - Kdenlive proxy clips and cache directories (`~/.local/share/kdenlive`, `~/.cache/kdenlive`) are desktop-agnostic.
5. **Storage & Hardware Maintenance:**
   - `btrfs scrub start -B` is standard across any distribution with Btrfs root partitions.
   - `fstrim -av` is a standard util-linux command present on all modern Linux installations.
6. **Gaming Subsystem (Valve Steam Sweeper):**
   - Valve Steam directory layout (`steamapps/libraryfolders.vdf`, `shadercache/`, `compatdata/`) is standardized by Steam runtime across all distributions.
   - Secondary mount depth handling (`/run/media/*/*/*`) is standardized by `udisks2` and KDE across all distributions.
7. **Desktop Configuration Backup:**
   - GNU `tar --zstd` archiving of selected configuration directories is fully universal.
8. **Universal App Runtimes:**
   - `flatpak uninstall --unused -y` works across all distros with Flatpak installed.

---

## 3. What is Arch / CachyOS-Specific

The following features depend on the Arch Linux packaging ecosystem:

1. **Orphan Package Detection:**
   - Relies on `pacman -Qtdq` to query unneeded dependencies.
   - Purges with cascade uninstallation `pacman -Rns --noconfirm`.
2. **Package Cache Maintenance:**
   - Uses `paccache -rk2` (provided by `pacman-contrib`) to keep the latest two versions while discarding obsolete tarballs from `/var/cache/pacman/pkg`.
3. **AUR Build Caches:**
   - Cleans `~/.cache/paru` and `~/.cache/yay` build trees.
4. **Configuration Merge Conflicts:**
   - Uses `pacdiff` to detect and merge `.pacnew` and `.pacsave` files.
5. **Kernel & Microcode Optimizations:**
   - CachyOS custom kernel repository flags and Bcachefs/Btrfs scheduler optimizations.

---

## 4. Required Changes for Fedora / Nobara (Phase 2)

### Package Management (`dnf` / `dnf5`)
- **Orphan Removal:** Replace `pacman -Qtdq` with `dnf autoremove -y` (or `dnf5 autoremove -y`).
- **Cache Trimming:** 
  - Standard DNF retains metadata and packages in `/var/cache/libdnf5` or `/var/cache/dnf`.
  - Use `dnf clean packages` (or `dnf clean all` for deep cleanup).
  - Note: DNF does not maintain a multi-version tarball cache like `paccache` by default unless `keepcache=1` is explicitly set in `/etc/dnf/dnf.conf`.
- **Third-Party Repositories:** Add Copr cache scanning if applicable.
- **Configuration Conflicts:** Replace `pacdiff` with `rpmconf -a` (detects `.rpmnew` and `.rpmsave` files).
- **Snapshot Tooling:** Default to `snapper` if configured, or `timeshift`.

---

## 5. Required Changes for Debian / Ubuntu / Mint / Pop!_OS (Phase 2)

### Package Management (`apt`)
- **Orphan Removal:** Replace `pacman -Qtdq` with `apt-get --purge autoremove -y`. The `--purge` flag ensures leftover configuration files (`rc` state in dpkg) are removed.
- **Cache Trimming:** 
  - Replace `paccache` with `apt-get autoclean` (removes packages no longer downloadable) and `apt-get clean` (clears `/var/cache/apt/archives`).
- **Configuration Conflicts:** 
  - Scan for `.dpkg-dist` and `.dpkg-old` in `/etc`.
- **Snap Maintenance (Ubuntu-specific):**
  - Ubuntu systems frequently run Canonical Snap. Disabled/superseded Snap revisions accumulate in `/var/lib/snapd/snaps`.
  - Add an optional Snap garbage collection loop:
    ```bash
    snap list --all | awk '/disabled/{print $1, $3}' |
        while read -r snapname revision; do
            snap remove "$snapname" --revision="$revision"
        done
    ```
- **Snapshot Tooling:** Default to `timeshift` (primary backup utility on Linux Mint and Ubuntu).

---

## 6. Required Changes for openSUSE (Phase 3)

### Package Management (`zypper`)
- **Orphan Removal:** Use `zypper packages --orphaned` or `zypper rm -u`.
- **Cache Trimming:** Use `zypper clean --all` (clears `/var/cache/zypp`).
- **Configuration Conflicts:** Use `rpmconf -a` or inspect `.rpmnew`.
- **Snapshot Tooling:** openSUSE natively integrates `snapper` with Btrfs root out-of-the-box (`snapper -c root create`).
