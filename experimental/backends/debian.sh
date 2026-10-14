#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Debian / Ubuntu / Mint / Pop Backend Implementation
# Part of Experimental Phase 2: Distro Abstraction Framework
# ==============================================================================
# Concrete implementation for APT / DPKG based distributions.
# Compatible with: Debian, Ubuntu, Linux Mint, Pop!_OS, and derivatives.
# ==============================================================================

_debian_run_priv() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo DEBIAN_FRONTEND=noninteractive "$@"
        else
            echo "[DEBIAN] [ERROR] Root privileges required to run: $*" >&2
            return 1
        fi
    else
        DEBIAN_FRONTEND=noninteractive "$@"
    fi
}

debian_package_update_metadata() {
    local dry_run="${DRY_RUN:-true}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DEBIAN] [DRY-RUN] Would execute: DEBIAN_FRONTEND=noninteractive apt-get update -qq"
        return 0
    fi

    echo "[DEBIAN] Refreshing APT package index..."
    if _debian_run_priv apt-get update -qq; then
        echo "[DEBIAN] Package metadata updated successfully."
        return 0
    else
        local rc=$?
        echo "[DEBIAN] [ERROR] Failed to update package metadata (exit code: ${rc})." >&2
        return "$rc"
    fi
}

debian_package_remove_orphans() {
    local dry_run="${DRY_RUN:-true}"
    local safe_mode="${SAFE_MODE:-true}"

    echo "[DEBIAN] Probing for candidate orphan packages..."
    local orphans=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && orphans+=("$pkg")
    done < <(apt-get --dry-run autoremove 2>/dev/null | awk '/^Remv / {print $2}' || true)

    local count=${#orphans[@]}
    if [[ $count -eq 0 ]]; then
        echo "[DEBIAN] No orphaned packages found."
        return 0
    fi

    echo "[DEBIAN] Found ${count} orphaned package(s):"
    for pkg in "${orphans[@]}"; do
        echo "  - ${pkg}"
    done

    if [[ "$dry_run" == "true" ]]; then
        echo "[DEBIAN] [DRY-RUN] Would purge ${count} orphaned packages via: apt-get --purge autoremove -y"
        return 0
    fi

    if [[ "$safe_mode" == "true" ]]; then
        if [[ -t 0 ]]; then
            local answer=""
            read -r -p "[DEBIAN] Safe Mode enabled. Purge these orphaned packages? [y/N] " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    echo "[DEBIAN] Operator approved orphan removal."
                    ;;
                *)
                    echo "[DEBIAN] [SAFE-MODE] Orphaned package removal skipped by operator."
                    return 0
                    ;;
            esac
        else
            echo "[DEBIAN] [SAFE-MODE] Non-interactive execution in Safe Mode; orphan package removal skipped."
            return 0
        fi
    fi

    echo "[DEBIAN] Purging ${count} orphaned package(s)..."
    if _debian_run_priv apt-get --purge autoremove -y; then
        echo "[DEBIAN] Successfully purged ${count} orphaned package(s)."
        return 0
    else
        local rc=$?
        echo "[DEBIAN] [ERROR] apt-get autoremove failed with exit code: ${rc}." >&2
        return "$rc"
    fi
}

debian_package_clean_cache() {
    local dry_run="${DRY_RUN:-true}"
    local snap_support="${SNAP_SUPPORT:-false}"

    local cache_dir="/var/cache/apt/archives"
    local cache_size="0B"
    if [[ -d "$cache_dir" ]]; then
        cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1 || echo "0B")
    fi
    echo "[DEBIAN] Current APT package cache usage (${cache_dir}): ${cache_size:-0B}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DEBIAN] [DRY-RUN] Would run: apt-get autoclean -y && apt-get clean"
        if [[ "$snap_support" == "true" ]]; then
            echo "[DEBIAN] [DRY-RUN] Would prune disabled Snap revisions."
            if command -v snap >/dev/null 2>&1; then
                local disabled_snaps=()
                while IFS=' ' read -r sname srev; do
                    [[ -n "$sname" && -n "$srev" ]] && disabled_snaps+=("${sname} (rev: ${srev})")
                done < <(LANG=C snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' || true)

                if [[ ${#disabled_snaps[@]} -gt 0 ]]; then
                    echo "[DEBIAN] [DRY-RUN] Candidate disabled Snap revisions identified:"
                    for s in "${disabled_snaps[@]}"; do
                        echo "  - ${s}"
                    done
                else
                    echo "[DEBIAN] [DRY-RUN] No disabled Snap revisions found."
                fi
            fi
        fi
        return 0
    fi

    echo "[DEBIAN] Cleaning APT cache..."
    _debian_run_priv apt-get autoclean -y
    _debian_run_priv apt-get clean
    echo "[DEBIAN] APT cache cleaned successfully."

    # Snap revision garbage collection
    if [[ "$snap_support" == "true" ]] && command -v snap >/dev/null 2>&1; then
        echo "[DEBIAN] Inspecting disabled Snap revisions..."
        local disabled_found=false
        while IFS=' ' read -r snapname revision; do
            [[ -z "$snapname" || -z "$revision" ]] && continue
            disabled_found=true
            echo "[DEBIAN] Removing disabled Snap revision: ${snapname} (rev ${revision})..."
            if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
                sudo snap remove "$snapname" --revision="$revision" || true
            else
                snap remove "$snapname" --revision="$revision" || true
            fi
        done < <(LANG=C snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' || true)

        if [[ "$disabled_found" == "false" ]]; then
            echo "[DEBIAN] No disabled Snap revisions detected."
        fi
    fi

    return 0
}

debian_package_scan_config_diffs() {
    echo "[DEBIAN] Scanning /etc for package configuration conflict files (.dpkg-* / .ucf-*)..."
    local conflict_files=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && conflict_files+=("$f")
    done < <(find /etc -maxdepth 3 \( -name "*.dpkg-dist" -o -name "*.dpkg-old" -o -name "*.dpkg-new" -o -name "*.ucf-dist" -o -name "*.ucf-old" -o -name "*.ucf-new" \) 2>/dev/null || true)

    if [[ ${#conflict_files[@]} -gt 0 ]]; then
        echo "[DEBIAN] [WARN] Found ${#conflict_files[@]} configuration conflict file(s) in /etc:"
        for f in "${conflict_files[@]}"; do
            echo "  - ${f}"
        done
        echo "[DEBIAN] [INFO] Recommendation: Inspect changes using 'diff -u' or 'meld', or resolve using 'sudo dpkg-reconfigure <package>'."
    else
        echo "[DEBIAN] Clean: No .dpkg-* or .ucf-* config conflict files detected in /etc."
    fi

    return 0
}
