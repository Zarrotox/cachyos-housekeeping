#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Package Management Backend Interface
# Part of Experimental Phase 1: Distro Abstraction Framework
# ==============================================================================
# Defines the standardized contract for distribution backends and dispatches
# operations dynamically to the active backend implementation.
# Standard Contract Methods:
#   - package_remove_orphans()
#   - package_clean_cache()
#   - package_update_metadata()
#   - package_scan_config_diffs()
# ==============================================================================

CURRENT_BACKEND="none"
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize and load appropriate backend
init_package_backend() {
    local family="${1:-${DETECTED_DISTRO_FAMILY:-unknown}}"

    case "$family" in
        arch)
            # shellcheck source=/dev/null
            source "${BACKEND_DIR}/arch.sh"
            CURRENT_BACKEND="arch"
            ;;
        fedora)
            # shellcheck source=/dev/null
            source "${BACKEND_DIR}/fedora.sh"
            CURRENT_BACKEND="fedora"
            ;;
        debian)
            # shellcheck source=/dev/null
            source "${BACKEND_DIR}/debian.sh"
            CURRENT_BACKEND="debian"
            ;;
        suse)
            # shellcheck source=/dev/null
            source "${BACKEND_DIR}/suse.sh"
            CURRENT_BACKEND="suse"
            ;;
        *)
            echo "[ERROR] Unsupported distribution family: '${family}'. Cannot load backend." >&2
            CURRENT_BACKEND="unsupported"
            return 1
            ;;
    esac

    return 0
}

# Standard Contract Dispatchers

package_remove_orphans() {
    case "$CURRENT_BACKEND" in
        arch)    arch_package_remove_orphans "$@" ;;
        fedora)  fedora_package_remove_orphans "$@" ;;
        debian)  debian_package_remove_orphans "$@" ;;
        suse)    suse_package_remove_orphans "$@" ;;
        *)
            echo "[ERROR] package_remove_orphans: No active backend loaded." >&2
            return 1
            ;;
    esac
}

package_clean_cache() {
    case "$CURRENT_BACKEND" in
        arch)    arch_package_clean_cache "$@" ;;
        fedora)  fedora_package_clean_cache "$@" ;;
        debian)  debian_package_clean_cache "$@" ;;
        suse)    suse_package_clean_cache "$@" ;;
        *)
            echo "[ERROR] package_clean_cache: No active backend loaded." >&2
            return 1
            ;;
    esac
}

package_update_metadata() {
    case "$CURRENT_BACKEND" in
        arch)    arch_package_update_metadata "$@" ;;
        fedora)  fedora_package_update_metadata "$@" ;;
        debian)  debian_package_update_metadata "$@" ;;
        suse)    suse_package_update_metadata "$@" ;;
        *)
            echo "[ERROR] package_update_metadata: No active backend loaded." >&2
            return 1
            ;;
    esac
}

package_scan_config_diffs() {
    case "$CURRENT_BACKEND" in
        arch)    arch_package_scan_config_diffs "$@" ;;
        fedora)  fedora_package_scan_config_diffs "$@" ;;
        debian)  debian_package_scan_config_diffs "$@" ;;
        suse)    suse_package_scan_config_diffs "$@" ;;
        *)
            echo "[WARN] package_scan_config_diffs: Unsupported on backend '${CURRENT_BACKEND}'." >&2
            return 0
            ;;
    esac
}
