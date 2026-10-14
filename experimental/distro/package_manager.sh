#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Package Manager Detection Engine
# Part of Experimental Phase 1: Distro Abstraction Framework
# ==============================================================================
# Detects primary package managers (pacman, dnf, apt, zypper) and companion
# tooling (AUR helpers, flatpak, snap).
# ==============================================================================

PRIMARY_PKG_MANAGER="unknown"
SUPPORTED_PKG_MANAGERS=("pacman" "dnf" "apt" "zypper")
SECONDARY_PKG_MANAGERS=()
HAS_FLATPAK=false
HAS_SNAP=false

detect_package_manager() {
    local family="${1:-${DETECTED_DISTRO_FAMILY:-unknown}}"
    PRIMARY_PKG_MANAGER="unknown"
    SECONDARY_PKG_MANAGERS=()

    # 1. Primary Package Manager resolution (heuristic based on distro family + PATH)
    case "$family" in
        arch)
            if command -v pacman >/dev/null 2>&1; then
                PRIMARY_PKG_MANAGER="pacman"
            fi
            ;;
        fedora)
            if command -v dnf5 >/dev/null 2>&1; then
                PRIMARY_PKG_MANAGER="dnf5"
            elif command -v dnf >/dev/null 2>&1; then
                PRIMARY_PKG_MANAGER="dnf"
            fi
            ;;
        debian)
            if command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
                PRIMARY_PKG_MANAGER="apt"
            fi
            ;;
        suse)
            if command -v zypper >/dev/null 2>&1; then
                PRIMARY_PKG_MANAGER="zypper"
            fi
            ;;
        *)
            # Probe candidates in order of preference
            for pm in "${SUPPORTED_PKG_MANAGERS[@]}"; do
                if command -v "$pm" >/dev/null 2>&1; then
                    PRIMARY_PKG_MANAGER="$pm"
                    break
                fi
            done
            ;;
    esac

    # 2. Companion and secondary tooling discovery
    if command -v paru >/dev/null 2>&1; then
        SECONDARY_PKG_MANAGERS+=("paru")
    fi
    if command -v yay >/dev/null 2>&1; then
        SECONDARY_PKG_MANAGERS+=("yay")
    fi
    if command -v paccache >/dev/null 2>&1; then
        SECONDARY_PKG_MANAGERS+=("paccache")
    fi
    if command -v flatpak >/dev/null 2>&1; then
        HAS_FLATPAK=true
        SECONDARY_PKG_MANAGERS+=("flatpak")
    fi
    if command -v snap >/dev/null 2>&1; then
        HAS_SNAP=true
        SECONDARY_PKG_MANAGERS+=("snap")
    fi

    if [[ "$PRIMARY_PKG_MANAGER" == "unknown" ]]; then
        echo "[WARN] No supported package manager detected in PATH (tried: ${SUPPORTED_PKG_MANAGERS[*]})." >&2
        return 1
    fi

    return 0
}

has_package_manager() {
    local query_pm="${1:?Package manager query required}"
    [[ "$PRIMARY_PKG_MANAGER" == "$query_pm" ]]
}

print_package_manager_info() {
    echo "Primary Package Manager:   ${PRIMARY_PKG_MANAGER}"
    echo "Secondary Tooling / Wrappers: ${SECONDARY_PKG_MANAGERS[*]:-<none>}"
    echo "Flatpak Support:           ${HAS_FLATPAK}"
    echo "Snap Support:              ${HAS_SNAP}"
}
