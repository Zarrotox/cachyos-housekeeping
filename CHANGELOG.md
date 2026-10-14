# Changelog

All notable changes to the **Universal Linux Housekeeping Framework** (and stable CachyOS Housekeeping Suite) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [Universal-Dev / Phase 2] - 2026-10-14

### Added
- **Concrete Debian / APT Backend (`experimental/backends/debian.sh`)**:
  - Implemented non-interactive metadata refresh (`apt-get update -qq`).
  - Implemented orphan discovery via `apt-get --dry-run autoremove` with candidate reporting, dry-run simulation, and interactive Safe Mode operator confirmation.
  - Implemented package cache usage measurement and cleanup (`apt-get autoclean` & `apt-get clean`).
  - Added Canonical Snap disabled revision detection and garbage collection (`snap list --all` & `snap remove`).
  - Added deep `/etc` scan for `.dpkg-*` and `.ucf-*` merge conflict files.
- **Concrete Fedora / DNF Backend (`experimental/backends/fedora.sh`)**:
  - Added dynamic binary resolution preferring `dnf5` with automatic fallback to `dnf`.
  - Implemented metadata cache refresh via `makecache --refresh`.
  - Implemented orphan discovery via `repoquery --unneeded -q` and safe autoremove (`autoremove -y`).
  - Implemented multi-tier cache directory calculation (`/var/cache/libdnf5` vs `/var/cache/dnf`) and cache clearing (`clean all`).
  - Added `.rpmnew` and `.rpmsave` conflict scanning in `/etc` with `rpmconf -a` integration guidance.
- **Driver Execution Controls (`experimental/universal-housekeeping.sh`)**:
  - Added `--apply` / `--execute` flags to toggle from default Dry-Run to live execution.
  - Added `--yes` / `--no-safe-mode` flags for unattended execution.
  - Added `--help` / `-h` CLI usage documentation.
  - Updated startup banner to `Branch: universal-dev | Phase 2`.

---

## [Universal-Dev / Phase 1] - 2026-10-14

### Added
- **ZARROTOX Project Rebranding**: Rebranded experimental cross-distribution initiative to **Universal Linux Housekeeping Framework** under author **Zarrotox**. Introduced stylized Unicode/ASCII startup banner with subheaders for distribution detection and active backend reporting.
- **Distribution Abstraction Engine (`experimental/distro/detect.sh`)**: Built native `/etc/os-release` parser classifying 10+ distributions across Arch, Fedora, Debian, and openSUSE families. Verified with an 11-test automated suite.
- **Package Manager Detection (`experimental/distro/package_manager.sh`)**: Added dynamic discovery for `pacman`, `dnf`, `apt`, `zypper`, `flatpak`, and `snap`.
- **Modular Backend Dispatcher (`experimental/backends/backend_interface.sh`)**: Standardized contract exposing `package_remove_orphans()`, `package_clean_cache()`, `package_update_metadata()`, and `package_scan_config_diffs()`.
- **Arch Reference Baseline (`experimental/backends/arch.sh`)**: Preserved production-hardened Arch/CachyOS functionality as reference baseline.
- **Cross-Distro Compatibility Matrix & Migration Roadmap (`experimental/compatibility/MATRIX.md`, `experimental/docs/MIGRATION_STRATEGY.md`)**: Comprehensive documentation detailing portable vs. distro-bound maintenance routines.

---

## [2026.10.16] - 2026-10-13

### Added
- **Dual Snapshot Engine (Snapper & Timeshift)**: Implemented native dual snapshot backend support in `cachyos-housekeeping.sh`. Step 0/5 (`run_preflight_checks()`) automatically probes for `snapper` first (standard CachyOS Btrfs setup), then falls back to `timeshift`. Step 1/5 (`run_system_safety()`) creates a `"Pre-Housekeeping"` snapshot via `snapper -c root create` (with fallback to default config `snapper create`) or `timeshift --create`. If neither snapshot tool is available, preflight exits with actionable installation remedies.
- **Packaging Dependencies**: Added `snapper` to `optdepends` in `PKGBUILD` and `.SRCINFO` for native Btrfs snapshot support prior to maintenance operations.

### Fixed
- **Container Runtime & Application Lock Symlink Protection**: Protected container rootfs environments and active application locks from broken symlink scanning in Step 3/5 (`run_kde_cleanup()`):
  - Explicitly prunes runtime, container, and game directories (`~/.local/share/Steam`, `~/.local/share/umu`, `~/.local/share/lutris`, `~/.local/share/Trash`, `~/.local/share/containers`, `~/.local/share/flatpak`, `~/.local/share/docker`), preventing `find` from traversing internal Steam Runtime / `pressure-vessel` container paths (e.g. `umu/steamrt3` and `steamrt4`).
  - Explicitly excludes `! -name "Singleton*"` and `! -name "lock"`, ensuring active Chromium/Electron (Brave, Chrome, Vesktop, Antigravity) and Gecko (Firefox, LibreWolf) profile lock symlinks are never falsely flagged or removed.
- **Mounted Media Path Safeguard (`safe_rm_rf` / `safe_empty_directory`)**: Permitted deletions inside secondary drives mounted under `/run/media/*/*/*` (e.g. multi-drive Steam libraries mounted by KDE/udisks2 at `/run/media/<user>/<drive>/...`), while continuing to strictly protect the `/run/media` root, user directories, drive mount roots, and all system `/run/*` paths.
- **Hardened Configuration Backup (`run_backup_module`)**:
  - Excluded heavy browser profiles and Electron caches from `.config` backups (`BraveSoftware`, `librewolf`, `mozilla`, `google-chrome`, `chromium`, `vivaldi`, `microsoft-edge`, `opera`, `vesktop`, `discord`, `Antigravity`, `Code`, `*/Cache/*`, `*/Code Cache/*`, `*/GPUCache/*`, `*/Singleton*`, `*/lock`), drastically reducing backup archive size for lightweight Proton Drive syncing.
  - Added `--warning=no-file-changed` and `--ignore-failed-read` to `tar`, capturing the exit code (`local tar_rc=0; tar ... || tar_rc=$?`) and accepting `(( tar_rc == 0 || tar_rc == 1 ))` as success to prevent live file modification warnings during browser/app execution from failing the backup step.

---

## [2026.10.15] - 2026-10-13

### Fixed
- **Quoted Wildcard Glob Invalidation**: Fixed critical issue where quoted directory paths (`"${dir}/*"`) were treated by Bash and `realpath -m` as literal asterisk files, preventing coredump, Kdenlive, and thumbnail cleanups from deleting directory contents.
- **Direct `rm` Bypasses**: Replaced raw `rm -f -- "${b_link:?}"` in broken symlink processing and `rm -f -- "$tmp_archive"` in backup error handling with `safe_rm_rf()`.
- **Symlink Deletion Safety**: Hardened `safe_rm_rf()` to invoke `realpath -s -m -- "$target"` when targeting symbolic links (`[[ -L "$target" ]]`), preventing `realpath` from following broken symlinks to nonexistent target paths and leaving the symlink intact.
- **Baloo Corruption False Positives**: Removed `"not running"` from `balooctl6` status check regex. Inactive or stopped Baloo services no longer trigger unwarranted database purges and index rebuilds.
- **Failure Propagation in Telemetry**: Updated `track_directory_cleanup()` to capture callback return codes and propagate non-zero exit statuses instead of swallowing errors with `|| true`. Updated all module callers to inspect return codes and report errors.

### Added
- **`safe_empty_directory()` Helper**: Recursively iterates through directory contents with `nullglob` and `dotglob` (safely ignoring `.` and `..`), routing each child deletion through `safe_rm_rf()` barriers while preserving directory existence.

---

## [2026.10.14] - 2026-10-13

### Fixed
- **Eliminated `eval`**: Replaced all string evaluations with safe, parameterized function callbacks.
- **Numeric Telemetry Output**: Guaranteed that `track_directory_cleanup()` routes all human logging to `stderr` and prints strictly numeric integer bytes on `stdout`, preventing arithmetic string corruption.
- **Variable Initialization Under `nounset`**: Explicitly initialized conditionally declared variables (`baloo_size_bytes`, `frag_count`, `baloo_fragmented`, `baloo_bloated`, `baloo_corrupted`).
- **Steam False-Orphan Prevention**: Added missing library checks and manifest count checks. If zero game manifests are indexed or Steam libraries are inaccessible, destructive sweeping is aborted.

### Security
- **Steam Compatdata Preservation**: Orphaned Proton prefixes (`compatdata/<AppID>`) are **never** automatically deleted, safeguarding game saves, Wine configurations, and DXVK state. Uninstalled prefixes are reported as candidates. Only disposable `shadercache` entries are pruned.
- **Atomic, Hardened Backups**: Configuration backups are staged to temporary files in `/tmp`, moved atomically, tagged with timestamps (`YYYY-MM-DD_HH-MM-SS`), assigned to primary group (`$TARGET_USER:$TARGET_GROUP`), and locked to mode `0600`.

### Added
- **Unattended Execution (`-y` / `--yes`)**: Bypasses interactive confirmation prompts for non-interactive maintenance scripts.
- **Target User Override (`-u` / `--target-user`)**: Explicitly overrides desktop user context for permissions, XDG paths, and DBus notifications.
- **Multi-Context User Discovery**: Robust user detection fallback across `sudo`, `pkexec`, `loginctl` (Wayland/X11), `logname`, and `who`.
- **Command-Line Conflict Checks**: Enforces mutual exclusivity for `--dry-run` + `--safe-mode` and `--all` + `--modules`.

---

## [2026.10.13] - 2026-10-13

### Added
- **Interactive Module Selector**: TUI checklist prompt supporting `gum`, `whiptail`, and terminal numbered selector to toggle:
  - `pacman`: Pacman package cache & orphan removal
  - `aur`: Paru/Yay cache cleanup
  - `flatpak`: Unused Flatpak runtimes
  - `kde`: Baloo indexer, Kdenlive, thumbnails, broken symlinks
  - `steam`: Multi-library shadercache orphan sweeper
  - `btrfs`: Btrfs foreground scrub & SSD TRIM
  - `backup`: Desktop configuration archive (.tar.zst)
- **Safe Mode (`-s` / `--safe-mode`)**: Non-destructive operational mode that executes system maintenance (Timeshift, Btrfs scrub, fstrim, journal vacuum, configuration backup) while prohibiting all `rm -rf` file deletions.
- **Systemd Journal Growth Monitor**: Logs pre-vacuum storage metrics via `journalctl --disk-usage`.
- **Baloo LMDB Split Index Fragmentation Check**: Detects severe database fragmentation when split `index-*` files exceed threshold (`frag_count > 20`).
- **Steam Shadercache Performance Monitor**: Measures and logs multi-drive shader storage consumption.

---

## [2026.10.12] - 2026-10-12

### Added
- **Live Disk Space Tracking Engine**: Calculates storage before and after each cleanup step with a color-coded Grand Total summary table.
- **Native KDE Plasma Notifications**: Pushes desktop notifications via `notify-send` across root/sudo boundaries over user DBus session socket.
- **Defensive Error Handling**: Script runtime secured with `set -euo pipefail` and dual terminal/logfile logging via `tee`.
- **Btrfs Filesystem Scrub**: Automated `btrfs scrub start -Bd /` and SSD `fstrim -av`.
