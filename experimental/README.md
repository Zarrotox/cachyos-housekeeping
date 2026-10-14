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

**Author**: Zarrotox  
**Target Environment**: Linux (Arch, Fedora, Debian, openSUSE Families)  
**Status**: Experimental Cross-Distribution Framework  

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

The **Universal Linux Housekeeping Framework** is an experimental cross-distribution maintenance framework engineered to decouple platform-independent system maintenance (systemd logs, core dumps, Valve Steam caches, KDE Baloo, SSD fstrim, Btrfs scrubs, and user backups) from distribution-specific package manager operations.

While the `main` branch maintains the hardened, production-proven Arch Linux / CachyOS suite (`cachyos-housekeeping.sh`), the `universal-dev` branch introduces modular backend engines for Fedora/Nobara, Debian/Ubuntu, and openSUSE.

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

## Directory Layout

```text
experimental/
├── UNIVERSAL_ROADMAP.md         # Master roadmap & architecture specification
├── universal-housekeeping.sh    # Modular test harness & driver
├── distro/
│   ├── detect.sh               # detect_distribution() via /etc/os-release
│   └── package_manager.sh      # detect_package_manager()
├── backends/
│   ├── backend_interface.sh    # Contract interface & dynamic loader
│   ├── arch.sh                 # Reference Arch / CachyOS backend
│   ├── fedora.sh               # Concrete Fedora / Nobara backend (dnf/dnf5)
│   ├── debian.sh               # Concrete Debian / Ubuntu backend (apt/dpkg)
│   └── suse.sh                 # openSUSE framework stub (zypper)
├── compatibility/
│   └── MATRIX.md               # Feature matrix across 10+ distros
├── docs/
│   └── MIGRATION_STRATEGY.md   # Portability and migration strategy
└── tests/
    └── test_distro_detect.sh   # Automated detection test suite
```

---

## Quick Start (Testing the Experimental Framework)

Run the experimental driver with your host's `/etc/os-release` or test with CLI execution modes:

```bash
# 1. Standard dry-run audit on current host
bash experimental/universal-housekeeping.sh

# 2. View available CLI options and execution flags
bash experimental/universal-housekeeping.sh --help

# 3. Live run with Safe Mode confirmation prompt
bash experimental/universal-housekeeping.sh --apply

# 4. Fully unattended live execution
bash experimental/universal-housekeeping.sh --apply --yes

# 5. Run the automated distribution detection unit test suite
bash experimental/tests/test_distro_detect.sh
```

---

## Documentation Links

- [Universal Roadmap](UNIVERSAL_ROADMAP.md)
- [Compatibility Matrix](compatibility/MATRIX.md)
- [Migration Strategy](docs/MIGRATION_STRATEGY.md)

---

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
