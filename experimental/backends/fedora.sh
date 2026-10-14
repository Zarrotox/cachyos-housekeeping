#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Fedora / Nobara Backend Implementation
# Part of Experimental Phase 2: Distro Abstraction Framework
# ==============================================================================
# Concrete implementation for DNF / DNF5 based RPM systems.
# Compatible with: Fedora Workstation, Nobara, RHEL, CentOS Stream, and clones.
# ==============================================================================

_fedora_resolve_dnf() {
    if command -v dnf5 >/dev/null 2>&1; then
        echo "dnf5"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        echo "dnf"
    fi
}

_fedora_run_priv() {
    local dnf_bin
    dnf_bin="$(_fedora_resolve_dnf)"

    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo "$dnf_bin" "$@"
        else
            echo "[FEDORA] [ERROR] Root privileges required to run: ${dnf_bin} $*" >&2
            return 1
        fi
    else
        "$dnf_bin" "$@"
    fi
}

fedora_package_update_metadata() {
    local dry_run="${DRY_RUN:-true}"
    local dnf_bin
    dnf_bin="$(_fedora_resolve_dnf)"

    if [[ "$dry_run" == "true" ]]; then
        echo "[FEDORA] [DRY-RUN] Would execute: ${dnf_bin} makecache --refresh"
        return 0
    fi

    echo "[FEDORA] Refreshing ${dnf_bin} package metadata cache..."
    if _fedora_run_priv makecache --refresh; then
        echo "[FEDORA] Metadata cache refreshed successfully."
        return 0
    else
        local rc=$?
        echo "[FEDORA] [ERROR] Failed to refresh metadata cache (exit code: ${rc})." >&2
        return "$rc"
    fi
}

fedora_package_remove_orphans() {
    local dry_run="${DRY_RUN:-true}"
    local safe_mode="${SAFE_MODE:-true}"
    local dnf_bin
    dnf_bin="$(_fedora_resolve_dnf)"

    echo "[FEDORA] Probing for unneeded/orphaned packages using ${dnf_bin}..."
    local orphans=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && orphans+=("$pkg")
    done < <("$dnf_bin" repoquery --unneeded -q 2>/dev/null || true)

    local count=${#orphans[@]}
    if [[ $count -eq 0 ]]; then
        echo "[FEDORA] No orphaned packages found."
        return 0
    fi

    echo "[FEDORA] Found ${count} unneeded/orphaned package(s):"
    for pkg in "${orphans[@]}"; do
        echo "  - ${pkg}"
    done

    if [[ "$dry_run" == "true" ]]; then
        echo "[FEDORA] [DRY-RUN] Would purge ${count} orphaned packages via: ${dnf_bin} autoremove -y"
        return 0
    fi

    if [[ "$safe_mode" == "true" ]]; then
        if [[ -t 0 ]]; then
            local answer=""
            read -r -p "[FEDORA] Safe Mode enabled. Purge these orphaned packages? [y/N] " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    echo "[FEDORA] Operator approved orphan removal."
                    ;;
                *)
                    echo "[FEDORA] [SAFE-MODE] Orphaned package removal skipped by operator."
                    return 0
                    ;;
            esac
        else
            echo "[FEDORA] [SAFE-MODE] Non-interactive execution in Safe Mode; orphan package removal skipped."
            return 0
        fi
    fi

    echo "[FEDORA] Removing ${count} orphaned package(s)..."
    if _fedora_run_priv autoremove -y; then
        echo "[FEDORA] Successfully purged orphaned packages."
        return 0
    else
        local rc=$?
        echo "[FEDORA] [ERROR] ${dnf_bin} autoremove failed with exit code: ${rc}." >&2
        return "$rc"
    fi
}

fedora_package_clean_cache() {
    local dry_run="${DRY_RUN:-true}"
    local dnf_bin
    dnf_bin="$(_fedora_resolve_dnf)"

    # Identify cache directory based on DNF version
    local cache_dir="/var/cache/dnf"
    [[ "$dnf_bin" == "dnf5" && -d "/var/cache/libdnf5" ]] && cache_dir="/var/cache/libdnf5"

    local cache_size="0B"
    if [[ -d "$cache_dir" ]]; then
        cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1 || echo "0B")
    fi
    echo "[FEDORA] Current ${dnf_bin} package cache usage (${cache_dir}): ${cache_size:-0B}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[FEDORA] [DRY-RUN] Would execute: ${dnf_bin} clean all"
        return 0
    fi

    echo "[FEDORA] Cleaning ${dnf_bin} cache..."
    if _fedora_run_priv clean all; then
        echo "[FEDORA] Cache cleaned successfully."
        return 0
    else
        local rc=$?
        echo "[FEDORA] [ERROR] ${dnf_bin} clean all failed with exit code: ${rc}." >&2
        return "$rc"
    fi
}

fedora_package_scan_config_diffs() {
    local dnf_bin
    dnf_bin="$(_fedora_resolve_dnf)"

    echo "[FEDORA] Scanning /etc for RPM configuration conflict files (.rpmnew / .rpmsave)..."
    local conflict_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && conflict_files+=("$f")
    done < <(find /etc -maxdepth 3 \( -name "*.rpmnew" -o -name "*.rpmsave" \) 2>/dev/null || true)

    if [[ ${#conflict_files[@]} -gt 0 ]]; then
        echo "[FEDORA] [WARN] Found ${#conflict_files[@]} configuration conflict file(s) in /etc:"
        for f in "${conflict_files[@]}"; do
            echo "  - ${f}"
        done
        if command -v rpmconf >/dev/null 2>&1; then
            echo "[FEDORA] [INFO] 'rpmconf' utility detected. You can merge conflict files interactively via: sudo rpmconf -a"
        else
            echo "[FEDORA] [INFO] Recommendation: Inspect changes via 'diff -u' or install rpmconf via: sudo ${dnf_bin} install rpmconf"
        fi
    else
        echo "[FEDORA] Clean: No .rpmnew or .rpmsave config conflict files detected in /etc."
    fi

    return 0
}
