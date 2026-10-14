# Universal Linux Housekeeping - Architecture & Development Roadmap

```text
███████╗ █████╗ ██████╗ ██████╗  ██████╗ ████████╗ ██████╗ ██╗  ██╗
╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔═══██╗╚██╗██╔╝
  ███╔╝ ███████║██████╔╝██████╔╝██║   ██║   ██║   ██║   ██║ ╚███╔╝ 
 ███╔╝  ██╔══██║██╔══██╗██╔══██╗██║   ██║   ██║   ██║   ██║ ██╔██╗ 
███████╗██║  ██║██║  ██║██║  ██║╚██████╔╝   ██║   ╚██████╔╝██╔╝ ██╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝

                 UNIVERSAL LINUX HOUSEKEEPING
               Linux Housekeeping Framework (Experimental)
                       Author: Zarrotox
                   Branch: universal-dev | Phase 1
```

**Project:** Universal Linux Housekeeping (Linux Housekeeping Framework)  
**Author:** Zarrotox  
**Branch:** `universal-dev` (Experimental Framework)  
**Reference Baseline:** CachyOS / Arch Linux Production Suite (`cachyos-housekeeping.sh` on `main`)

---

## Branch Status

### Main Branch
- ✅ **Stable**
- ✅ **Arch / CachyOS Reference Baseline**

### Universal-Dev Branch
- ⚠️ **Experimental**
- ⚠️ **Framework Development**
- ⚠️ **Not Yet Feature Complete**

---

## Development Roadmap & Milestones

### Phase 1 (Completed)
- ✅ **Distro Detection Engine** (`/etc/os-release` parsing for 10+ distributions)
- ✅ **Package Manager Detection** (`pacman`, `dnf`, `apt`, `zypper`, `flatpak`, `snap`)
- ✅ **Backend Dispatcher Interfaces** (`package_remove_orphans`, `package_clean_cache`, `package_update_metadata`)
- ✅ **Arch Reference Baseline** (`experimental/backends/arch.sh`)
- ✅ **Framework Stubs for Target Distros** (Fedora, Debian, openSUSE)
- ✅ **ZARROTOX Unified Branding & CLI Banner**
- ✅ **Cross-Distro Compatibility Matrix & Migration Strategy**

### Phase 2 (Planned)
- ⬜ **Fedora / Nobara Support** (`dnf` / `dnf5`, `rpmconf`)
- ⬜ **Debian / Ubuntu Support** (`apt-get --purge autoremove`, `apt-get clean`, `.dpkg-dist`)
- ⬜ **openSUSE Support** (`zypper packages --orphaned`, `zypper clean`)
- ⬜ **Containerized CI Validation Matrix** (`archlinux`, `fedora`, `ubuntu`, `opensuse`)

### Phase 3 (Planned)
- ⬜ **Immutable Distribution Support** (`/run/ostree-booted` detection)
- ⬜ **Fedora Silverblue & Kinoite**
- ⬜ **Bazzite & SteamOS Handheld Support**
- ⬜ **OSTree Read-Only System Protections** (`rpm-ostree cleanup`)

---

## 1. Architectural Vision

The Universal Linux Housekeeping Suite decouples platform-independent system maintenance (logs, caches, SSD trimming, snapshots, gaming files, user backups) from distribution-specific package operations.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CLI Dispatcher & Common Core Engine                  │
│       (Preflight, Snapshots, Journal Vacuum, Steam Orphan Sweeper,     │
│        Desktop Cache Wipe, Btrfs Scrub, SSD TRIM, Profile Backups)     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      Distribution Abstraction Layer                    │
│      detect_distribution() [/etc/os-release] & detect_package_manager()│
└──────────────┬────────────────────┬────────────────────┬───────────────┘
               │                    │                    │
               ▼                    ▼                    ▼
     ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
     │   Arch / CachyOS │ │  Fedora / Nobara │ │  Debian / Ubuntu │
     │  Backend (Pacman)│ │   Backend (DNF)  │ │   Backend (APT)  │
     └──────────────────┘ └──────────────────┘ └──────────────────┘
```

### Module Breakdown
- `experimental/distro/detect.sh`: Robust distribution detection supporting 10+ major distributions and 4 primary families.
- `experimental/distro/package_manager.sh`: Package manager identification and secondary tool discovery (`flatpak`, `snap`, AUR helpers).
- `experimental/backends/backend_interface.sh`: Unified contract exposing `package_remove_orphans`, `package_clean_cache`, `package_update_metadata`, and `package_scan_config_diffs`.
- `experimental/backends/*.sh`: Specific implementations for `arch`, `fedora`, `debian`, and `suse`.
- `experimental/compatibility/MATRIX.md`: Detailed cross-distribution feature support matrix.
- `experimental/docs/MIGRATION_STRATEGY.md`: Detailed analysis of portable vs. distro-bound functionality.

---

## 2. Portability Goals

1. **Zero Degradation of Reference Implementation:**
   The Arch Linux / CachyOS baseline must maintain 100% of its verified features and safety guarantees.
2. **Unified User Interface:**
   The CLI arguments (`-d` dry-run, `-s` safe-mode, `-m` modules, `-y` non-interactive) remain identical across all distributions.
3. **Fail-Safe Operational Safety:**
   - Pre-cleanup system rollback snapshots (via `snapper` or `timeshift`) remain mandatory prior to destructive tasks.
   - Protected path filtering (`safe_rm_rf`) prevents deletion of root, home root, and secondary drive mount points (`/run/media/*/*`).
4. **Graceful Degradation:**
   If a companion tool (such as Flatpak, Steam, or an AUR helper) is not present, the suite logs an informational notice and proceeds without failing.

---

## 3. Risks & Mitigations

| Risk | Description | Mitigation Strategy |
| :--- | :--- | :--- |
| **Aggressive Orphan Purging** | Different package managers interpret dependencies differently. For instance, `apt autoremove` may propose removing packages marked as manual dependencies if recommends were disabled. | Maintain `SAFE_MODE` as default when unconfirmed. Require explicit operator confirmation before destructive removal. |
| **DNF Keepcache Inconsistency** | Fedora/Nobara systems rarely enable `keepcache=1` by default; package caches might be minimal, meaning disk reclaim may appear smaller than on Arch. | Document expected reclaim values per distro family. Provide deep vs. light cache clean options. |
| **OSTree / Immutable Distros** | Distributions like Fedora Silverblue, Bazzite, and SteamOS have read-only `/usr` and `/var` mount structures. Regular package managers fail. | Detect OSTree via `/run/ostree-booted` and disable standard package manager modules. |
| **Broken Symlink False Positives** | Non-Arch systems may store active symlinks across varying container or snap roots (`/var/snap`). | Expand directory pruning in `find -xtype l` to prune `/snap`, `/var/snap`, and flatpak paths. |

---

## 4. Unsupported Features in Universal Mode (By Design)

1. **CachyOS Custom Kernel Optimization:**
   Kernel package flags, Bcachefs scheduler tuning, and proprietary repository mirrors will remain exclusive to CachyOS.
2. **AUR Build Helpers on Non-Arch Systems:**
   AUR cleanup logic (`paru`, `yay`) is suppressed on non-Arch platforms.
3. **Direct File Conflicts (pacdiff):**
   `pacdiff` will only run on Arch-based distributions; Fedora will invoke `rpmconf`, while Debian systems will scan for `.dpkg-dist`.

---

## 5. Testing Requirements & Verification Matrix

### Container Testing Suite
Phase 2 requires automated container integration testing across reference container images:
- `archlinux:latest` & `cachyos/cachyos:latest`
- `fedora:41` & `fedora:latest`
- `ubuntu:24.04` (Noble) & `debian:12` (Bookworm)
- `opensuse/tumbleweed:latest`

### Verification Checklist per Backend
- [x] Correctly identifies distro ID, family, and version in `detect_distribution()`.
- [x] Accurately detects primary and secondary package managers.
- [x] Safe simulation under `DRY_RUN=true`.
- [x] Safe bypass of all deletions under `SAFE_MODE=true`.
- [x] Accurate calculation of freed bytes without string contamination on stdout.
- [x] Validated non-zero exit codes on protected path violations.
- [x] ShellCheck clean with zero warnings under standard CI.
