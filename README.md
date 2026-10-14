# Universal Linux Housekeeping Framework

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

[![CI](https://github.com/Zarrotox/cachyos-housekeeping/actions/workflows/ci.yml/badge.svg)](https://github.com/Zarrotox/cachyos-housekeeping/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Zarrotox/cachyos-housekeeping)](https://github.com/Zarrotox/cachyos-housekeeping/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Arch%20%7C%20Fedora%20%7C%20Debian%20%7C%20openSUSE-00d1b2.svg)](#)

**Author**: Zarrotox  
**Branch**: `universal-dev` (Experimental Framework)  
**Reference Baseline**: CachyOS / Arch Linux Production Suite (`main` branch)  

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

## Overview

The **Universal Linux Housekeeping Framework** is an experimental cross-distribution maintenance framework engineered to consolidate system sanitization, telemetry, performance optimization, and backup generation across major Linux distributions.

- **Main Branch (`main`)**: The production-hardened, stable CachyOS and Arch Linux reference implementation (`cachyos-housekeeping.sh`).
- **Universal Branch (`universal-dev`)**: The forward-looking cross-distribution framework introducing modular abstraction layers for Fedora/Nobara, Debian/Ubuntu, and openSUSE.

---

## Development Roadmap

### Phase 1 (Completed)
- ✅ **Distro Detection Engine**: Parses `/etc/os-release` across 10+ distributions.
- ✅ **Package Manager Detection**: Identifies `pacman`, `dnf`, `apt`, `zypper`, `flatpak`, and `snap`.
- ✅ **Backend Interfaces**: Standardized dispatchers for orphan removal, cache trimming, and metadata updates.
- ✅ **Arch Baseline**: Reference implementation preserved.
- ✅ **Stubs Created**: Initial scaffolding for Fedora, Debian, and openSUSE.
- ✅ **ZARROTOX Branding**: Stylized ASCII banner and unified identity.

### Phase 2 (In Progress - Active Development)
- ✅ **Fedora / Nobara Concrete Backend**: Integrated `dnf5` and `dnf` with `makecache --refresh`, `autoremove`, `clean all`, and `.rpmnew`/`.rpmsave` detection.
- ✅ **Debian / Ubuntu / Mint / Pop Concrete Backend**: Integrated `apt-get` with noninteractive environment, `--purge autoremove`, `autoclean`, `clean`, disabled Snap revision pruning, and `.dpkg-*`/`.ucf-*` conflict scans.
- ✅ **Driver Execution Control**: Added `--apply` / `--execute` for live changes, `--yes` / `--no-safe-mode` for non-interactive execution, and `--help` / `-h` usage instructions.
- ⬜ **openSUSE Support**: Full `zypper` backend implementation.
- ⬜ **Multi-Distro CI**: Container validation across Fedora, Ubuntu, and Arch.

### Phase 3 (Planned)
- ⬜ **Immutable Distribution Support**: Detection of atomic systems (`/run/ostree-booted`).
- ⬜ **Fedora Silverblue & Kinoite**
- ⬜ **Bazzite & SteamOS Handheld Support**
- ⬜ **OSTree Read-Only Root Protections**: `rpm-ostree cleanup` integration.

---

## Why This Exists

Power users and Linux gamers often juggle multiple disconnected tools for package cache trimming, orphan package sweeps, Steam shadercache cleaning, Flatpak runtime pruning, desktop indexer maintenance, filesystem scrubs, and profile backups.

Universal Linux Housekeeping unifies these workflows into a single safety-focused framework:

- Dual snapshot rollback protection (Snapper & Timeshift)
- Dry-run simulation & Safe Mode execution
- Multi-drive Steam shadercache orphan cleaning & compatdata protection
- FreeDesktop & desktop environment cache sanitization
- Telemetry reporting of freed bytes
- Btrfs maintenance and SSD TRIM
- Atomic profile configuration backups (`tar --zstd`)

---

## Screenshot

<!-- TODO: Replace with actual screenshot after first production validation run -->

---

## Table of Contents

- [Why This Exists](#why-this-exists)
- [Screenshot](#screenshot)
- [Installation](#installation)
  - [Method 1: Local PKGBUILD Build](#method-1-local-pkgbuild-build)
  - [Method 2: Standalone Script Installation](#method-2-standalone-script-installation)
  - [Planned: Arch User Repository (AUR)](#planned-arch-user-repository-aur)
- [Operational Modes: Standard vs Safe Mode vs Dry-Run](#operational-modes-standard-vs-safe-mode-vs-dry-run)
- [Interactive Module Selector](#interactive-module-selector)
- [Steam Orphan Safety & Compatdata Preservation](#steam-orphan-safety--compatdata-preservation)
- [Advanced System Monitors](#advanced-system-monitors)
  - [A. Journal Growth Monitor](#a-journal-growth-monitor)
  - [B. KDE Baloo Index Fragmentation Check](#b-kde-baloo-index-fragmentation-check)
  - [C. Steam Shadercache Performance Monitor](#c-steam-shadercache-performance-monitor)
- [Prerequisites & Package Requirements](#prerequisites--package-requirements)
- [CLI Options & Usage Guide](#cli-options--usage-guide)
  - [CLI Syntax](#cli-syntax)
  - [Command Examples](#command-examples)
- [Detailed 5-Step Pipeline](#detailed-5-step-pipeline)
  - [Step 0: Preflight Verification](#step-0-preflight-verification)
  - [Step 1: System Safety (Snapper / Timeshift Snapshot)](#step-1-system-safety-snapper--timeshift-snapshot)
  - [Step 2: Arch Package Cleanup](#step-2-arch-package-cleanup)
  - [Step 3: Advanced Deep Maintenance (Btrfs, Baloo, Journal)](#step-3-advanced-deep-maintenance-btrfs-baloo-journal)
  - [Step 4: Multi-Drive Steam Orphan Sweeper](#step-4-multi-drive-steam-orphan-sweeper)
  - [Step 5: Proton Drive Payload & Notifications](#step-5-proton-drive-payload--notifications)
- [Log Files & Telemetry](#log-files--telemetry)
- [Aliases & Shortcuts](#aliases--shortcuts)
- [Changelog & Documentation](#changelog--documentation)
- [AUR Publication & Maintenance](#aur-publication--maintenance)
- [AI Assistance Disclosure](#ai-assistance-disclosure)
- [License](#license)

---

> [!WARNING]
> This utility performs system maintenance operations including package cleanup,
> cache removal, Steam shader cache cleanup, configuration backups,
> and filesystem maintenance.
>
> Always perform an initial `--dry-run` before first use.

## Installation

### Method 1: Local PKGBUILD Build

You can build and install the native Arch package locally using `makepkg`:

```bash
git clone https://github.com/Zarrotox/cachyos-housekeeping.git
cd cachyos-housekeeping
makepkg -si
```

This installs `/usr/bin/cachyos-housekeeping`, the `/usr/bin/cachy-clean` symlink, license, and documentation into standard system paths.

### Method 2: Standalone Script Installation

You can also install the standalone script directly without `makepkg`:

```bash
git clone https://github.com/Zarrotox/cachyos-housekeeping.git
cd cachyos-housekeeping
sudo install -Dm755 cachyos-housekeeping.sh /usr/local/bin/cachyos-housekeeping
sudo ln -sf /usr/local/bin/cachyos-housekeeping /usr/local/bin/cachy-clean
```

### Planned: Arch User Repository (AUR)

> [!WARNING]
> AUR publication is planned but not yet released.
> The package is currently undergoing final validation testing.
> Installation via Git clone or manual PKGBUILD is recommended until testing is completed.

Once published, package installation via AUR helpers will be supported:

```bash
# Future usage:
# paru -S cachyos-housekeeping
# yay -S cachyos-housekeeping
```

---

## Operational Modes: Standard vs Safe Mode vs Dry-Run

| Feature | Standard Mode | Safe Mode (`-s`) | Dry-Run (`-d`) |
| :--- | :--- | :--- | :--- |
| **System Snapshot (Snapper/Timeshift)** | Creates snapshot | Creates snapshot | Simulated |
| **Btrfs Scrub** | Executes | Executes | Simulated |
| **SSD fstrim** | Executes | Executes | Simulated |
| **Journal Vacuum** | Executes | Executes | Simulated |
| **Config Backup (`.tar.zst`)** | Creates archive | Creates archive | Simulated |
| **Pacman Orphan Removal** | Deletes packages | **BLOCKED** (Report only) | Simulated |
| **Pacman Cache Prune** | Deletes old packages | **BLOCKED** | Simulated |
| **`rm -rf` Deletions** | Active | **BLOCKED** | Simulated |
| **Steam Shader Removal** | Deletes orphans | **BLOCKED** (Report only) | Simulated |
| **Steam Compatdata Purge** | **BLOCKED** (Report only) | **BLOCKED** (Report only) | **BLOCKED** (Report only) |

> [!TIP]
> **Safe Mode** is for "real maintenance, zero deletions" runs. If you're ever unsure, use this.

1. **Standard Mode**: Full automated maintenance with pre-run system safety snapshot (Snapper or Timeshift).
2. **Safe Mode (`--safe-mode`)**: Executes all health diagnostics, filesystem maintenance, journal vacuuming, and backups, but strictly blocks any `rm -rf` file deletions and package removals.
3. **Dry-Run Mode (`--dry-run`)**: Simulates all operations, displaying projected reclaimable space without modifying disks.

---

## Interactive Module Selector

When launched without `--all` or `--modules`, an interactive checklist prompts you to choose which modules to run:

- [ ] **Pacman cleanup**: Orphaned dependencies and package cache trimming
- [ ] **AUR helper cleanup**: `paru` and `yay` build cache wipe
- [ ] **Flatpak cleanup**: Unused runtimes and application dependencies
- [ ] **KDE Plasma & caches**: Baloo indexer, Kdenlive proxies, thumbnails, broken symlinks
- [ ] **Steam orphan sweeper**: Abandoned shader caches across multi-drive libraries
- [ ] **Btrfs scrub & SSD TRIM**: Filesystem verification and TRIM dispatch
- [ ] **Configuration backup**: Lightweight desktop config archive for Proton Drive

---

## Steam Orphan Safety & Compatdata Preservation

> [!IMPORTANT]
> **Zero Save Data Loss Policy**: Steam's `compatdata/<AppID>` folders frequently store game saves, Wine configuration prefixes, and non-cloud user progress. The suite **never** automatically deletes `compatdata` folders, even if an AppID is absent from your library. It inspects them and reports them as candidates for manual review. Only disposable, regenerated numerical folders in `shadercache/` are eligible for cleanup.

---

## Advanced System Monitors

### A. Journal Growth Monitor

Before vacuuming journal archives, the suite queries storage consumption:

```bash
journalctl --disk-usage
```

The exact byte count is recorded in `/var/log/cachyos-housekeeping.log` to track long-term journal growth.

### B. KDE Baloo Index Fragmentation Check

Baloo's LMDB index storage engine fragments heavily over time, splitting into multiple `index-*` chunks. The suite checks:

```bash
frag_count=$(find "$baloo_dir" -maxdepth 1 -type f -name "index-*" | wc -l)
```

If `frag_count > 20`, severe fragmentation is logged, prompting an index rebuild.

### C. Steam Shadercache Performance Monitor

Queries and records total disk allocation for shader caches on all discovered Steam library partitions before any sweeping takes place:

```bash
du -sh "$lib/steamapps/shadercache"
```

---

## Prerequisites & Package Requirements

The following packages are installed automatically when using the package:

| Category | Package | Purpose |
| :--- | :--- | :--- |
| **Mandatory** | `bash` | Shell interpreter (>= 5.0) |
| **Mandatory** | `pacman-contrib` | Provides `paccache` for package cache pruning |
| **Mandatory** | `coreutils`, `findutils`, `grep`, `sed`, `gawk`, `tar`, `zstd` | Standard POSIX & compression tooling |
| **Recommended**| `gum` | Modern Charmbracelet CLI for the interactive module checklist |
| **Fallback** | `whiptail` | Standard dialog-based TUI menu when `gum` is absent |
| **Safety** | `snapper` / `timeshift` | Automated system safety snapshot creation (Snapper native on CachyOS Btrfs, Timeshift fallback) |
| **Desktop** | `libnotify` | Pushes native KDE Plasma desktop completion alerts |
| **Optional** | `paru` / `yay` | AUR cache cleanup |
| **Optional** | `flatpak` | Unused Flatpak runtime uninstaller |
| **Optional** | `baloo` | KDE Plasma file indexing tools (`balooctl6` / `balooctl`) |

---

## CLI Options & Usage Guide

### CLI Syntax

```text
Usage: sudo cachyos-housekeeping [OPTIONS]

Execution Modes:
  -d, --dry-run             Simulate all operations without modifying or deleting files.
  -s, --safe-mode           Execute non-destructive tasks (Snapper/Timeshift, btrfs scrub, fstrim,
                            journal vacuum, backup) while strictly prohibiting all 'rm -rf'
                            and uninstallation deletions.

Module Selection:
  -a, --all                 Execute all modules without prompting the module selector.
  -m, --modules <LIST>      Comma-separated list of modules to execute.
                            Available: pacman, aur, flatpak, kde, steam, btrfs, backup

Automation & Overrides:
  -y, --yes                 Unattended mode: bypass interactive execution confirmation.
  -u, --target-user <USER>  Explicitly specify the desktop target username for permissions,
                            paths, and DBus notifications.

Information:
  -v, --version             Print script version and exit.
  -h, --help                Display this help message and exit.
```

### Command Examples

```bash
# Standard interactive execution
sudo cachyos-housekeeping

# Safe Mode: Full health checks, scrub, journal vacuum, and backup; zero deletions
sudo cachyos-housekeeping --safe-mode

# Dry-run simulation: Show exactly what would be cleaned without touching disks
sudo cachyos-housekeeping --dry-run

# Run non-interactively for automated cron / maintenance timers
sudo cachyos-housekeeping -a -y

# Select specific modules non-interactively
sudo cachyos-housekeeping -m pacman,steam,btrfs -y
```

---

## Detailed 5-Step Pipeline

### Step 0: Preflight Verification
Verifies presence of core utilities, snapshot backend (`snapper` or `timeshift`), pacman-contrib, and desktop context before executing any operations.

### Step 1: System Safety (Snapper / Timeshift Snapshot)
Always runs prior to cleanup modules to ensure rollback protection. Automatically detects and utilizes native `snapper` (default on CachyOS Btrfs) or `timeshift`. If snapshot creation fails, the script immediately halts execution.

### Step 2: Arch Package Cleanup
- **Pacman**: `pacman -Qtdq` orphan detection and `paccache -rk2` trimming.
- **AUR**: Prunes `paru` and `yay` caches.
- **Flatpak**: Uninstalls unused runtimes via `flatpak uninstall --unused -y`.

### Step 3: Advanced Deep Maintenance (Btrfs, Baloo, Journal)
- **Journal**: Records `journalctl --disk-usage` before vacuuming to 2 weeks.
- **Coredumps**: Empties `/var/lib/systemd/coredump` safely via `safe_empty_directory`.
- **Baloo**: Evaluates fragmentation and index size; conditionally runs `suspend` → `purge` → `check` only if corrupt or bloated (>500MB).
- **Caches**: Wipes Kdenlive proxies and thumbnail cache.
- **Btrfs Scrub & SSD TRIM**: Runs foreground `btrfs scrub start -Bd /` and `fstrim -av`.
- **Pacnew Scan**: Searches `/etc` for `.pacnew` / `.pacsave` configuration files.

### Step 4: Multi-Drive Steam Orphan Sweeper
- Parses `libraryfolders.vdf` with robust `sed` and `awk`.
- Measures shadercache storage size across every drive for gaming performance analysis.
- Scans `appmanifest_<AppID>.acf` across libraries to build an installed game array.
- Deletes uninstalled numerical AppID folders in `shadercache/`.
- **Safely preserves** `compatdata/` folders (reporting them as candidates to protect user save files).

### Step 5: Proton Drive Payload & Notifications
- Archives `~/.config` (excluding heavy browser and Electron application profiles such as Brave, Chrome, LibreWolf, Firefox, Discord, Vesktop, Code, and volatile caches/locks to keep the Proton Drive archive lightweight), shell RCs (`.bashrc`, `.zshrc`), and lightweight KDE folders (`konsole`, `plasma`, `kxmlgui5`, `kxmlgui6`, `kdenlive`, `color-schemes`, `dolphin`, `plasma-systemmonitor`, `applications`), avoiding heavy game/Steam directories.
- Writes to temporary archive atomically and moves to `~/Desktop/CachyOS-Config-Backup-YYYY-MM-DD_HH-MM-SS.tar.zst`.
- Restricts archive permissions to mode `0600` under `$TARGET_USER:$TARGET_GROUP`.
- Prints the **Disk Reclamation Summary Table** accompanied by the **Session Profile Footer** (`Mode: ...`, `Modules executed: ...`, `Status: ...`) and logs it to `/var/log/cachyos-housekeeping.log`.
- Sends a native desktop alert to the active KDE session via `notify-send`.

---

## Log Files & Telemetry

Full execution logs, journal trends, and shader metrics are appended to:

```text
/var/log/cachyos-housekeeping.log
```

To follow active housekeeping logs in real time:

```bash
tail -f /var/log/cachyos-housekeeping.log
```

For long‑term operational longevity, consider adding this log to your system's `logrotate` configuration (e.g. `/etc/logrotate.d/cachyos-housekeeping`).

---

## Aliases & Shortcuts

If using the installed package, `cachy-clean` is already available as a system symlink. If running the standalone script, you can add these aliases to your `~/.bashrc` or `~/.zshrc`:

```bash
alias cachy-clean="sudo cachyos-housekeeping"
alias cachy-safe="sudo cachyos-housekeeping --safe-mode"
alias cachy-dry="sudo cachyos-housekeeping --dry-run"
```

---

## Changelog & Documentation

For detailed release history and version-by-version changes, see the [Changelog](CHANGELOG.md).

Maintainers and contributors can find package publication procedures in the [AUR Publishing Guide](AUR_PUBLISHING.md).

---

## AUR Publication & Maintenance

Maintainers can publish or update this package on the Arch User Repository using the instructions in [AUR_PUBLISHING.md](AUR_PUBLISHING.md). The repository includes an audited [PKGBUILD](PKGBUILD), [.SRCINFO](.SRCINFO), and automated GitHub Actions CI & release packaging workflows.

---

## AI Assistance Disclosure

This project was developed with significant AI assistance during design, implementation, refactoring, documentation, packaging, and review.

AI tools were used to help generate code, propose architectural changes, identify bugs, review implementations, create documentation, and produce packaging and CI/CD assets. However, all generated code and recommendations were manually reviewed, tested, modified, and integrated by the project maintainer.

The maintainer remains solely responsible for:

- Project direction and feature decisions
- Code review and acceptance
- Testing and validation
- Bug fixes and maintenance
- Security and safety decisions
- Releases and package publication

AI-generated code should not be assumed correct by default. Features and changes included in this repository are expected to undergo the same review, testing, and validation process as any other contribution.

If you find a bug, unsafe behavior, packaging issue, or logic error, please open an issue on GitHub. Feedback and code review are always welcome.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
