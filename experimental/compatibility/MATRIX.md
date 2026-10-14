# Universal Linux Housekeeping - Compatibility Matrix

This matrix categorizes the portability of housekeeping features across supported distribution families.

## Portability Classification Table

| Feature / Subsystem | Universal | Arch Only | Fedora Only | Unknown / Future | Portability Notes |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **System Rollback Snapshots (Timeshift)** | ✅ | | | | Operates universally on Btrfs subvolumes and ext4 via rsync across any distribution with `timeshift`. |
| **System Rollback Snapshots (Snapper)** | ✅ | | | | Standardized on openSUSE, Fedora (with snapper), Arch, and CachyOS. Requires root layout configuration. |
| **Systemd Journal Vacuuming** | ✅ | | | | Fully universal across all systemd-based Linux distributions (`journalctl --vacuum-size=500M`). |
| **Systemd Core Dumps Purging** | ✅ | | | | Universal on all systems running `systemd-coredump` (`/var/lib/systemd/coredump`). |
| **KDE Baloo File Index Sanitization** | ✅ | | | | Universal on KDE Plasma installations running `balooctl6` or `balooctl`. |
| **Kdenlive Proxy & Cache Wipe** | ✅ | | | | Universal FreeDesktop location (`~/.local/share/kdenlive`, `~/.cache/kdenlive`). |
| **FreeDesktop Thumbnail Cache Trim** | ✅ | | | | Standardized XDG base specification location (`~/.cache/thumbnails`). |
| **Broken Symlink Detection** | ✅ | | | | POSIX/GNU `find -xtype l` works identically across all Linux distributions. Prunes container/flatpak mounts. |
| **Btrfs Scrub** | ✅ | | | | Universal on any Btrfs root filesystem (`btrfs scrub start -B`). |
| **SSD TRIM (`fstrim`)** | ✅ | | | | Universal Linux utility (`fstrim -av`). |
| **Steam Multi-Drive Orphan Sweeper** | ✅ | | | | Valve Steam manifest (`libraryfolders.vdf`) parsing and `/run/media` depth tracking are agnostic of host distro. |
| **Atomic Desktop Profile Backup** | ✅ | | | | GNU `tar --zstd` works universally on any distro with `tar` and `zstd`. |
| **Flatpak Unused Runtime Sweep** | ✅ | | | | Fully universal across any distro with Flatpak runtime installed (`flatpak uninstall --unused -y`). |
| **Pacman Package Cache Trim** | | ✅ | | | Depends on `pacman` and `paccache` (`pacman-contrib`). Arch, CachyOS, EndeavourOS only. |
| **Pacman Orphan Package Purge** | | ✅ | | | Relies on `pacman -Qtdq` and cascade removal `pacman -Rns`. Arch-family only. |
| **AUR Helper Cache Sanitization** | | ✅ | | | Specific to Arch User Repository build helpers (`paru`, `yay`). |
| **Pacnew / Pacsave Conflict Scanner** | | ✅ | | | Arch-specific package merge conflict utility (`pacdiff`). |
| **DNF Package Cache Clean** | | | ✅ | | Planned Phase 2 backend hook (`dnf clean all` / `dnf clean packages`). Fedora, Nobara, RHEL only. |
| **DNF Autoremove (Orphan Purge)** | | | ✅ | | Planned Phase 2 backend hook (`dnf autoremove -y`). Fedora, Nobara only. |
| **RPM Configuration Diff Scanner** | | | ✅ | | Planned Phase 2 tool (`rpmconf -a` scanning `.rpmnew` / `.rpmsave`). Fedora & openSUSE only. |
| **APT Package Cache Clean** | | | | ❓ (Debian) | Planned Phase 2 backend hook (`apt-get clean && apt-get autoclean`). Ubuntu, Mint, Pop, Debian. |
| **APT Autoremove (Orphan Purge)** | | | | ❓ (Debian) | Planned Phase 2 backend hook (`apt-get --purge autoremove -y`). Ubuntu, Mint, Pop, Debian. |
| **DPKG Conflict Scanner** | | | | ❓ (Debian) | Planned Phase 2 scanner for `.dpkg-dist` and `.dpkg-old`. Debian family only. |
| **Zypper Package Cache Clean** | | | | ❓ (SUSE) | Planned Phase 2 backend hook (`zypper clean --all`). openSUSE family only. |
| **Zypper Orphan Package Purge** | | | | ❓ (SUSE) | Planned Phase 2 backend hook (`zypper packages --orphaned`). openSUSE family only. |
| **Snap Package Old Revision Trim** | | | | ❓ (Ubuntu) | Requires custom shell loop to prune superseded Snap revisions on Ubuntu. |
| **Immutable / Atomic Systems (OSTree)** | | | | ❓ (Future) | Fedora Silverblue, Bazzite, SteamOS. Requires read-only root handling (`rpm-ostree cleanup`). |

---

## Architectural Findings
1. **Core Housekeeping is 70%+ Universal:** The majority of storage consumers (systemd logs, core dumps, Steam shadercaches, thumbnail caches, desktop config backups, SSD fstrim, Btrfs scrubs) are completely distribution-agnostic.
2. **Package Management is 100% Distro-Specific:** Package caches, orphan detection, and configuration conflict merges require abstracted backend modules.
3. **Rollback guarantees require dual backend support:** Snapper and Timeshift must remain co-equal first-class citizens.
