#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Arch Linux / CachyOS Backend (Reference)
# Part of Experimental Phase 1: Distro Abstraction Framework
# ==============================================================================
# Reference implementation representing verified stable behavior on Arch Linux,
# CachyOS, and EndeavourOS.
# ==============================================================================

arch_package_remove_orphans() {
    local dry_run="${DRY_RUN:-false}"
    local safe_mode="${SAFE_MODE:-false}"

    echo "[ARCH] Probing for unneeded dependencies and orphaned packages (pacman -Qtdq)..."
    local orphans=""
    orphans=$(pacman -Qtdq 2>/dev/null || true)

    if [[ -z "$orphans" ]]; then
        echo "[ARCH] No orphaned packages identified."
        return 0
    fi

    echo "[ARCH] Orphaned packages identified:"
    echo "$orphans" | sed 's/^/  - /'

    if [[ "$dry_run" == "true" ]]; then
        echo "[ARCH] [DRY-RUN] Would remove orphaned packages using 'pacman -Rns --noconfirm'."
        return 0
    elif [[ "$safe_mode" == "true" ]]; then
        echo "[ARCH] [SAFE-MODE] Orphaned package removal skipped in Safe Mode."
        return 0
    fi

    echo "[ARCH] Removing orphaned packages..."
    # shellcheck disable=SC2086
    if pacman -Rns --noconfirm $orphans; then
        echo "[ARCH] Successfully purged orphaned packages."
    else
        echo "[ARCH] [ERROR] Failed to remove some orphaned packages." >&2
        return 1
    fi
}

arch_package_clean_cache() {
    local dry_run="${DRY_RUN:-false}"
    local safe_mode="${SAFE_MODE:-false}"

    echo "[ARCH] Trimming pacman package cache..."
    if command -v paccache >/dev/null 2>&1; then
        if [[ "$dry_run" == "true" ]]; then
            echo "[ARCH] [DRY-RUN] Would trim package cache keeping last 2 versions (paccache -rk2)."
            return 0
        elif [[ "$safe_mode" == "true" ]]; then
            echo "[ARCH] [SAFE-MODE] Package cache trimming skipped in Safe Mode."
            return 0
        fi

        paccache -rk2
    else
        echo "[ARCH] [WARN] 'paccache' not found. Falling back to pacman -Sc." >&2
        if [[ "$dry_run" == "true" ]] || [[ "$safe_mode" == "true" ]]; then
            echo "[ARCH] Skipping live cache wipe."
            return 0
        fi
        pacman -Sc --noconfirm
    fi
}

arch_package_update_metadata() {
    local dry_run="${DRY_RUN:-false}"

    echo "[ARCH] Refreshing pacman repository metadata databases..."
    if [[ "$dry_run" == "true" ]]; then
        echo "[ARCH] [DRY-RUN] Would refresh package databases (pacman -Sy)."
        return 0
    fi

    pacman -Sy
}

arch_package_scan_config_diffs() {
    echo "[ARCH] Scanning for .pacnew and .pacsave configuration diffs..."
    if command -v pacdiff >/dev/null 2>&1; then
        local editor="${SUDO_EDITOR:-${VISUAL:-${EDITOR:-nano}}}"
        DIFFPROG="$editor" pacdiff -s 2>/dev/null || true
    else
        echo "[ARCH] [INFO] 'pacdiff' utility not installed (pacman-contrib)."
    fi
}
