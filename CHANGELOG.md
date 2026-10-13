# Changelog

All notable changes to the **CachyOS Housekeeping Suite** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
