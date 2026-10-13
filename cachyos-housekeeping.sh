#!/usr/bin/env bash
# ==============================================================================
# CachyOS & KDE Plasma Comprehensive Housekeeping Suite
# ==============================================================================
# SCRIPT_VERSION="2026.10.13"
# AUTHOR="Zarrotox"
#
# CHANGELOG:
#   v2026.10.13:
#     - Added interactive module selector (gum / whiptail / CLI menu fallback)
#     - Added Safe Mode (-s / --safe-mode) prohibiting all rm -rf operations
#     - Added systemd journal growth monitor (journalctl --disk-usage)
#     - Added KDE Baloo index fragmentation detector
#     - Added Steam shadercache performance tuning size monitor
#     - Added CLI module selection flags (--all, --modules, --version)
#   v2026.10.12:
#     - Added real-time disk space tracking engine and Grand Total summary table
#     - Added KDE Plasma DBus graphical desktop notification via notify-send
#     - Enforced set -euo pipefail, ${var:?} protection, and dual logging tee
#   v2026.10.11:
#     - Initial release with 5-step maintenance pipeline & Timeshift failsafe
# ==============================================================================

# Strict Bash Mode
set -euo pipefail

# Version Definition
SCRIPT_VERSION="2026.10.13"

# ------------------------------------------------------------------------------
# Signal Trapping & Interruption Handling
# ------------------------------------------------------------------------------
trap 'echo -e "\n\033[0;31m[✗] ERROR: Script interrupted by user or system signal. Halting immediately.\033[0m\n" >&2; exit 1' INT TERM

# ------------------------------------------------------------------------------
# CLI Flag & Parameter Parsing
# ------------------------------------------------------------------------------
DRY_RUN=false
SAFE_MODE=false
SELECT_ALL_MODULES=false
USER_MODULES=""

show_version() {
    echo "CachyOS Housekeeping Suite v${SCRIPT_VERSION}"
}

show_help() {
    cat << EOF
Usage: sudo ./cachyos-housekeeping.sh [OPTIONS]

Comprehensive maintenance, sanitization, and backup suite for CachyOS / KDE Plasma 6.

Options:
  -d, --dry-run          Simulate all actions without modifying or deleting any files.
  -s, --safe-mode        Prevent any 'rm -rf' or destructive deletions while executing
                         safe operations (Timeshift, btrfs scrub, fstrim, journal vacuum, backup).
  -a, --all              Execute all modules without prompting the module selector.
  -m, --modules <LIST>   Comma-separated list of modules to run.
                         Available: pacman, aur, flatpak, kde, steam, btrfs, backup
  -v, --version          Print script version and exit.
  -h, --help             Display this help message and exit.

Examples:
  sudo ./cachyos-housekeeping.sh                  # Interactive mode with module selector
  sudo ./cachyos-housekeeping.sh --dry-run        # Complete dry-run simulation
  sudo ./cachyos-housekeeping.sh --safe-mode       # Safe mode (no rm -rf deletions)
  sudo ./cachyos-housekeeping.sh -a               # Run all modules unattended
  sudo ./cachyos-housekeeping.sh -m pacman,steam  # Run only Pacman and Steam modules

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--safe-mode)
            SAFE_MODE=true
            shift
            ;;
        -a|--all)
            SELECT_ALL_MODULES=true
            shift
            ;;
        -m|--modules)
            USER_MODULES="${2:-}"
            shift 2
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Terminal Color & Styling Definitions
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''
    BOLD=''
    RESET=''
fi

# ------------------------------------------------------------------------------
# Output Logging Functions
# ------------------------------------------------------------------------------
print_banner() {
    # Print the ASCII logo in Cyan
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
 ______                     _             
|___  /                    | |            
   / / __ _ _ __ _ __ ___  | |_ _____  __ 
  / / / _` | '__| '__/ _ \ | __/ _ \ \/ / 
 / /_| (_| | |  | | | (_) || || (_) >  <  
/_____\__,_|_|  |_|  \___/  \__\___/_/\_\ 
                                          
==============================================================================
EOF
    # Print the script title and dynamic version variable in White
    echo -e "${WHITE}${BOLD}       CACHYOS / KDE PLASMA SYSTEM HOUSEKEEPING SUITE (v${SCRIPT_VERSION})       ${RESET}"
    echo -e "${CYAN}${BOLD}==============================================================================${RESET}"
}

print_step() {
    local step_num="$1"
    local title="$2"
    echo ""
    echo -e "${MAGENTA}${BOLD}------------------------------------------------------------------------------${RESET}"
    echo -e "${MAGENTA}${BOLD}[STEP ${step_num}] ${WHITE}${title}${RESET}"
    echo -e "${MAGENTA}${BOLD}------------------------------------------------------------------------------${RESET}"
}

print_progress() {
    echo -e "${BLUE}${BOLD}[*]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}${BOLD}[✓]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}${BOLD}[!] WARNING:${RESET} $1"
}

print_error() {
    echo -e "${RED}${BOLD}[✗] ERROR:${RESET} $1" >&2
}

print_info() {
    echo -e "${CYAN}[i]${RESET} $1"
}

# ------------------------------------------------------------------------------
# Privilege & Environment Verification
# ------------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    print_error "This script must be executed with root privileges via sudo:"
    echo "  sudo $0 $*" >&2
    exit 1
fi

# Identify the underlying desktop user
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
    TARGET_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    TARGET_UID=$(id -u "$SUDO_USER")
else
    DETECTED_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n1 || echo "root")
    TARGET_USER="$DETECTED_USER"
    TARGET_HOME=$(getent passwd "$DETECTED_USER" | cut -d: -f6)
    TARGET_UID=$(id -u "$DETECTED_USER")
fi

run_as_target_user() {
    if [[ "$TARGET_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------------
# Safe Removal Wrapper Function
# ------------------------------------------------------------------------------
# Enforces ${target:?} expansion and handles Safe Mode / Dry Run logic
safe_rm_rf() {
    local target="${1:?Target path missing}"
    if [[ "$DRY_RUN" = true ]]; then
        echo -e "    ${CYAN}[DRY-RUN]${RESET} Would delete: ${target}"
        return 0
    elif [[ "$SAFE_MODE" = true ]]; then
        echo -e "    ${YELLOW}[SAFE-MODE]${RESET} Deletion prevented: ${target}"
        return 0
    else
        rm -rf "${target:?}"
    fi
}

# ------------------------------------------------------------------------------
# Module Selection Engine
# ------------------------------------------------------------------------------
declare -A MODULES=(
    [pacman]=false
    [aur]=false
    [flatpak]=false
    [kde]=false
    [steam]=false
    [btrfs]=false
    [backup]=false
)

parse_module_list() {
    local raw_list="$1"
    IFS=',' read -ra mods <<< "$raw_list"
    for m in "${mods[@]}"; do
        clean_m=$(echo "$m" | tr '[:upper:]' '[:lower:]' | xargs)
        if [[ "$clean_m" == "all" ]]; then
            for key in "${!MODULES[@]}"; do MODULES[$key]=true; done
        elif [[ -v MODULES[$clean_m] ]]; then
            MODULES[$clean_m]=true
        else
            print_warning "Unknown module name in selection: '$clean_m'"
        fi
    done
}

configure_active_modules() {
    if [[ -n "$USER_MODULES" ]]; then
        parse_module_list "$USER_MODULES"
        return 0
    fi

    if [[ "$SELECT_ALL_MODULES" = true ]]; then
        for key in "${!MODULES[@]}"; do MODULES[$key]=true; done
        return 0
    fi

    echo ""
    echo -e "${CYAN}${BOLD}>>> CONFIGURE HOUSEKEEPING MODULES <<<${RESET}"

    if command -v gum >/dev/null 2>&1; then
        local choices
        choices=$(gum choose --no-limit \
            --selected="Pacman cleanup,AUR cleanup,Flatpak cleanup,KDE cleanup,Steam cleanup,Btrfs scrub,Backup" \
            "Pacman cleanup" "AUR cleanup" "Flatpak cleanup" "KDE cleanup" "Steam cleanup" "Btrfs scrub" "Backup" < /dev/tty || true)
        if [[ -z "$choices" ]]; then
            print_warning "No modules selected. Exiting."
            exit 0
        fi
        echo "$choices" | grep -q "Pacman cleanup" && MODULES[pacman]=true || true
        echo "$choices" | grep -q "AUR cleanup" && MODULES[aur]=true || true
        echo "$choices" | grep -q "Flatpak cleanup" && MODULES[flatpak]=true || true
        echo "$choices" | grep -q "KDE cleanup" && MODULES[kde]=true || true
        echo "$choices" | grep -q "Steam cleanup" && MODULES[steam]=true || true
        echo "$choices" | grep -q "Btrfs scrub" && MODULES[btrfs]=true || true
        echo "$choices" | grep -q "Backup" && MODULES[backup]=true || true

    elif command -v whiptail >/dev/null 2>&1; then
        local choices
        choices=$(whiptail --title "CachyOS Housekeeping - Module Selector" \
            --checklist "Use [Space] to toggle modules and [Enter] to confirm:" 18 68 7 \
            "pacman" "Pacman cleanup (orphans, cache)" ON \
            "aur" "AUR helper build cache cleanup" ON \
            "flatpak" "Flatpak unused runtimes removal" ON \
            "kde" "KDE Plasma (Baloo, Kdenlive, thumbnails)" ON \
            "steam" "Steam multi-drive orphan sweeper" ON \
            "btrfs" "Btrfs scrub on / & fstrim across SSDs" ON \
            "backup" "Selective KDE configuration backup" ON \
            3>&1 1>&2 2>&3 || true)
        if [[ -z "$choices" ]]; then
            print_warning "No modules selected. Exiting."
            exit 0
        fi
        echo "$choices" | grep -q "pacman" && MODULES[pacman]=true || true
        echo "$choices" | grep -q "aur" && MODULES[aur]=true || true
        echo "$choices" | grep -q "flatpak" && MODULES[flatpak]=true || true
        echo "$choices" | grep -q "kde" && MODULES[kde]=true || true
        echo "$choices" | grep -q "steam" && MODULES[steam]=true || true
        echo "$choices" | grep -q "btrfs" && MODULES[btrfs]=true || true
        echo "$choices" | grep -q "backup" && MODULES[backup]=true || true

    else
        # Standard interactive CLI fallback
        echo -e "${YELLOW}Available Modules:${RESET}"
        echo "  [1] Pacman cleanup (orphans & cache)"
        echo "  [2] AUR helper cleanup (paru / yay)"
        echo "  [3] Flatpak unused runtimes"
        echo "  [4] KDE cleanup (Baloo, Kdenlive, thumbnails)"
        echo "  [5] Steam multi-drive orphan sweeper"
        echo "  [6] Btrfs scrub & SSD TRIM"
        echo "  [7] Configuration backup archive"
        echo ""
        read -r -p "$(echo -e "${CYAN}Enter module numbers to run (e.g. '1 2 4 5') or press Enter for ALL [ALL]: ${RESET}")" num_sel < /dev/tty || true
        if [[ -z "${num_sel// /}" ]]; then
            for key in "${!MODULES[@]}"; do MODULES[$key]=true; done
        else
            for n in $num_sel; do
                case "$n" in
                    1) MODULES[pacman]=true ;;
                    2) MODULES[aur]=true ;;
                    3) MODULES[flatpak]=true ;;
                    4) MODULES[kde]=true ;;
                    5) MODULES[steam]=true ;;
                    6) MODULES[btrfs]=true ;;
                    7) MODULES[backup]=true ;;
                esac
            done
        fi
    fi
}

configure_active_modules

# Verify that at least one module was activated
any_active_module=false
for m_key in "${!MODULES[@]}"; do
    if [[ "${MODULES[$m_key]}" = true ]]; then
        any_active_module=true
        break
    fi
done

if [[ "$any_active_module" = false ]]; then
    print_warning "No modules active. Exiting without changes."
    exit 0
fi

# ------------------------------------------------------------------------------
# Interactive Execution Confirmation
# ------------------------------------------------------------------------------
confirm_execution() {
    if [[ "$DRY_RUN" = true ]]; then
        print_info "Dry-Run mode active. No files will be modified."
        return 0
    fi

    echo ""
    local confirm_msg="Proceed with execution of selected housekeeping modules?"
    [[ "$SAFE_MODE" = true ]] && confirm_msg="Proceed in SAFE MODE (all deletions disabled)?"

    if command -v gum >/dev/null 2>&1; then
        if ! gum confirm "$confirm_msg"; then
            print_warning "Maintenance cancelled by user."
            exit 0
        fi
    elif command -v whiptail >/dev/null 2>&1; then
        if ! whiptail --title "Execution Confirmation" --yesno "$confirm_msg" 10 65; then
            print_warning "Maintenance cancelled by user."
            exit 0
        fi
    else
        read -r -p "$(echo -e "${YELLOW}${BOLD}${confirm_msg} [y/N]: ${RESET}")" response < /dev/tty || true
        case "${response:-n}" in
            [yY][eE][sS]|[yY]) ;;
            *)
                print_warning "Maintenance cancelled by user."
                exit 0
                ;;
        esac
    fi
}

confirm_execution

# ------------------------------------------------------------------------------
# Logging Tee Initialization
# ------------------------------------------------------------------------------
LOG_FILE="/var/log/cachyos-housekeeping.log"
touch "$LOG_FILE" 2>/dev/null || true
exec > >(tee -a "$LOG_FILE") 2>&1

print_banner
if [[ "$DRY_RUN" = true ]]; then
    echo -e "${YELLOW}${BOLD}>>> MODE: DRY-RUN (SIMULATION ONLY) <<<${RESET}\n"
elif [[ "$SAFE_MODE" = true ]]; then
    echo -e "${GREEN}${BOLD}>>> MODE: SAFE-MODE (ALL RM-RF DELETIONS DISABLED) <<<${RESET}\n"
else
    echo -e "${CYAN}${BOLD}>>> MODE: STANDARD EXECUTION <<<${RESET}\n"
fi

print_info "Desktop User: ${BOLD}${TARGET_USER}${RESET} (UID: ${TARGET_UID}, Home: ${TARGET_HOME})"
print_info "Log Session: $(date) -> ${LOG_FILE}"

echo -e "\n${CYAN}Active Modules:${RESET}"
[[ "${MODULES[pacman]}" = true ]]  && echo "  • Pacman cleanup"
[[ "${MODULES[aur]}" = true ]]     && echo "  • AUR helper cleanup"
[[ "${MODULES[flatpak]}" = true ]] && echo "  • Flatpak cleanup"
[[ "${MODULES[kde]}" = true ]]     && echo "  • KDE Plasma & caches"
[[ "${MODULES[steam]}" = true ]]   && echo "  • Steam orphan sweeper"
[[ "${MODULES[btrfs]}" = true ]]   && echo "  • Btrfs scrub & SSD TRIM"
[[ "${MODULES[backup]}" = true ]]  && echo "  • Configuration backup"

# ------------------------------------------------------------------------------
# Disk Space Tracking Engine
# ------------------------------------------------------------------------------
PACMAN_CACHE_FREED=0
AUR_CACHES_FREED=0
FLATPAK_FREED=0
JOURNAL_FREED=0
COREDUMPS_FREED=0
KDE_CACHES_FREED=0
STEAM_ORPHANS_FREED=0

format_bytes() {
    local bytes="${1:-0}"
    if [[ -z "$bytes" || "$bytes" -le 0 ]]; then
        echo "0.00 MB"
        return
    fi

    if (( bytes >= 1073741824 )); then
        awk -v b="$bytes" 'BEGIN { printf "%.2f GB", b / 1073741824 }'
    elif (( bytes >= 1048576 )); then
        awk -v b="$bytes" 'BEGIN { printf "%.2f MB", b / 1048576 }'
    elif (( bytes >= 1024 )); then
        awk -v b="$bytes" 'BEGIN { printf "%.2f KB", b / 1024 }'
    else
        echo "${bytes} B"
    fi
}

get_dir_size_bytes() {
    local target_path="${1:?Target path missing}"
    if [[ -e "$target_path" ]]; then
        local size_bytes
        size_bytes=$(du -s -B1 "$target_path" 2>/dev/null | awk '{print $1}' || echo "0")
        if [[ -n "$size_bytes" && "$size_bytes" =~ ^[0-9]+$ ]]; then
            echo "$size_bytes"
            return
        fi
    fi
    echo "0"
}

track_directory_cleanup() {
    local dir_path="${1:?Directory path missing}"
    shift
    local cleanup_cmd=("$@")

    local size_before
    size_before=$(get_dir_size_bytes "$dir_path")

    if [[ "$DRY_RUN" = true ]]; then
        echo -e "    ${CYAN}[DRY-RUN]${RESET} Would execute cleanup on: ${dir_path}"
        echo "$size_before"
        return
    elif [[ "$SAFE_MODE" = true ]]; then
        echo -e "    ${YELLOW}[SAFE-MODE]${RESET} Destructive cleanup skipped for: ${dir_path}"
        echo "0"
        return
    fi

    if [[ ${#cleanup_cmd[@]} -eq 1 ]]; then
        eval "${cleanup_cmd[0]}" || true
    else
        "${cleanup_cmd[@]}" || true
    fi

    local size_after
    size_after=$(get_dir_size_bytes "$dir_path")

    local freed_bytes=0
    if (( size_before > size_after )); then
        freed_bytes=$(( size_before - size_after ))
    fi

    echo "$freed_bytes"
}

# ------------------------------------------------------------------------------
# DBus Desktop Notification
# ------------------------------------------------------------------------------
send_kde_notification() {
    local total_space="$1"
    local dbus_socket="/run/user/${TARGET_UID}/bus"

    if [[ -S "$dbus_socket" ]] && command -v notify-send >/dev/null 2>&1; then
        local notif_title="CachyOS Housekeeping Completed"
        local notif_body="System maintenance complete! Total space reclaimed: ${total_space}."

        if [[ "$DRY_RUN" = true ]]; then
            notif_title="CachyOS Housekeeping (Dry-Run)"
            notif_body="Dry run finished. Estimated reclaimable space: ${total_space}."
        elif [[ "$SAFE_MODE" = true ]]; then
            notif_title="CachyOS Housekeeping (Safe-Mode)"
            notif_body="Safe mode completed. Non-destructive operations finished successfully."
        fi

        sudo -u "$TARGET_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=${dbus_socket}" notify-send \
            -a "CachyOS Housekeeper" \
            -i "system-software-update" \
            "$notif_title" \
            "$notif_body" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# Telemetry Summary Table
# ------------------------------------------------------------------------------
print_summary_table() {
    local grand_total=$(( PACMAN_CACHE_FREED + AUR_CACHES_FREED + FLATPAK_FREED + JOURNAL_FREED + COREDUMPS_FREED + KDE_CACHES_FREED + STEAM_ORPHANS_FREED ))
    local grand_total_fmt

    if (( grand_total >= 1073741824 )); then
        grand_total_fmt=$(awk -v b="$grand_total" 'BEGIN { printf "%.2f GB", b / 1073741824 }')
    else
        grand_total_fmt=$(awk -v b="$grand_total" 'BEGIN { printf "%.2f MB", b / 1048576 }')
    fi

    echo ""
    echo -e "${CYAN}${BOLD}==============================================================================${RESET}"
    echo -e "${WHITE}${BOLD}                     HOUSEKEEPING DISK RECLAMATION SUMMARY                    ${RESET}"
    echo -e "${CYAN}${BOLD}==============================================================================${RESET}"
    printf "  ${BOLD}%-42s %24s${RESET}\n" "Cleanup Category" "Space Reclaimed"
    echo -e "${CYAN}------------------------------------------------------------------------------${RESET}"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "Pacman Package Cache" "$(format_bytes "$PACMAN_CACHE_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "AUR Helper Build Caches" "$(format_bytes "$AUR_CACHES_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "Unused Flatpak Runtimes" "$(format_bytes "$FLATPAK_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "Systemd Journal Logs" "$(format_bytes "$JOURNAL_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "Systemd Crash Dumps (Coredumps)" "$(format_bytes "$COREDUMPS_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "KDE / Kdenlive / Thumbnail Caches" "$(format_bytes "$KDE_CACHES_FREED")"
    printf "  %-42s ${GREEN}%24s${RESET}\n" "Steam Orphan Prefixes & Shaders" "$(format_bytes "$STEAM_ORPHANS_FREED")"
    echo -e "${CYAN}------------------------------------------------------------------------------${RESET}"
    printf "  ${BOLD}%-42s ${YELLOW}${BOLD}%24s${RESET}\n" "GRAND TOTAL RECLAIMED" "$grand_total_fmt"
    echo -e "${CYAN}------------------------------------------------------------------------------${RESET}"

    # Execution Mode & Active Modules Summary
    local exec_mode="STANDARD"
    if [[ "$DRY_RUN" = true ]]; then
        exec_mode="DRY-RUN"
    elif [[ "$SAFE_MODE" = true ]]; then
        exec_mode="SAFE-MODE"
    fi

    local active_mods=()
    for m in pacman aur flatpak kde steam btrfs backup; do
        if [[ "${MODULES[$m]}" = true ]]; then
            active_mods+=("$m")
        fi
    done
    local modules_str
    modules_str=$(IFS=', '; echo "${active_mods[*]}")

    printf "  ${BOLD}%-22s${RESET} ${CYAN}%-50s${RESET}\n" "Mode:" "${exec_mode}"
    printf "  ${BOLD}%-22s${RESET} ${WHITE}%-50s${RESET}\n" "Modules executed:" "${modules_str}"
    echo -e "${CYAN}${BOLD}==============================================================================${RESET}"
    echo ""

    # Log summary entry for audit and trend analysis
    echo "[$(date -Iseconds)] [SESSION-SUMMARY] Mode: ${exec_mode} | Modules executed: ${modules_str} | Total reclaimed: ${grand_total_fmt}" >> "$LOG_FILE"

    send_kde_notification "$grand_total_fmt"
}

# ==============================================================================
# PREFLIGHT CHECKS & DEPENDENCY VERIFICATION
# ==============================================================================
run_preflight_checks() {
    print_step "0/5" "Preflight Dependency & System Verification"
    local preflight_failed=false

    # 1. Timeshift check (Critical for system safety & rollback)
    if ! command -v timeshift >/dev/null 2>&1; then
        print_error "Preflight Failure: 'timeshift' is not installed or not in PATH."
        echo "    Remedy: Install with 'sudo pacman -S timeshift' and initialize via Timeshift GUI." >&2
        preflight_failed=true
    else
        print_success "Preflight: Timeshift is installed."
    fi

    # 2. pacman-contrib check (paccache)
    if [[ "${MODULES[pacman]}" = true ]]; then
        if ! command -v paccache >/dev/null 2>&1; then
            print_error "Preflight Failure: 'paccache' is not installed (pacman module selected)."
            echo "    Remedy: Install with 'sudo pacman -S pacman-contrib'." >&2
            preflight_failed=true
        else
            print_success "Preflight: pacman-contrib (paccache) is installed."
        fi
    fi

    # 3. balooctl6 or balooctl check
    if [[ "${MODULES[kde]}" = true ]]; then
        if ! command -v balooctl6 >/dev/null 2>&1 && ! command -v balooctl >/dev/null 2>&1; then
            print_error "Preflight Failure: neither 'balooctl6' nor 'balooctl' was found (kde module selected)."
            echo "    Remedy: Install with 'sudo pacman -S baloo'." >&2
            preflight_failed=true
        else
            local baloo_bin="balooctl6"
            command -v balooctl6 >/dev/null 2>&1 || baloo_bin="balooctl"
            print_success "Preflight: KDE Baloo utility (${baloo_bin}) is installed."
        fi
    fi

    # 4. flatpak check (if flatpak module selected)
    if [[ "${MODULES[flatpak]}" = true ]]; then
        if ! command -v flatpak >/dev/null 2>&1; then
            print_error "Preflight Failure: 'flatpak' is not installed (flatpak module selected)."
            echo "    Remedy: Install with 'sudo pacman -S flatpak' or deselect flatpak module." >&2
            preflight_failed=true
        else
            print_success "Preflight: Flatpak is installed."
        fi
    fi

    # 5. Steam manifest check (if steam module selected)
    if [[ "${MODULES[steam]}" = true ]]; then
        local steam_vdf="$TARGET_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
        [[ ! -f "$steam_vdf" && -f "$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf" ]] && steam_vdf="$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf"
        if [[ ! -f "$steam_vdf" ]]; then
            print_error "Preflight Failure: Steam library manifest not found at: ${steam_vdf} (steam module selected)."
            echo "    Remedy: Launch Steam at least once to create libraries or deselect steam module." >&2
            preflight_failed=true
        else
            print_success "Preflight: Steam library manifest verified."
        fi
    fi

    if [[ "$preflight_failed" = true ]]; then
        echo ""
        print_error "Preflight checks encountered fatal errors. Aborting housekeeping."
        exit 1
    fi
}

run_preflight_checks

# ==============================================================================
# STEP 1: SYSTEM SAFETY (TIMESHIFT SNAPSHOT)
# ==============================================================================
# Always executes prior to any cleanup actions to guarantee rollback capability
print_step "1/5" "System Safety (Timeshift Snapshot)"

if [[ "$DRY_RUN" = true ]]; then
    print_info "[DRY-RUN] Would create Timeshift snapshot labeled 'Pre-Housekeeping'."
else
    print_progress "Triggering Timeshift snapshot labeled 'Pre-Housekeeping'..."
    if ! command -v timeshift >/dev/null 2>&1; then
        print_error "Timeshift executable not found! Cannot guarantee system safety."
        print_error "Aborting all housekeeping tasks immediately."
        exit 1
    fi

    if timeshift --create --comments 'Pre-Housekeeping'; then
        print_success "Timeshift snapshot 'Pre-Housekeeping' created successfully."
    else
        print_error "Timeshift snapshot creation FAILED!"
        print_error "CRITICAL: Halting execution immediately to protect system integrity."
        print_error "No cleanup or modification tasks have been performed."
        exit 1
    fi
fi

# ==============================================================================
# STEP 2: ARCH PACKAGE CLEANUP
# ==============================================================================
print_step "2/5" "Arch Package Cleanup"

# 1. Pacman Orphans & Cache
if [[ "${MODULES[pacman]}" = true ]]; then
    print_progress "Probing for orphaned packages (pacman -Qtdq)..."
    orphans=$(pacman -Qtdq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        echo -e "${YELLOW}Orphaned packages identified:${RESET}"
        echo "$orphans" | sed 's/^/  - /'
        if [[ "$DRY_RUN" = true ]]; then
            print_info "[DRY-RUN] Would remove orphaned packages with 'pacman -Rns --noconfirm'."
        elif [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Orphaned package removal skipped in Safe Mode."
        else
            print_progress "Removing orphaned packages..."
            # shellcheck disable=SC2086
            pacman -Rns --noconfirm $orphans || true
            print_success "Orphaned packages removed."
        fi
    else
        print_info "No orphaned dependencies found."
    fi

    print_progress "Trimming pacman package cache (paccache -rk2)..."
    pacman_cache_dir="/var/cache/pacman/pkg"
    if command -v paccache >/dev/null 2>&1; then
        if [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Package cache deletion skipped in Safe Mode."
        else
            freed_pac=$(track_directory_cleanup "$pacman_cache_dir" "paccache -rk2")
            PACMAN_CACHE_FREED=$(( PACMAN_CACHE_FREED + freed_pac ))
            print_success "Pacman cache trimmed (Freed: $(format_bytes "$freed_pac"))."
        fi
    else
        print_warning "paccache not found (pacman-contrib may not be installed)."
    fi
else
    print_info "Module 'Pacman cleanup' skipped."
fi

# 2. AUR Helper Cache
if [[ "${MODULES[aur]}" = true ]]; then
    print_progress "Checking for AUR helper build caches..."
    aur_step_freed=0

    if command -v paru >/dev/null 2>&1; then
        paru_cache_dir="$TARGET_HOME/.cache/paru"
        if [[ -d "$paru_cache_dir" ]]; then
            if [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Paru cache wipe skipped in Safe Mode."
            else
                freed_paru=$(track_directory_cleanup "$paru_cache_dir" \
                    "run_as_target_user paru -Sc --noconfirm 2>/dev/null || true; safe_rm_rf '${paru_cache_dir:?}/clone'")
                aur_step_freed=$(( aur_step_freed + freed_paru ))
                print_success "Paru cache cleaned."
            fi
        fi
    fi

    if command -v yay >/dev/null 2>&1; then
        yay_cache_dir="$TARGET_HOME/.cache/yay"
        if [[ -d "$yay_cache_dir" ]]; then
            if [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Yay cache wipe skipped in Safe Mode."
            else
                freed_yay=$(track_directory_cleanup "$yay_cache_dir" \
                    "run_as_target_user yay -Sc --noconfirm 2>/dev/null || true; safe_rm_rf '${yay_cache_dir:?}'")
                aur_step_freed=$(( aur_step_freed + freed_yay ))
                print_success "Yay cache cleaned."
            fi
        fi
    fi

    AUR_CACHES_FREED=$(( AUR_CACHES_FREED + aur_step_freed ))
else
    print_info "Module 'AUR cleanup' skipped."
fi

# 3. Flatpak Cleanup
if [[ "${MODULES[flatpak]}" = true ]]; then
    print_progress "Checking for unused Flatpak runtimes (flatpak uninstall --unused)..."
    if command -v flatpak >/dev/null 2>&1; then
        if [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Flatpak uninstallation skipped in Safe Mode."
        else
            flatpak_step_freed=0
            flatpak_sys_dir="/var/lib/flatpak"
            flatpak_user_dir="$TARGET_HOME/.local/share/flatpak"

            if [[ -d "$flatpak_sys_dir" ]]; then
                f_sys=$(track_directory_cleanup "$flatpak_sys_dir" "flatpak uninstall --unused -y 2>/dev/null || true")
                flatpak_step_freed=$(( flatpak_step_freed + f_sys ))
            fi

            if [[ -d "$flatpak_user_dir" ]]; then
                f_usr=$(track_directory_cleanup "$flatpak_user_dir" "run_as_target_user flatpak uninstall --unused --user -y 2>/dev/null || true")
                flatpak_step_freed=$(( flatpak_step_freed + f_usr ))
            fi

            FLATPAK_FREED=$(( FLATPAK_FREED + flatpak_step_freed ))
            print_success "Flatpak cleanup complete (Freed: $(format_bytes "$flatpak_step_freed"))."
        fi
    else
        print_info "Flatpak not installed. Skipping Flatpak pruning."
    fi
else
    print_info "Module 'Flatpak cleanup' skipped."
fi

# ==============================================================================
# STEP 3: ADVANCED DEEP MAINTENANCE
# ==============================================================================
print_step "3/5" "Advanced Deep Maintenance"

# A. Systemd Journal Growth Monitor & Vacuum
print_progress "Monitoring systemd journal growth & disk consumption..."
current_journal_usage=$(journalctl --disk-usage 2>/dev/null || echo "Unknown disk usage")
echo -e "  ${CYAN}[TREND] Current Journal Consumption:${RESET} ${BOLD}${current_journal_usage}${RESET}"
echo "[$(date -Iseconds)] [JOURNAL-TREND] Pre-vacuum disk usage: ${current_journal_usage}" >> "$LOG_FILE"

journal_target="/var/log/journal"
[[ ! -d "$journal_target" ]] && journal_target="/run/log/journal"

if [[ -d "$journal_target" ]]; then
    print_progress "Vacuuming systemd journal logs to retain 2 weeks..."
    if [[ "$DRY_RUN" = true ]]; then
        print_info "[DRY-RUN] Would vacuum journal to 2 weeks."
    else
        freed_journal=$(track_directory_cleanup "$journal_target" "journalctl --vacuum-time=2weeks")
        JOURNAL_FREED=$(( JOURNAL_FREED + freed_journal ))
        print_success "Systemd journal vacuumed (Freed: $(format_bytes "$freed_journal"))."
    fi
fi

# Core Dumps Purge
print_progress "Inspecting systemd core dumps in /var/lib/systemd/coredump/..."
coredump_dir="/var/lib/systemd/coredump"
if [[ -d "$coredump_dir" ]]; then
    if [[ "$SAFE_MODE" = true ]]; then
        print_info "[SAFE-MODE] Core dump deletion skipped in Safe Mode."
    else
        freed_coredump=$(track_directory_cleanup "$coredump_dir" "safe_rm_rf '${coredump_dir:?}'/*")
        COREDUMPS_FREED=$(( COREDUMPS_FREED + freed_coredump ))
        print_success "Core dumps purged (Freed: $(format_bytes "$freed_coredump"))."
    fi
fi

# B. KDE Cleanup & Baloo Fragmentation Check
if [[ "${MODULES[kde]}" = true ]]; then
    print_progress "Inspecting KDE Baloo file indexer..."
    baloo_dir="$TARGET_HOME/.local/share/baloo"
    kde_step_freed=0

    # Fragmentation Check: inspect index directory structure and split index-* file count
    if [[ -d "$baloo_dir" ]]; then
        frag_count=$(find "$baloo_dir" -maxdepth 1 -type f -name "index-*" 2>/dev/null | wc -l || echo 0)
        baloo_size_bytes=$(get_dir_size_bytes "$baloo_dir")
        echo -e "  ${CYAN}[BALOO-METRICS]${RESET} Split index-* files: ${BOLD}${frag_count}${RESET} (Size: $(format_bytes "$baloo_size_bytes"))"
        echo "[$(date -Iseconds)] [BALOO-METRICS] Split index files: ${frag_count}, Size: ${baloo_size_bytes}B" >> "$LOG_FILE"

        baloo_fragmented=false
        if (( frag_count > 20 )); then
            baloo_fragmented=true
            print_warning "Baloo index exhibits severe LMDB fragmentation (${frag_count} split index-* files detected)."
        fi
    fi

    if command -v balooctl6 >/dev/null 2>&1; then
        baloo_status=$(run_as_target_user balooctl6 status 2>&1 || true)
        baloo_bloated=false

        if (( baloo_size_bytes > 524288000 )); then
            baloo_bloated=true
        fi

        baloo_corrupted=false
        if echo "$baloo_status" | grep -Ei "corrupt|error|failed|not running|unable to open" >/dev/null 2>&1; then
            baloo_corrupted=true
        fi

        if [[ "$baloo_bloated" = true || "$baloo_corrupted" = true || "${baloo_fragmented:-false}" = true ]]; then
            print_warning "Baloo index reset required (Bloated: ${baloo_bloated}, Corrupt: ${baloo_corrupted}, Fragmented: ${baloo_fragmented:-false})."
            if [[ "$DRY_RUN" = true ]]; then
                print_info "[DRY-RUN] Would suspend, purge, and restart Baloo indexer."
            elif [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Baloo index purge skipped in Safe Mode."
            else
                run_as_target_user balooctl6 suspend || true
                f_baloo=$(track_directory_cleanup "$baloo_dir" "run_as_target_user balooctl6 purge")
                kde_step_freed=$(( kde_step_freed + f_baloo ))
                run_as_target_user balooctl6 check || true
                print_success "KDE Baloo indexer purged and rebuilt."
            fi
        else
            print_info "KDE Baloo index is healthy ($(format_bytes "$baloo_size_bytes")). Purge skipped."
        fi
    else
        print_info "balooctl6 not found. Skipping Baloo check."
    fi

    # Kdenlive & Thumbnail Caches
    print_progress "Inspecting Kdenlive proxy and thumbnail caches..."
    kdenlive_proxy="$TARGET_HOME/.local/share/kdenlive/proxy"
    kdenlive_cache="$TARGET_HOME/.cache/kdenlive"
    thumbnails_dir="$TARGET_HOME/.cache/thumbnails"

    if [[ "$SAFE_MODE" = true ]]; then
        print_info "[SAFE-MODE] Kdenlive and thumbnail cache deletions skipped in Safe Mode."
    else
        if [[ -d "$kdenlive_proxy" ]]; then
            f_kproxy=$(track_directory_cleanup "$kdenlive_proxy" "safe_rm_rf '${kdenlive_proxy:?}'/*")
            kde_step_freed=$(( kde_step_freed + f_kproxy ))
        fi
        if [[ -d "$kdenlive_cache" ]]; then
            f_kcache=$(track_directory_cleanup "$kdenlive_cache" "safe_rm_rf '${kdenlive_cache:?}'/*")
            kde_step_freed=$(( kde_step_freed + f_kcache ))
        fi
        if [[ -d "$thumbnails_dir" ]]; then
            f_thumb=$(track_directory_cleanup "$thumbnails_dir" "safe_rm_rf '${thumbnails_dir:?}'/*")
            kde_step_freed=$(( kde_step_freed + f_thumb ))
        fi
    fi

    KDE_CACHES_FREED=$(( KDE_CACHES_FREED + kde_step_freed ))
    print_success "KDE and application scratch caches processed (Freed: $(format_bytes "$kde_step_freed"))."

    # Broken symlinks
    print_progress "Scanning for broken symbolic links in ~/.config and ~/.local..."
    broken_links=()
    while IFS= read -r -d '' link; do
        broken_links+=("$link")
    done < <(find "$TARGET_HOME/.config" "$TARGET_HOME/.local" -xtype l -print0 2>/dev/null || true)

    if [[ ${#broken_links[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Identified ${#broken_links[@]} broken symlink(s):${RESET}"
        for b_link in "${broken_links[@]}"; do
            if [[ "$DRY_RUN" = true ]]; then
                echo -e "  ${CYAN}[DRY-RUN]${RESET} Would remove: $b_link"
            elif [[ "$SAFE_MODE" = true ]]; then
                echo -e "  ${YELLOW}[SAFE-MODE]${RESET} Symlink removal skipped: $b_link"
            else
                echo -e "  ${RED}✗${RESET} Removing: $b_link"
                rm -f "${b_link:?}"
            fi
        done
        print_success "Broken symlinks processed."
    else
        print_info "No broken symlinks found."
    fi
else
    print_info "Module 'KDE cleanup' skipped."
fi

# Btrfs Scrub & SSD TRIM
if [[ "${MODULES[btrfs]}" = true ]]; then
    print_progress "Checking root filesystem type for Btrfs maintenance..."
    root_fs=$(stat -f -c %T / 2>/dev/null || true)
    if [[ "$root_fs" == "btrfs" ]]; then
        print_progress "Initiating lightweight foreground Btrfs scrub on / (btrfs scrub start -Bd /)..."
        if [[ "$DRY_RUN" = true ]]; then
            print_info "[DRY-RUN] Would run: btrfs scrub start -Bd /"
        else
            btrfs scrub start -Bd / 2>/dev/null || print_warning "Btrfs scrub reported warnings or is already running."
            print_success "Btrfs scrub completed."
        fi
    else
        print_info "Root filesystem is ${root_fs:-non-btrfs}. Skipping btrfs scrub."
    fi

    print_progress "Triggering filesystem TRIM across mounted SSDs (fstrim -av)..."
    if [[ "$DRY_RUN" = true ]]; then
        print_info "[DRY-RUN] Would run: fstrim -av"
    else
        if command -v fstrim >/dev/null 2>&1; then
            fstrim -av 2>/dev/null || print_warning "fstrim finished with non-fatal device warnings."
            print_success "Filesystem TRIM completed."
        fi
    fi
else
    print_info "Module 'Btrfs scrub & SSD TRIM' skipped."
fi

# Scan for .pacnew and .pacsave files (Non-destructive, always runs)
print_progress "Scanning /etc for .pacnew and .pacsave files..."
pacfiles=$(find /etc -type f \( -name "*.pacnew" -o -name "*.pacsave" \) 2>/dev/null || true)

if [[ -n "$pacfiles" ]]; then
    echo ""
    echo -e "${RED}${BOLD}==============================================================================${RESET}"
    echo -e "${YELLOW}${BOLD} [!] ACTION REQUIRED: UNMERGED PACMAN CONFIGURATION FILES DETECTED IN /etc    ${RESET}"
    echo -e "${RED}${BOLD}==============================================================================${RESET}"
    echo -e "${YELLOW}The following .pacnew / .pacsave files require manual inspection and merge:${RESET}"
    while IFS= read -r f; do
        echo -e "  ${RED}•${RESET} ${BOLD}$f${RESET}"
    done <<< "$pacfiles"
    echo ""
    echo -e "${YELLOW}Prompt:${RESET} Run ${BOLD}${CYAN}sudo pacdiff${RESET} (or meld) to inspect and merge these changes."
    echo -e "${RED}${BOLD}==============================================================================${RESET}"
    echo ""
else
    print_success "No .pacnew or .pacsave files found in /etc."
fi

# ==============================================================================
# STEP 4: MULTI-DRIVE STEAM ORPHAN SWEEPER
# ==============================================================================
print_step "4/5" "Multi-Drive Steam Orphan Sweeper"

if [[ "${MODULES[steam]}" = true ]]; then
    steam_vdf="$TARGET_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
    if [[ ! -f "$steam_vdf" ]]; then
        if [[ -f "$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf" ]]; then
            steam_vdf="$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf"
        fi
    fi

    if [[ ! -f "$steam_vdf" ]]; then
        print_warning "Steam library manifest not found at: $steam_vdf"
        print_info "Skipping Steam orphan sweep."
    else
        print_progress "Parsing Steam library paths from: $steam_vdf (pure sed/awk, no jq)..."

        active_libraries=()
        while IFS= read -r lib_path; do
            clean_path="${lib_path//\\\\//}"
            clean_path="${clean_path%/}"
            if [[ -n "$clean_path" && -d "$clean_path" ]]; then
                active_libraries+=("$clean_path")
            fi
        done < <(sed -n -E 's/.*"path"[[:space:]]+"([^"]+)".*/\1/p' "$steam_vdf" || true)

        default_steam_path="$TARGET_HOME/.local/share/Steam"
        if [[ -d "$default_steam_path" ]]; then
            is_present=false
            for lib in "${active_libraries[@]}"; do
                if [[ "$lib" == "$default_steam_path" ]]; then
                    is_present=true
                    break
                fi
            done
            if [[ "$is_present" = false ]]; then
                active_libraries+=("$default_steam_path")
            fi
        fi

        echo -e "${CYAN}Discovered active Steam libraries:${RESET}"
        for lib in "${active_libraries[@]}"; do
            echo -e "  - ${WHITE}$lib${RESET}"
        done

        # C. Steam Shadercache Size Monitor & Logging
        print_progress "Monitoring Steam shadercache metrics across discovered libraries..."
        for lib in "${active_libraries[@]}"; do
            candidate_shader="$lib/steamapps/shadercache"
            [[ ! -d "$candidate_shader" && -d "$lib/shadercache" ]] && candidate_shader="$lib/shadercache"
            if [[ -d "$candidate_shader" ]]; then
                shader_size_human=$(du -sh "$candidate_shader" 2>/dev/null | awk '{print $1}' || echo "0B")
                echo -e "  ${CYAN}[PERF-TUNING] Shader Cache at ${lib}:${RESET} ${BOLD}${shader_size_human}${RESET}"
                echo "[$(date -Iseconds)] [STEAM-PERF] Shadercache at ${candidate_shader}: ${shader_size_human}" >> "$LOG_FILE"
            fi
        done

        # Index installed AppIDs across manifests
        print_progress "Indexing installed game manifests (appmanifest_<AppID>.acf)..."
        declare -A installed_appids=()
        installed_count=0

        for lib in "${active_libraries[@]}"; do
            manifest_dirs=()
            [[ -d "$lib/steamapps" ]] && manifest_dirs+=("$lib/steamapps")
            [[ -d "$lib" ]] && manifest_dirs+=("$lib")

            for m_dir in "${manifest_dirs[@]}"; do
                for manifest_file in "$m_dir"/appmanifest_*.acf; do
                    if [[ -f "$manifest_file" ]]; then
                        base_name=$(basename "$manifest_file")
                        if [[ "$base_name" =~ ^appmanifest_([0-9]+)\.acf$ ]]; then
                            appid="${BASH_REMATCH[1]}"
                            if [[ -z "${installed_appids[$appid]:-}" ]]; then
                                installed_appids["$appid"]=1
                                ((installed_count++)) || true
                            fi
                        fi
                    fi
                done
            done
        done

        print_info "Indexed ${BOLD}${installed_count}${RESET} installed game AppID(s)."

        # Scan for orphaned shader caches and compatdata Proton prefixes
        print_progress "Scanning for abandoned prefixes and shader caches..."
        removed_count=0
        steam_step_freed=0

        for lib in "${active_libraries[@]}"; do
            check_dirs=()
            [[ -d "$lib/steamapps/shadercache" ]] && check_dirs+=("$lib/steamapps/shadercache")
            [[ -d "$lib/shadercache" && "$lib/shadercache" != "$lib/steamapps/shadercache" ]] && check_dirs+=("$lib/shadercache")
            [[ -d "$lib/steamapps/compatdata" ]] && check_dirs+=("$lib/steamapps/compatdata")
            [[ -d "$lib/compatdata" && "$lib/compatdata" != "$lib/steamapps/compatdata" ]] && check_dirs+=("$lib/compatdata")

            for c_dir in "${check_dirs[@]}"; do
                cache_type=$(basename "$c_dir")
                for entry in "$c_dir"/*; do
                    if [[ -d "$entry" ]]; then
                        entry_name=$(basename "$entry")
                        if [[ "$entry_name" =~ ^[0-9]+$ ]]; then
                            if [[ -z "${installed_appids[$entry_name]:-}" ]]; then
                                folder_freed=$(track_directory_cleanup "$entry" "safe_rm_rf '${entry:?}'")
                                steam_step_freed=$(( steam_step_freed + folder_freed ))
                                if [[ "$DRY_RUN" = true ]]; then
                                    echo -e "  ${CYAN}[DRY-RUN]${RESET} Would remove orphan AppID: ${BOLD}${RED}${entry_name}${RESET} [Type: ${cache_type}] [Size: $(format_bytes "$folder_freed")]"
                                elif [[ "$SAFE_MODE" = true ]]; then
                                    echo -e "  ${YELLOW}[SAFE-MODE]${RESET} Orphan AppID detected but deletion skipped: ${BOLD}${entry_name}${RESET} [Type: ${cache_type}]"
                                else
                                    echo -e "  ${YELLOW}• Removed orphan AppID:${RESET} ${BOLD}${RED}${entry_name}${RESET} [Type: ${cache_type}] [Path: ${entry}] [Freed: $(format_bytes "$folder_freed")]"
                                fi
                                ((removed_count++)) || true
                            fi
                        fi
                    fi
                done
            done
        done

        STEAM_ORPHANS_FREED=$(( STEAM_ORPHANS_FREED + steam_step_freed ))

        if [[ $removed_count -gt 0 ]]; then
            print_success "Processed ${removed_count} abandoned prefix/cache folder(s) (Freed: $(format_bytes "$steam_step_freed"))."
        else
            print_info "No orphaned Steam shader caches or compatdata prefixes found."
        fi
    fi
else
    print_info "Module 'Steam orphan sweeper' skipped."
fi

# ==============================================================================
# STEP 5: PROTON DRIVE PAYLOAD & FINISH
# ==============================================================================
print_step "5/5" "Proton Drive Payload & Finish"

BACKUP_DATE=$(date +"%Y-%m-%d")
ARCHIVE_FILENAME="CachyOS-Config-Backup-${BACKUP_DATE}.tar.zst"
DESKTOP_DIR="$TARGET_HOME/Desktop"
ARCHIVE_TARGET="$DESKTOP_DIR/$ARCHIVE_FILENAME"

if [[ "${MODULES[backup]}" = true ]]; then
    mkdir -p "$DESKTOP_DIR"

    print_progress "Assembling selective configuration backup archive..."

    backup_items=()
    [[ -d "$TARGET_HOME/.config" ]] && backup_items+=(".config")
    [[ -f "$TARGET_HOME/.bashrc" ]] && backup_items+=(".bashrc")
    [[ -f "$TARGET_HOME/.zshrc" ]] && backup_items+=(".zshrc")

    kde_share_folders=(
        ".local/share/konsole"
        ".local/share/plasma"
        ".local/share/kxmlgui5"
        ".local/share/kxmlgui6"
        ".local/share/kdenlive"
        ".local/share/color-schemes"
        ".local/share/dolphin"
        ".local/share/plasma-systemmonitor"
        ".local/share/applications"
    )

    for k_folder in "${kde_share_folders[@]}"; do
        if [[ -d "$TARGET_HOME/$k_folder" ]]; then
            backup_items+=("$k_folder")
        fi
    done

    if [[ ${#backup_items[@]} -eq 0 ]]; then
        print_warning "No configuration items found to archive."
    else
        print_progress "Archiving configuration items with tar (zstd)..."
        if [[ "$DRY_RUN" = true ]]; then
            print_info "[DRY-RUN] Would create tar.zst archive at: ${ARCHIVE_TARGET}"
        else
            tar --zstd \
                --exclude="*/cache/*" \
                --exclude="*/proxy/*" \
                -cf "$ARCHIVE_TARGET" \
                -C "$TARGET_HOME" \
                "${backup_items[@]}"

            chown "$TARGET_USER:$TARGET_USER" "$ARCHIVE_TARGET"
            archive_size=$(du -h "$ARCHIVE_TARGET" 2>/dev/null | cut -f1 || echo "unknown")
            print_success "Configuration archive created: ${ARCHIVE_TARGET} (${archive_size})"
        fi
    fi
else
    print_info "Module 'Backup' skipped."
fi

# ==============================================================================
# SUMMARY TABLE & NOTIFICATION
# ==============================================================================
print_summary_table

# Final Reminder & Success Box
echo -e "${GREEN}${BOLD}==============================================================================${RESET}"
echo -e "${GREEN}${BOLD}             ALL HOUSEKEEPING OPERATIONS COMPLETED SUCCESSFULLY!              ${RESET}"
echo -e "${GREEN}${BOLD}==============================================================================${RESET}"

if [[ "${MODULES[backup]}" = true && -f "$ARCHIVE_TARGET" ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}==> PROTON DRIVE BACKUP ACTION REQUIRED:${RESET}"
    echo -e "    Drag your new configuration archive directly into ${BOLD}Proton Drive${RESET}:"
    echo -e "    ${WHITE}${BOLD}${ARCHIVE_TARGET}${RESET}"
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${RESET}"
fi
echo ""
