# CachyOS & KDE Plasma Comprehensive Housekeeping Suite

[![CI](https://github.com/Zarrotox/cachyos-housekeeping/actions/workflows/ci.yml/badge.svg)](https://github.com/Zarrotox/cachyos-housekeeping/actions/workflows/ci.yml)
[![AUR version](https://img.shields.io/aur/version/cachyos-housekeeping)](https://aur.archlinux.org/packages/cachyos-housekeeping)
[![Release](https://img.shields.io/github/v/release/Zarrotox/cachyos-housekeeping)](https://github.com/Zarrotox/cachyos-housekeeping/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Arch / CachyOS](https://img.shields.io/badge/Platform-CachyOS%20%2F%20Arch%20Linux-00d1b2.svg)](#)

**Version**: `2026.10.15`  
**Author**: Zarrotox  
**Target OS**: CachyOS / Arch Linux with KDE Plasma 6  

**TL;DR:**  
Run `sudo cachyos-housekeeping` (or `sudo ./cachyos-housekeeping.sh`) for an interactive cleanup,  
`--safe-mode` for non-destructive maintenance,  
or `--dry-run` to simulate everything.

A hardened, sysadmin-grade Bash maintenance, performance-tuning, and backup automation suite designed for manual execution via `sudo` or automated packaging through the Arch User Repository (AUR).

---

## Table of Contents

- [Installation](#installation)
  - [Method 1: Arch User Repository (AUR)](#method-1-arch-user-repository-aur)
  - [Method 2: Manual PKGBUILD Build](#method-2-manual-pkgbuild-build)
  - [Method 3: Standalone Script Clone](#method-3-standalone-script-clone)
- [Operational Modes: Standard vs Safe Mode vs Dry-Run](#operational-modes-standard-vs-safe-mode-vs-dry-run)
- [Interactive Module Selector](#interactive-module-selector)
- [Steam Orphan Safety & Compatdata Preservation](#steam-orphan-safety--compatdata-preservation)
- [Advanced System Monitors](#advanced-system-monitors)
  - [A. Journal Growth Monitor](#a-journal-growth-monitor)
  - [B. KDE Baloo Index Fragmentation Check](#b-kde-baloo-index-fragmentation-check)
  - [C. Steam Shadercache Performance Monitor](#c-steam-shadercache-performance-monitor)
- [Prerequisites & Package Requirements](#prerequisites--package-requirements)
- [CLI Options & Usage Guide](#cli-options--usage-guide)
- [Detailed 5-Step Pipeline](#detailed-5-step-pipeline)
  - [Step 0: Preflight Verification](#step-0-preflight-verification)
  - [Step 1: System Safety (Timeshift Failsafe)](#step-1-system-safety-timeshift-failsafe)
  - [Step 2: Arch Package Cleanup](#step-2-arch-package-cleanup)
  - [Step 3: Advanced Deep Maintenance (Btrfs, Baloo, Journal)](#step-3-advanced-deep-maintenance-btrfs-baloo-journal)
  - [Step 4: Multi-Drive Steam Orphan Sweeper](#step-4-multi-drive-steam-orphan-sweeper)
  - [Step 5: Proton Drive Payload & Notifications](#step-5-proton-drive-payload--notifications)
- [Log Files & Telemetry](#log-files--telemetry)
- [Aliases & Shortcuts](#aliases--shortcuts)
- [Changelog & Documentation](#changelog--documentation)
- [AUR Publication & Maintenance](#aur-publication--maintenance)
- [License](#license)

---

## Installation

### Method 1: Arch User Repository (AUR)
The recommended installation method on CachyOS and Arch Linux is via your preferred AUR helper:

```bash
# Using paru (standard on CachyOS)
paru -S cachyos-housekeeping

# Using yay
yay -S cachyos-housekeeping
```

Once installed, the command `cachyos-housekeeping` and its short alias `cachy-clean` are immediately available system-wide:
```bash
sudo cachyos-housekeeping
# or
sudo cachy-clean
```

### Method 2: Manual PKGBUILD Build
```bash
git clone https://aur.archlinux.org/cachyos-housekeeping.git
cd cachyos-housekeeping
makepkg -si
```

### Method 3: Standalone Script Clone
```bash
git clone https://github.com/Zarrotox/cachyos-housekeeping.git
cd cachyos-housekeeping
sudo install -Dm755 cachyos-housekeeping.sh /usr/local/bin/cachyos-housekeeping
sudo ln -sf /usr/local/bin/cachyos-housekeeping /usr/local/bin/cachy-clean
```

---

## Operational Modes: Standard vs Safe Mode vs Dry-Run

```
┌─────────────────────────┬───────────────────┬──────────────────┬─────────────────┐
│ Feature                 │ Standard Mode     │ Safe Mode (-s)   │ Dry-Run (-d)    │
├─────────────────────────┼───────────────────┼──────────────────┼─────────────────┤
│ Timeshift Snapshot      │ Creates snapshot  │ Creates snapshot │ Simulated       │
│ Btrfs Scrub             │ Executes          │ Executes         │ Simulated       │
│ SSD fstrim              │ Executes          │ Executes         │ Simulated       │
│ Journal Vacuum          │ Executes          │ Executes         │ Simulated       │
│ Config Backup (.tar.zst)│ Creates archive   │ Creates archive  │ Simulated       │
│ Pacman Orphan Removal   │ Deletes packages  │ BLOCKED (Report) │ Simulated       │
│ Pacman Cache Prune      │ Deletes old pkgs  │ BLOCKED          │ Simulated       │
│ rm -rf Operations       │ Active            │ BLOCKED          │ Simulated       │
│ Steam Shader Removal    │ Deletes orphans   │ BLOCKED (Report) │ Simulated       │
│ Steam Compatdata Purge  │ BLOCKED (Report)  │ BLOCKED (Report) │ BLOCKED (Report)│
└─────────────────────────┴───────────────────┴──────────────────┴─────────────────┘
```

> [!TIP]
> **Safe Mode** is for "real maintenance, zero deletions" runs. If you're ever unsure, use this.

1. **Standard Mode**: Full automated maintenance with pre-run Timeshift safety snapshot.
2. **Safe Mode (`--safe-mode`)**: Executes all health diagnostics, filesystem maintenance, journal vacuuming, and backups, but strictly blocks any `rm -rf` file deletions and package removals.
3. **Dry-Run Mode (`--dry-run`)**: Simulates all operations, displaying projected reclaimable space without modifying disks.

---

## Interactive Module Selector

When launched without `--all` or `--modules`, an interactive checklist prompts you to choose which modules to run:

- `[ ] Pacman cleanup` (orphaned dependencies and package cache trimming)
- `[ ] AUR helper cleanup` (paru and yay build cache wipe)
- `[ ] Flatpak cleanup` (unused runtimes and application dependencies)
- `[ ] KDE Plasma & caches` (Baloo indexer, Kdenlive proxies, thumbnails, broken symlinks)
- `[ ] Steam orphan sweeper` (abandoned shader caches across multi-drive libraries)
- `[ ] Btrfs scrub & SSD TRIM` (filesystem verification and TRIM dispatch)
- `[ ] Configuration backup` (lightweight desktop config archive for Proton Drive)

---

## Steam Orphan Safety & Compatdata Preservation

> [!IMPORTANT]
> **Zero Save Data Loss Policy**: Steam's `compatdata/<AppID>` folders frequently store game saves, Wine configuration prefixes, and non-cloud user progress. The suite **never** automatically deletes `compatdata` folders, even if an AppID is absent from your library. It inspects them and reports them as candidates for manual review. Only disposable, regenerated numerical folders in `shadercache/` are eligible for cleanup.

---

## Advanced System Monitors

### A. Journal Growth Monitor
Before vacuuming journal archives, the suite queries:
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
Queries and records total disk allocation for shader caches on all discovered Steam library partitions before any sweeping takes place.

---

## Prerequisites & Package Requirements

The following packages are installed automatically when using the AUR package:

| Category | Package | Purpose |
| :--- | :--- | :--- |
| **Mandatory** | `bash` | Shell interpreter ($\ge$ 5.0) |
| **Mandatory** | `pacman-contrib` | Provides `paccache` for package cache pruning |
| **Mandatory** | `coreutils`, `findutils`, `grep`, `sed`, `gawk`, `tar`, `zstd` | Standard POSIX & compression tooling |
| **Recommended**| `gum` | Modern Charmbracelet CLI for the interactive module checklist |
| **Fallback** | `whiptail` | Standard dialog-based TUI menu when `gum` is absent |
| **Safety** | `timeshift` | Automated system restore snapshot creation |
| **Desktop** | `libnotify` | Pushes native KDE Plasma desktop completion alerts |
| **Optional** | `paru` / `yay` | AUR cache cleanup |
| **Optional** | `flatpak` | Unused Flatpak runtime uninstaller |
| **Optional** | `baloo` | KDE Plasma file indexing tools (`balooctl6` / `balooctl`) |

---

## CLI Options & Usage Guide

```text
Usage: sudo cachyos-housekeeping [OPTIONS]

Execution Modes:
  -d, --dry-run             Simulate all operations without modifying or deleting files.
  -s, --safe-mode           Execute non-destructive tasks (Timeshift, btrfs scrub, fstrim,
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

### Examples
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
Verifies presence of core utilities, Timeshift, pacman-contrib, and desktop context before executing any operations.

### Step 1: System Safety (Timeshift Failsafe)
Always runs prior to cleanup modules to ensure rollback protection. If snapshot creation fails, the script immediately halts execution.

### Step 2: Arch Package Cleanup
- **Pacman**: `pacman -Qtdq` orphan detection and `paccache -rk2` trimming.
- **AUR**: Prunes `paru` and `yay` caches.
- **Flatpak**: Uninstalls unused runtimes (`flatpak uninstall --unused -y`).

### Step 3: Advanced Deep Maintenance (Btrfs, Baloo, Journal)
- **Journal**: Records `journalctl --disk-usage` before vacuuming to 2 weeks.
- **Coredumps**: Empties `/var/lib/systemd/coredump` safely via `safe_empty_directory`.
- **Baloo**: Evaluates fragmentation and index size; conditionally runs `suspend` $\rightarrow$ `purge` $\rightarrow$ `check` only if corrupt or bloated (>500MB).
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
- Archives `~/.config`, shell RCs (`.bashrc`, `.zshrc`), and lightweight KDE folders (`konsole`, `plasma`, `kxmlgui5`, `kxmlgui6`, `kdenlive`, `color-schemes`, `dolphin`, `applications`), avoiding heavy game/Steam directories.
- Writes to temporary archive atomically and moves to `~/Desktop/CachyOS-Config-Backup-YYYY-MM-DD_HH-MM-SS.tar.zst`.
- Restricts archive permissions to mode `0600` under `$TARGET_USER:$TARGET_GROUP`.
- Prints the **Disk Reclamation Summary Table** accompanied by the **Session Profile Footer** (`Mode: ...`, `Modules executed: ...`, `Status: ...`) and logs it to `/var/log/cachyos-housekeeping.log`.
- Sends a native desktop alert to the active KDE session via `notify-send`.

---

## Log Files & Telemetry

Full execution logs, journal trends, and shader metrics are appended to:
```bash
/var/log/cachyos-housekeeping.log
```

For long‑term operational longevity, consider adding this log to your system's `logrotate` configuration (e.g. `/etc/logrotate.d/cachyos-housekeeping`).

---

## Aliases & Shortcuts

If using the AUR package, `cachy-clean` is already installed as a system symlink. If running the standalone script, you can add these aliases to your `~/.bashrc` or `~/.zshrc`:

```bash
alias cachy-clean="sudo cachyos-housekeeping"
alias cachy-safe="sudo cachyos-housekeeping --safe-mode"
alias cachy-dry="sudo cachyos-housekeeping --dry-run"
```

---

## Changelog & Documentation

* Complete release history and version notes: [CHANGELOG.md](CHANGELOG.md)
* AUR packaging and maintainer publication guide: [AUR_PUBLISHING.md](AUR_PUBLISHING.md)

---

## AUR Publication & Maintenance

Maintainers can publish or update this package on the Arch User Repository using the instructions in [AUR_PUBLISHING.md](AUR_PUBLISHING.md). The repository includes an audited [PKGBUILD](PKGBUILD), [.SRCINFO](.SRCINFO), and automated GitHub Actions CI & release packaging workflows.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
