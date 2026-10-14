#!/usr/bin/env bash
# ==============================================================================
# CachyOS & KDE Plasma Comprehensive Housekeeping Suite
# ==============================================================================
# SCRIPT_VERSION="2026.10.16"
# AUTHOR="Zarrotox"
#
# Description: Production-grade system maintenance, optimization, and backup
#              automation suite engineered for CachyOS / Arch Linux with KDE Plasma 6.
#
# Hardening & Standards:
#   - set -euo pipefail with defensive guards against false exits
#   - Strict variable initialization under nounset
#   - Function-driven execution (zero eval usage)
#   - stdout-clean directory size tracking (du telemetry to stderr)
#   - Ironclad safe_rm_rf() with root/system/traversal barriers
#   - Steam compatdata preservation (retention of user save prefixes)
#   - Missing library detection & zero false-orphan safeguards
#   - Verified success telemetry (no false-positive success reporting)
#   - Consistent Safe Mode policy across all modules
#   - Robust desktop user detection (sudo, pkexec, systemd logind, cli overrides)
#   - Atomic, restricted-permission configuration backup to XDG Desktop
# ==============================================================================

# Strict Bash Mode
set -euo pipefail

# Script Version
SCRIPT_VERSION="2026.10.16"

# ------------------------------------------------------------------------------
# Global Telemetry Counters & Variables
# ------------------------------------------------------------------------------
WARNING_COUNT=0
FAILURE_COUNT=0

PACMAN_CACHE_FREED=0
AUR_CACHES_FREED=0
FLATPAK_FREED=0
JOURNAL_FREED=0
COREDUMPS_FREED=0
KDE_CACHES_FREED=0
STEAM_ORPHANS_FREED=0

BALOO_BIN=""
SNAPSHOT_BACKEND=""

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
UNATTENDED=false
USER_MODULES=""
OVERRIDE_USER=""

show_version() {
    echo "CachyOS Housekeeping Suite v${SCRIPT_VERSION} by ${AUTHOR:-Zarrotox}"
}

show_help() {
    cat << EOF
Usage: sudo ./cachyos-housekeeping.sh [OPTIONS]

Comprehensive maintenance, sanitization, and backup suite for CachyOS / KDE Plasma 6.

Execution Modes:
  -d, --dry-run             Simulate all operations without modifying or deleting files.
  -s, --safe-mode           Execute non-destructive tasks (Snapper/Timeshift, btrfs scrub, fstrim,
                            journal vacuum, backup) while strictly prohibiting all 'rm -rf'
                            and uninstallation deletions.

Module Selection:
  -a, --all                 Execute all modules without prompting the module selector.
  -m, --modules <LIST>      Comma-separated list of modules to execute.
                            Available: pacman, aur, flatpak, kde, steam, btrfs, backup

Automation & Overrides:
  -y, --yes                 Unattended mode: bypass interactive execution confirmation.
  -u, --target-user <USER>  Explicitly specify the desktop target username for permissions,
                            paths, and DBus notifications.

Information:
  -v, --version             Print script version and exit.
  -h, --help                Display this help message and exit.

Examples:
  sudo ./cachyos-housekeeping.sh                  # Interactive mode with module selector
  sudo ./cachyos-housekeeping.sh --dry-run        # Complete dry-run simulation
  sudo ./cachyos-housekeeping.sh --safe-mode       # Safe mode (zero file deletions)
  sudo ./cachyos-housekeeping.sh -a -y            # Fully unattended maintenance run
  sudo ./cachyos-housekeeping.sh -m pacman,steam  # Execute only Pacman and Steam modules

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
            if [[ $# -lt 2 || -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: Option --modules requires a non-empty comma-separated list of modules." >&2
                show_help
                exit 1
            fi
            USER_MODULES="$2"
            shift 2
            ;;
        -y|--yes)
            UNATTENDED=true
            shift
            ;;
        -u|--target-user)
            if [[ $# -lt 2 || -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: Option --target-user requires a valid username." >&2
                show_help
                exit 1
            fi
            OVERRIDE_USER="$2"
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
            echo "Error: Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Argument Compatibility Checks
if [[ "$DRY_RUN" = true && "$SAFE_MODE" = true ]]; then
    echo "Error: Conflicting options: --dry-run and --safe-mode cannot be used together." >&2
    echo "  --dry-run: simulates all actions without touching the system." >&2
    echo "  --safe-mode: executes non-destructive tasks but prohibits file deletions." >&2
    exit 1
fi

if [[ "$SELECT_ALL_MODULES" = true && -n "$USER_MODULES" ]]; then
    echo "Error: Conflicting options: --all and --modules cannot be used together." >&2
    exit 1
fi

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
    echo -e "${YELLOW}${BOLD}[!] WARNING:${RESET} $1" >&2
    (( WARNING_COUNT++ )) || true
}

print_error() {
    echo -e "${RED}${BOLD}[✗] ERROR:${RESET} $1" >&2
    (( FAILURE_COUNT++ )) || true
}

print_info() {
    echo -e "${CYAN}[i]${RESET} $1"
}

# ------------------------------------------------------------------------------
# Privilege & Desktop User Discovery
# ------------------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    print_error "This script must be executed with root privileges via sudo:"
    echo "  sudo $0 $*" >&2
    exit 1
fi

detect_target_user() {
    if [[ -n "${OVERRIDE_USER:-}" ]]; then
        if getent passwd "$OVERRIDE_USER" >/dev/null 2>&1; then
            echo "$OVERRIDE_USER"
            return 0
        else
            echo "Error: Specified target user '$OVERRIDE_USER' does not exist." >&2
            exit 1
        fi
    fi

    # 1. SUDO_USER (standard sudo invocation)
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        if getent passwd "$SUDO_USER" >/dev/null 2>&1; then
            echo "$SUDO_USER"
            return 0
        fi
    fi

    # 2. PKEXEC_UID (PolicyKit invocation)
    if [[ -n "${PKEXEC_UID:-}" && "$PKEXEC_UID" -ne 0 ]]; then
        local pk_user
        pk_user=$(id -nu "$PKEXEC_UID" 2>/dev/null || true)
        if [[ -n "$pk_user" && "$pk_user" != "root" ]]; then
            echo "$pk_user"
            return 0
        fi
    fi

    # 3. Active graphical desktop user via loginctl (Wayland/X11)
    if command -v loginctl >/dev/null 2>&1; then
        local s_id s_type s_user
        while read -r s_id _ s_user _; do
            if [[ -n "$s_id" && "$s_id" =~ ^[0-9a-zA-Z]+$ && "$s_user" != "root" ]]; then
                s_type=$(loginctl show-session -p Type "$s_id" 2>/dev/null | cut -d= -f2 || true)
                if [[ "$s_type" =~ ^(wayland|x11)$ ]]; then
                    echo "$s_user"
                    return 0
                fi
            fi
        done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
    fi

    # 4. logname fallback
    local l_name
    l_name=$(logname 2>/dev/null || true)
    if [[ -n "$l_name" && "$l_name" != "root" ]] && getent passwd "$l_name" >/dev/null 2>&1; then
        echo "$l_name"
        return 0
    fi

    # 5. who login session fallback
    local w_user
    w_user=$(who -u 2>/dev/null | awk '$1 != "root" {print $1}' | head -n1 || true)
    if [[ -n "$w_user" ]] && getent passwd "$w_user" >/dev/null 2>&1; then
        echo "$w_user"
        return 0
    fi

    # 6. Fallback to root for headless/container environments
    echo "root"
}

TARGET_USER=$(detect_target_user)
TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GROUP=$(id -gn "$TARGET_USER" 2>/dev/null || id -un "$TARGET_USER")
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

run_as_target_user() {
    if [[ "$TARGET_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" "$@"
    else
        "$@"
    fi
}

# ------------------------------------------------------------------------------
# Hardened Safe Removal Wrapper Function
# ------------------------------------------------------------------------------
safe_rm_rf() {
    local target="${1:-}"

    if [[ -z "${target// /}" ]]; then
        print_error "safe_rm_rf: refused deletion of empty path argument."
        return 1
    fi

    # Reject direct relative references
    if [[ "$target" == "." || "$target" == ".." || "$target" == *".."* ]]; then
        print_error "safe_rm_rf: refused traversing or relative path: '$target'."
        return 1
    fi

    local canon_path
    if [[ -L "$target" ]]; then
        canon_path=$(realpath -s -m -- "$target" 2>/dev/null || echo "")
    else
        canon_path=$(realpath -m -- "$target" 2>/dev/null || echo "")
    fi

    if [[ -z "$canon_path" ]]; then
        print_error "safe_rm_rf: could not resolve canonical path for: '$target'."
        return 1
    fi

    local check_path="${canon_path%/}"
    [[ -z "$check_path" ]] && check_path="/"

    # Refuse root and critical system trees
    case "$check_path" in
        /run/media/*/*/*)
            # Allowed: files and subdirectories located inside mounted secondary storage volumes
            ;;
        /|/root|/home|/etc|/etc/*|/usr|/usr/*|/var|/var/log|/var/log/*|/boot|/boot/*|/sys|/sys/*|/proc|/proc/*|/dev|/dev/*|/run|/run/*|/run/media|/run/media/*|/run/media/*/*)
            print_error "safe_rm_rf: CRITICAL - Refused deletion of protected system path: '$canon_path'."
            return 1
            ;;
    esac

    # Refuse home directory root
    if [[ "$check_path" == "${TARGET_HOME%/}" ]]; then
        print_error "safe_rm_rf: CRITICAL - Refused deletion of user home root: '$canon_path'."
        return 1
    fi

    if [[ "$DRY_RUN" = true ]]; then
        echo -e "    ${CYAN}[DRY-RUN]${RESET} Would delete: ${canon_path}" >&2
        return 0
    elif [[ "$SAFE_MODE" = true ]]; then
        echo -e "    ${YELLOW}[SAFE-MODE]${RESET} Deletion prevented: ${canon_path}" >&2
        return 0
    else
        rm -rf -- "${canon_path:?}"
        return 0
    fi
}

# ------------------------------------------------------------------------------
# Safe Directory Contents Removal Wrapper Function
# Safely removes all contents inside a directory without deleting the directory itself
# and without relying on shell wildcards that fail when quoted.
# ------------------------------------------------------------------------------
safe_empty_directory() {
    local target_dir="${1:-}"

    if [[ -z "${target_dir// /}" ]]; then
        print_error "safe_empty_directory: refused empty path argument."
        return 1
    fi

    if [[ ! -d "$target_dir" ]]; then
        return 0
    fi

    local canon_dir
    canon_dir=$(realpath -m -- "$target_dir" 2>/dev/null || echo "")

    if [[ -z "$canon_dir" ]]; then
        print_error "safe_empty_directory: could not resolve canonical path for: '$target_dir'."
        return 1
    fi

    local check_path="${canon_dir%/}"
    [[ -z "$check_path" ]] && check_path="/"

    # Refuse root and critical system trees
    case "$check_path" in
        /run/media/*/*/*)
            # Allowed: subdirectories located inside mounted secondary storage volumes
            ;;
        /|/root|/home|/etc|/etc/*|/usr|/usr/*|/var|/var/log|/var/log/*|/boot|/boot/*|/sys|/sys/*|/proc|/proc/*|/dev|/dev/*|/run|/run/*|/run/media|/run/media/*|/run/media/*/*)
            print_error "safe_empty_directory: CRITICAL - Refused emptying protected system directory: '$canon_dir'."
            return 1
            ;;
    esac

    # Refuse user home root
    if [[ "$check_path" == "${TARGET_HOME%/}" ]]; then
        print_error "safe_empty_directory: CRITICAL - Refused emptying user home root: '$canon_dir'."
        return 1
    fi

    local item has_nullglob has_dotglob rm_err=0
    shopt -q nullglob && has_nullglob=1 || has_nullglob=0
    shopt -q dotglob && has_dotglob=1 || has_dotglob=0
    shopt -s nullglob dotglob

    for item in "$canon_dir"/*; do
        [[ -e "$item" || -L "$item" ]] || continue
        local b_name
        b_name=$(basename -- "$item")
        [[ "$b_name" == "." || "$b_name" == ".." ]] && continue
        if ! safe_rm_rf "$item"; then
            rm_err=1
        fi
    done

    (( has_dotglob == 0 )) && shopt -u dotglob
    (( has_nullglob == 0 )) && shopt -u nullglob

    if (( rm_err != 0 )); then
        return 1
    fi
    return 0
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
    local clean_m
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
        local num_sel=""
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
    if [[ "$UNATTENDED" = true ]]; then
        print_info "Unattended mode active (-y/--yes). Bypassing confirmation."
        return 0
    fi

    if [[ "$DRY_RUN" = true ]]; then
        print_info "Dry-Run mode active. No changes will be committed to disk."
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
        local response=""
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
# Logging Tee & File Initialization
# ------------------------------------------------------------------------------
LOG_FILE="/var/log/cachyos-housekeeping.log"
if ! touch "$LOG_FILE" 2>/dev/null; then
    LOG_FILE="/tmp/cachyos-housekeeping.log"
    touch "$LOG_FILE" 2>/dev/null || true
fi
chmod 640 "$LOG_FILE" 2>/dev/null || true

# Tee stdout & stderr to log file while preserving live terminal view
exec > >(tee -a "$LOG_FILE") 2>&1

print_banner
if [[ "$DRY_RUN" = true ]]; then
    echo -e "${YELLOW}${BOLD}>>> MODE: DRY-RUN (SIMULATION ONLY) <<<${RESET}\n"
elif [[ "$SAFE_MODE" = true ]]; then
    echo -e "${GREEN}${BOLD}>>> MODE: SAFE-MODE (ALL RM-RF DELETIONS DISABLED) <<<${RESET}\n"
else
    echo -e "${CYAN}${BOLD}>>> MODE: STANDARD EXECUTION <<<${RESET}\n"
fi

print_info "Desktop User: ${BOLD}${TARGET_USER}${RESET} (UID: ${TARGET_UID}, Group: ${TARGET_GROUP}, Home: ${TARGET_HOME})"
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
# Disk Space Tracking Engine (Clean Telemetry)
# ------------------------------------------------------------------------------
format_bytes() {
    local bytes="${1:-0}"
    if [[ ! "$bytes" =~ ^[0-9]+$ || "$bytes" -le 0 ]]; then
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
    local target_path="${1:-}"
    if [[ -n "$target_path" && -e "$target_path" ]]; then
        local size_bytes
        size_bytes=$(du -s -B1 -- "$target_path" 2>/dev/null | awk '{print $1}' || echo "0")
        if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
            printf '%u\n' "$size_bytes"
            return 0
        fi
    fi
    printf '%u\n' 0
}

# Reusable tracking wrapper:
# Guarantees that stdout contains ONLY the numeric integer byte count.
# Human messages and callback output are routed to stderr so arithmetic
# captures are never contaminated.
track_directory_cleanup() {
    local dir_path="${1:?Directory path missing}"
    shift
    local size_before size_after freed_bytes=0

    size_before=$(get_dir_size_bytes "$dir_path")

    local callback_cmd="${1:-}"
    case "$callback_cmd" in
        delete_steam_dir|safe_rm_rf|safe_empty_directory|purge_coredumps|clean_kdenlive_*|clean_thumbnail_*)
            # Safe removal functions with internal DRY_RUN and SAFE_MODE handlers.
            # Execute them so path safety validation runs even during dry-run audits.
            local callback_rc=0
            if [[ $# -gt 0 ]]; then
                "$@" >&2 || callback_rc=$?
            fi

            if (( callback_rc != 0 )); then
                print_error "track_directory_cleanup: callback command failed for '${dir_path}' (exit code: ${callback_rc})."
                printf '%u\n' 0
                return "$callback_rc"
            fi

            if [[ "$DRY_RUN" = true ]]; then
                printf '%u\n' "$size_before"
                return 0
            elif [[ "$SAFE_MODE" = true ]]; then
                printf '%u\n' 0
                return 0
            fi
            ;;
        *)
            if [[ "$DRY_RUN" = true ]]; then
                echo -e "    ${CYAN}[DRY-RUN]${RESET} Would execute cleanup on: ${dir_path}" >&2
                printf '%u\n' "$size_before"
                return 0
            elif [[ "$SAFE_MODE" = true ]]; then
                echo -e "    ${YELLOW}[SAFE-MODE]${RESET} Deletion skipped for: ${dir_path}" >&2
                printf '%u\n' 0
                return 0
            fi

            # Execute callback safely without eval; route stdout to stderr and capture return status
            local callback_rc=0
            if [[ $# -gt 0 ]]; then
                "$@" >&2 || callback_rc=$?
            fi

            if (( callback_rc != 0 )); then
                print_error "track_directory_cleanup: callback command failed for '${dir_path}' (exit code: ${callback_rc})."
                printf '%u\n' 0
                return "$callback_rc"
            fi
            ;;
    esac

    size_after=$(get_dir_size_bytes "$dir_path")

    if (( size_before > size_after )); then
        freed_bytes=$(( size_before - size_after ))
    fi

    if [[ "$freed_bytes" =~ ^[0-9]+$ ]]; then
        printf '%u\n' "$freed_bytes"
    else
        printf '%u\n' 0
    fi
    return 0
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
# Telemetry Summary Table & Reporting
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

    # Overall Status Evaluation
    local overall_status="SUCCESS"
    if (( FAILURE_COUNT > 0 )); then
        overall_status="PARTIAL FAILURE (${FAILURE_COUNT} error(s), ${WARNING_COUNT} warning(s))"
    elif (( WARNING_COUNT > 0 )); then
        overall_status="SUCCESS WITH WARNINGS (${WARNING_COUNT} warning(s))"
    fi

    printf "  ${BOLD}%-22s${RESET} ${CYAN}%-50s${RESET}\n" "Mode:" "${exec_mode}"
    printf "  ${BOLD}%-22s${RESET} ${WHITE}%-50s${RESET}\n" "Modules executed:" "${modules_str}"
    printf "  ${BOLD}%-22s${RESET} " "Status:"
    if (( FAILURE_COUNT > 0 )); then
        echo -e "${RED}${BOLD}${overall_status}${RESET}"
    elif (( WARNING_COUNT > 0 )); then
        echo -e "${YELLOW}${BOLD}${overall_status}${RESET}"
    else
        echo -e "${GREEN}${BOLD}${overall_status}${RESET}"
    fi
    echo -e "${CYAN}${BOLD}==============================================================================${RESET}"
    echo ""

    echo "[$(date -Iseconds)] [SESSION-SUMMARY] Status: ${overall_status} | Mode: ${exec_mode} | Modules: ${modules_str} | Reclaimed: ${grand_total_fmt}" >> "$LOG_FILE"

    send_kde_notification "$grand_total_fmt"
}

# ==============================================================================
# PREFLIGHT CHECKS & DEPENDENCY VERIFICATION
# ==============================================================================
run_preflight_checks() {
    print_step "0/5" "Preflight Dependency & System Verification"
    local preflight_fatal=false

    # 1. Snapshot backend check (Snapper or Timeshift for rollback guarantee)
    if command -v snapper >/dev/null 2>&1; then
        SNAPSHOT_BACKEND="snapper"
        print_success "Preflight: Snapshot backend detected: snapper."
    elif command -v timeshift >/dev/null 2>&1; then
        SNAPSHOT_BACKEND="timeshift"
        print_success "Preflight: Snapshot backend detected: timeshift."
    else
        preflight_fatal=true
        print_error "Preflight: Neither 'snapper' nor 'timeshift' is installed. A snapshot backend is required for system rollback safety."
        echo "    Remedy: Install with 'sudo pacman -S snapper' or 'sudo pacman -S timeshift'." >&2
    fi

    # 2. pacman-contrib check (paccache)
    if [[ "${MODULES[pacman]}" = true ]]; then
        if ! command -v paccache >/dev/null 2>&1; then
            print_error "Preflight: 'paccache' is not installed (pacman module active)."
            echo "    Remedy: Install with 'sudo pacman -S pacman-contrib'." >&2
            preflight_fatal=true
        else
            print_success "Preflight: pacman-contrib (paccache) is installed."
        fi
    fi

    # 3. Baloo control utility resolution (detect once, reuse throughout)
    if [[ "${MODULES[kde]}" = true ]]; then
        if command -v balooctl6 >/dev/null 2>&1; then
            BALOO_BIN="balooctl6"
            print_success "Preflight: KDE Baloo control utility detected: balooctl6."
        elif command -v balooctl >/dev/null 2>&1; then
            BALOO_BIN="balooctl"
            print_success "Preflight: KDE Baloo control utility detected: balooctl."
        else
            print_warning "Preflight: neither 'balooctl6' nor 'balooctl' was found; Baloo reset will be skipped."
            BALOO_BIN=""
        fi
    fi

    # 4. flatpak check
    if [[ "${MODULES[flatpak]}" = true ]]; then
        if ! command -v flatpak >/dev/null 2>&1; then
            print_warning "Preflight: 'flatpak' command not found; flatpak module will be skipped."
            MODULES[flatpak]=false
        else
            print_success "Preflight: Flatpak is installed."
        fi
    fi

    # 5. Steam library manifest verification (Graceful degradation)
    if [[ "${MODULES[steam]}" = true ]]; then
        local steam_vdf="$TARGET_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
        [[ ! -f "$steam_vdf" && -f "$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf" ]] && steam_vdf="$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf"
        if [[ ! -f "$steam_vdf" ]]; then
            print_warning "Preflight: Steam library manifest not found. Disabling Steam module for this run."
            MODULES[steam]=false
        else
            print_success "Preflight: Steam library manifest verified (${steam_vdf})."
        fi
    fi

    # 6. Btrfs & fstrim validation
    if [[ "${MODULES[btrfs]}" = true ]]; then
        local root_fs
        root_fs=$(stat -f -c %T / 2>/dev/null || true)
        if [[ "$root_fs" == "btrfs" ]] && ! command -v btrfs >/dev/null 2>&1; then
            print_warning "Preflight: Root is Btrfs but 'btrfs' CLI is not found."
        fi
        if ! command -v fstrim >/dev/null 2>&1; then
            print_warning "Preflight: 'fstrim' utility not found; SSD TRIM will be skipped."
        fi
    fi

    # 7. Backup dependencies
    if [[ "${MODULES[backup]}" = true ]]; then
        if ! command -v tar >/dev/null 2>&1; then
            print_error "Preflight: 'tar' utility not found (backup module active)."
            preflight_fatal=true
        fi
        if ! command -v zstd >/dev/null 2>&1; then
            print_error "Preflight: 'zstd' utility not found (backup module active)."
            preflight_fatal=true
        fi
    fi

    # 8. journalctl check
    if ! command -v journalctl >/dev/null 2>&1; then
        print_warning "Preflight: 'journalctl' not found; journal vacuuming will be skipped."
    fi

    if [[ "$preflight_fatal" = true ]]; then
        echo ""
        print_error "Preflight verification encountered fatal errors. Aborting housekeeping."
        exit 1
    fi
}

run_preflight_checks

# ==============================================================================
# STEP 1: SYSTEM SAFETY (PRE-HOUSEKEEPING SNAPSHOT)
# ==============================================================================
run_system_safety() {
    print_step "1/5" "System Safety (Pre-Housekeeping Snapshot)"

    if [[ "$DRY_RUN" = true ]]; then
        print_info "[DRY-RUN] Would create 'Pre-Housekeeping' system snapshot via ${SNAPSHOT_BACKEND}."
        return 0
    fi

    if [[ "$SNAPSHOT_BACKEND" == "snapper" ]]; then
        print_progress "Triggering Snapper snapshot labeled 'Pre-Housekeeping'..."
        if snapper -c root create --description "Pre-Housekeeping" --cleanup-algorithm number 2>/dev/null || snapper create --description "Pre-Housekeeping"; then
            print_success "Snapper snapshot 'Pre-Housekeeping' created successfully."
        else
            print_error "Snapper snapshot creation FAILED!"
            print_error "CRITICAL: Halting execution immediately to protect system integrity."
            print_error "No cleanup or modification tasks have been performed."
            exit 1
        fi
    elif [[ "$SNAPSHOT_BACKEND" == "timeshift" ]]; then
        print_progress "Triggering Timeshift snapshot labeled 'Pre-Housekeeping'..."
        if timeshift --create --comments 'Pre-Housekeeping'; then
            print_success "Timeshift snapshot 'Pre-Housekeeping' created successfully."
        else
            print_error "Timeshift snapshot creation FAILED!"
            print_error "CRITICAL: Halting execution immediately to protect system integrity."
            print_error "No cleanup or modification tasks have been performed."
            exit 1
        fi
    else
        print_error "No valid snapshot backend configured! Cannot guarantee system safety."
        print_error "CRITICAL: Halting execution immediately to protect system integrity."
        exit 1
    fi
}

run_system_safety

# ==============================================================================
# STEP 2: ARCH PACKAGE CLEANUP FUNCTIONS
# ==============================================================================
clean_pacman_cache() {
    paccache -rk2
}

run_pacman_cleanup() {
    print_progress "Probing for orphaned packages (pacman -Qtdq)..."
    local orphans=""
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
            if pacman -Rns --noconfirm $orphans; then
                print_success "Orphaned packages removed."
            else
                print_error "Failed to remove some orphaned packages."
            fi
        fi
    else
        print_info "No orphaned dependencies found."
    fi

    print_progress "Trimming pacman package cache (paccache -rk2)..."
    local pacman_cache_dir="/var/cache/pacman/pkg"
    if command -v paccache >/dev/null 2>&1; then
        if [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Package cache deletion skipped in Safe Mode."
        else
            local freed_pac=0
            if freed_pac=$(track_directory_cleanup "$pacman_cache_dir" clean_pacman_cache); then
                PACMAN_CACHE_FREED=$(( PACMAN_CACHE_FREED + freed_pac ))
                print_success "Pacman cache trimmed (Freed: $(format_bytes "$freed_pac"))."
            else
                print_error "Failed to trim pacman cache via paccache."
            fi
        fi
    else
        print_warning "paccache not found (pacman-contrib may not be installed)."
    fi
}

clean_paru_helper() {
    local paru_dir="${1:?Paru dir missing}"
    run_as_target_user paru -Sc --noconfirm 2>/dev/null || true
    safe_rm_rf "${paru_dir}/clone"
}

clean_yay_helper() {
    local yay_dir="${1:?Yay dir missing}"
    run_as_target_user yay -Sc --noconfirm 2>/dev/null || true
    safe_rm_rf "${yay_dir}"
}

run_aur_cleanup() {
    print_progress "Checking for AUR helper build caches..."
    local aur_step_freed=0

    if command -v paru >/dev/null 2>&1; then
        local paru_cache_dir="$TARGET_HOME/.cache/paru"
        if [[ -d "$paru_cache_dir" ]]; then
            if [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Paru cache wipe skipped in Safe Mode."
            else
                local freed_paru=0
                if freed_paru=$(track_directory_cleanup "$paru_cache_dir" clean_paru_helper "$paru_cache_dir"); then
                    aur_step_freed=$(( aur_step_freed + freed_paru ))
                    print_success "Paru cache cleaned."
                else
                    print_error "Failed to clean Paru cache."
                fi
            fi
        fi
    fi

    if command -v yay >/dev/null 2>&1; then
        local yay_cache_dir="$TARGET_HOME/.cache/yay"
        if [[ -d "$yay_cache_dir" ]]; then
            if [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Yay cache wipe skipped in Safe Mode."
            else
                local freed_yay=0
                if freed_yay=$(track_directory_cleanup "$yay_cache_dir" clean_yay_helper "$yay_cache_dir"); then
                    aur_step_freed=$(( aur_step_freed + freed_yay ))
                    print_success "Yay cache cleaned."
                else
                    print_error "Failed to clean Yay cache."
                fi
            fi
        fi
    fi

    AUR_CACHES_FREED=$(( AUR_CACHES_FREED + aur_step_freed ))
}

clean_flatpak_system() {
    flatpak uninstall --unused -y
}

clean_flatpak_user() {
    run_as_target_user flatpak uninstall --unused --user -y
}

run_flatpak_cleanup() {
    print_progress "Checking for unused Flatpak runtimes (flatpak uninstall --unused)..."
    if command -v flatpak >/dev/null 2>&1; then
        if [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Flatpak uninstallation skipped in Safe Mode."
        else
            local flatpak_step_freed=0
            local flatpak_sys_dir="/var/lib/flatpak"
            local flatpak_user_dir="$TARGET_HOME/.local/share/flatpak"

            if [[ -d "$flatpak_sys_dir" ]]; then
                local f_sys=0
                if f_sys=$(track_directory_cleanup "$flatpak_sys_dir" clean_flatpak_system); then
                    flatpak_step_freed=$(( flatpak_step_freed + f_sys ))
                else
                    print_error "Failed to clean system Flatpak runtimes."
                fi
            fi

            if [[ -d "$flatpak_user_dir" ]]; then
                local f_usr=0
                if f_usr=$(track_directory_cleanup "$flatpak_user_dir" clean_flatpak_user); then
                    flatpak_step_freed=$(( flatpak_step_freed + f_usr ))
                else
                    print_error "Failed to clean user Flatpak runtimes."
                fi
            fi

            FLATPAK_FREED=$(( FLATPAK_FREED + flatpak_step_freed ))
            print_success "Flatpak cleanup complete (Freed: $(format_bytes "$flatpak_step_freed"))."
        fi
    else
        print_info "Flatpak not installed. Skipping Flatpak pruning."
    fi
}

# Execute Step 2
print_step "2/5" "Arch Package Cleanup"
if [[ "${MODULES[pacman]}" = true ]]; then
    run_pacman_cleanup
else
    print_info "Module 'Pacman cleanup' skipped."
fi

if [[ "${MODULES[aur]}" = true ]]; then
    run_aur_cleanup
else
    print_info "Module 'AUR cleanup' skipped."
fi

if [[ "${MODULES[flatpak]}" = true ]]; then
    run_flatpak_cleanup
else
    print_info "Module 'Flatpak cleanup' skipped."
fi

# ==============================================================================
# STEP 3: ADVANCED DEEP MAINTENANCE FUNCTIONS
# ==============================================================================
vacuum_journal() {
    journalctl --vacuum-time=2weeks
}

run_journal_maintenance() {
    print_progress "Monitoring systemd journal growth & disk consumption..."
    local current_journal_usage=""
    current_journal_usage=$(journalctl --disk-usage 2>/dev/null || echo "Unknown disk usage")
    echo -e "  ${CYAN}[TREND] Current Journal Consumption:${RESET} ${BOLD}${current_journal_usage}${RESET}"
    echo "[$(date -Iseconds)] [JOURNAL-TREND] Pre-vacuum disk usage: ${current_journal_usage}" >> "$LOG_FILE"

    local journal_target="/var/log/journal"
    [[ ! -d "$journal_target" ]] && journal_target="/run/log/journal"

    if [[ -d "$journal_target" ]]; then
        print_progress "Vacuuming systemd journal logs to retain 2 weeks..."
        if [[ "$DRY_RUN" = true ]]; then
            print_info "[DRY-RUN] Would vacuum journal to 2 weeks."
        else
            local freed_journal=0
            if freed_journal=$(track_directory_cleanup "$journal_target" vacuum_journal); then
                JOURNAL_FREED=$(( JOURNAL_FREED + freed_journal ))
                print_success "Systemd journal vacuumed (Freed: $(format_bytes "$freed_journal"))."
            else
                print_error "Failed to vacuum systemd journal logs."
            fi
        fi
    fi
}

purge_coredumps() {
    local c_dir="${1:?Coredump dir missing}"
    safe_empty_directory "$c_dir"
}

run_coredump_cleanup() {
    print_progress "Inspecting systemd core dumps in /var/lib/systemd/coredump/..."
    local coredump_dir="/var/lib/systemd/coredump"
    if [[ -d "$coredump_dir" ]]; then
        if [[ "$SAFE_MODE" = true ]]; then
            print_info "[SAFE-MODE] Core dump deletion skipped in Safe Mode."
        else
            local freed_coredump=0
            if freed_coredump=$(track_directory_cleanup "$coredump_dir" purge_coredumps "$coredump_dir"); then
                COREDUMPS_FREED=$(( COREDUMPS_FREED + freed_coredump ))
                print_success "Core dumps purged (Freed: $(format_bytes "$freed_coredump"))."
            else
                print_error "Failed to purge core dumps."
            fi
        fi
    fi
}

purge_baloo_index() {
    if [[ -n "$BALOO_BIN" ]]; then
        run_as_target_user "$BALOO_BIN" purge
    fi
}

clean_kdenlive_proxy() {
    local dir="${1:?Directory missing}"
    safe_empty_directory "$dir"
}

clean_kdenlive_cache() {
    local dir="${1:?Directory missing}"
    safe_empty_directory "$dir"
}

clean_thumbnail_cache() {
    local dir="${1:?Directory missing}"
    safe_empty_directory "$dir"
}

run_kde_cleanup() {
    print_progress "Inspecting KDE Baloo file indexer..."
    local baloo_dir="$TARGET_HOME/.local/share/baloo"
    local kde_step_freed=0
    local baloo_size_bytes=0
    local frag_count=0
    local baloo_fragmented=false
    local baloo_bloated=false
    local baloo_corrupted=false

    if [[ -d "$baloo_dir" ]]; then
        frag_count=$(find "$baloo_dir" -maxdepth 1 -type f -name "index-*" 2>/dev/null | wc -l || echo 0)
        baloo_size_bytes=$(get_dir_size_bytes "$baloo_dir")
        echo -e "  ${CYAN}[BALOO-METRICS]${RESET} Split index-* files: ${BOLD}${frag_count}${RESET} (Size: $(format_bytes "$baloo_size_bytes"))"
        echo "[$(date -Iseconds)] [BALOO-METRICS] Split index files: ${frag_count}, Size: ${baloo_size_bytes}B" >> "$LOG_FILE"

        if (( frag_count > 20 )); then
            baloo_fragmented=true
            print_warning "Baloo index exhibits severe LMDB fragmentation (${frag_count} split index-* files detected)."
        fi
    fi

    if [[ -n "$BALOO_BIN" ]]; then
        local baloo_status=""
        baloo_status=$(run_as_target_user "$BALOO_BIN" status 2>&1 || true)

        if (( baloo_size_bytes > 524288000 )); then
            baloo_bloated=true
        fi

        if echo "$baloo_status" | grep -Ei "corrupt|corruption|unable to open|database error|failed to open" >/dev/null 2>&1; then
            baloo_corrupted=true
        fi

        if [[ "$baloo_bloated" = true || "$baloo_corrupted" = true || "$baloo_fragmented" = true ]]; then
            print_warning "Baloo index reset required (Bloated: ${baloo_bloated}, Corrupt: ${baloo_corrupted}, Fragmented: ${baloo_fragmented})."
            if [[ "$DRY_RUN" = true ]]; then
                print_info "[DRY-RUN] Would suspend, purge, and restart Baloo indexer."
            elif [[ "$SAFE_MODE" = true ]]; then
                print_info "[SAFE-MODE] Baloo index purge skipped in Safe Mode."
            else
                run_as_target_user "$BALOO_BIN" suspend || true
                local f_baloo=0
                if f_baloo=$(track_directory_cleanup "$baloo_dir" purge_baloo_index); then
                    kde_step_freed=$(( kde_step_freed + f_baloo ))
                    print_success "KDE Baloo indexer purged and rebuilt."
                else
                    print_error "Failed to purge KDE Baloo index."
                fi
                run_as_target_user "$BALOO_BIN" check || true
            fi
        else
            print_info "KDE Baloo index is healthy ($(format_bytes "$baloo_size_bytes")). Purge skipped."
        fi
    else
        print_info "Baloo control utility not found. Skipping Baloo check."
    fi

    # Kdenlive & Thumbnail Caches
    print_progress "Inspecting Kdenlive proxy and thumbnail caches..."
    local kdenlive_proxy="$TARGET_HOME/.local/share/kdenlive/proxy"
    local kdenlive_cache="$TARGET_HOME/.cache/kdenlive"
    local thumbnails_dir="$TARGET_HOME/.cache/thumbnails"

    if [[ "$SAFE_MODE" = true ]]; then
        print_info "[SAFE-MODE] Kdenlive and thumbnail cache deletions skipped in Safe Mode."
    else
        if [[ -d "$kdenlive_proxy" ]]; then
            local f_kproxy=0
            if f_kproxy=$(track_directory_cleanup "$kdenlive_proxy" clean_kdenlive_proxy "$kdenlive_proxy"); then
                kde_step_freed=$(( kde_step_freed + f_kproxy ))
            else
                print_error "Failed to empty Kdenlive proxy directory."
            fi
        fi
        if [[ -d "$kdenlive_cache" ]]; then
            local f_kcache=0
            if f_kcache=$(track_directory_cleanup "$kdenlive_cache" clean_kdenlive_cache "$kdenlive_cache"); then
                kde_step_freed=$(( kde_step_freed + f_kcache ))
            else
                print_error "Failed to empty Kdenlive cache directory."
            fi
        fi
        if [[ -d "$thumbnails_dir" ]]; then
            local f_thumb=0
            if f_thumb=$(track_directory_cleanup "$thumbnails_dir" clean_thumbnail_cache "$thumbnails_dir"); then
                kde_step_freed=$(( kde_step_freed + f_thumb ))
            else
                print_error "Failed to empty thumbnails cache directory."
            fi
        fi
    fi

    KDE_CACHES_FREED=$(( KDE_CACHES_FREED + kde_step_freed ))
    print_success "KDE and application scratch caches processed (Freed: $(format_bytes "$kde_step_freed"))."

    # Broken symlinks
    print_progress "Scanning for broken symbolic links in ~/.config and ~/.local..."
    local broken_links=()
    while IFS= read -r -d '' link; do
        broken_links+=("$link")
    done < <(find "$TARGET_HOME/.config" "$TARGET_HOME/.local" \
        \( -path "$TARGET_HOME/.local/share/Steam" \
           -o -path "$TARGET_HOME/.local/share/umu" \
           -o -path "$TARGET_HOME/.local/share/lutris" \
           -o -path "$TARGET_HOME/.local/share/Trash" \
           -o -path "$TARGET_HOME/.local/share/containers" \
           -o -path "$TARGET_HOME/.local/share/flatpak" \
           -o -path "$TARGET_HOME/.local/share/docker" \) -prune \
        -o -xtype l ! -name "Singleton*" ! -name "lock" -print0 2>/dev/null || true)

    if [[ ${#broken_links[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Identified ${#broken_links[@]} broken symlink(s):${RESET}"
        for b_link in "${broken_links[@]}"; do
            if [[ "$DRY_RUN" = true ]]; then
                echo -e "  ${CYAN}[DRY-RUN]${RESET} Would remove: $b_link"
            elif [[ "$SAFE_MODE" = true ]]; then
                echo -e "  ${YELLOW}[SAFE-MODE]${RESET} Symlink removal skipped: $b_link"
            else
                echo -e "  ${RED}✗${RESET} Removing: $b_link"
                safe_rm_rf "$b_link"
            fi
        done
        print_success "Broken symlinks processed."
    else
        print_info "No broken symlinks found."
    fi
}

run_btrfs_maintenance() {
    print_progress "Checking root filesystem type for Btrfs maintenance..."
    local root_fs
    root_fs=$(stat -f -c %T / 2>/dev/null || true)
    if [[ "$root_fs" == "btrfs" ]]; then
        print_progress "Initiating lightweight foreground Btrfs scrub on / (btrfs scrub start -Bd /)..."
        if [[ "$DRY_RUN" = true ]]; then
            print_info "[DRY-RUN] Would run: btrfs scrub start -Bd /"
        else
            if btrfs scrub start -Bd /; then
                print_success "Btrfs scrub on / completed."
            else
                print_warning "Btrfs scrub finished with warnings or was already running."
            fi
        fi
    else
        print_info "Root filesystem is ${root_fs:-non-btrfs}. Skipping btrfs scrub."
    fi

    print_progress "Triggering filesystem TRIM across mounted SSDs (fstrim -av)..."
    if [[ "$DRY_RUN" = true ]]; then
        print_info "[DRY-RUN] Would run: fstrim -av"
    else
        if command -v fstrim >/dev/null 2>&1; then
            if fstrim -av; then
                print_success "Filesystem TRIM completed."
            else
                print_warning "fstrim finished with non-fatal device warnings."
            fi
        fi
    fi
}

run_pacnew_scan() {
    print_progress "Scanning /etc for .pacnew and .pacsave files..."
    local pacfiles
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
}

# Execute Step 3
print_step "3/5" "Advanced Deep Maintenance"
run_journal_maintenance
run_coredump_cleanup

if [[ "${MODULES[kde]}" = true ]]; then
    run_kde_cleanup
else
    print_info "Module 'KDE cleanup' skipped."
fi

if [[ "${MODULES[btrfs]}" = true ]]; then
    run_btrfs_maintenance
else
    print_info "Module 'Btrfs scrub & SSD TRIM' skipped."
fi

run_pacnew_scan

# ==============================================================================
# STEP 4: MULTI-DRIVE STEAM ORPHAN SWEEPER
# ==============================================================================
delete_steam_dir() {
    local target="${1:?Target path missing}"
    safe_rm_rf "$target"
}

run_steam_cleanup() {
    local steam_vdf="$TARGET_HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
    if [[ ! -f "$steam_vdf" ]]; then
        if [[ -f "$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf" ]]; then
            steam_vdf="$TARGET_HOME/.steam/steam/steamapps/libraryfolders.vdf"
        fi
    fi

    if [[ ! -f "$steam_vdf" ]]; then
        print_warning "Steam library manifest not found at: $steam_vdf"
        print_info "Skipping Steam orphan sweep."
        return 0
    fi

    print_progress "Parsing Steam library paths from: $steam_vdf (robust sed/awk)..."

    local active_libraries=()
    local lib_path clean_path
    while IFS= read -r lib_path; do
        clean_path="${lib_path//\\\\//}"
        clean_path="${clean_path%/}"
        if [[ -n "$clean_path" && -d "$clean_path" ]]; then
            active_libraries+=("$clean_path")
        elif [[ -n "$clean_path" ]]; then
            print_warning "Configured Steam library currently unmounted or inaccessible: '$clean_path'."
        fi
    done < <(sed -n -E 's/.*"path"[[:space:]]+"([^"]+)".*/\1/p' "$steam_vdf" || true)

    local default_steam_path="$TARGET_HOME/.local/share/Steam"
    if [[ -d "$default_steam_path" ]]; then
        local is_present=false
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

    if [[ ${#active_libraries[@]} -eq 0 ]]; then
        print_warning "No accessible Steam libraries found. Aborting Steam orphan sweep to prevent false deletions."
        return 0
    fi

    echo -e "${CYAN}Discovered accessible Steam libraries:${RESET}"
    for lib in "${active_libraries[@]}"; do
        echo -e "  - ${WHITE}$lib${RESET}"
    done

    # Steam Shadercache Metrics
    print_progress "Evaluating Steam shadercache metrics across discovered libraries..."
    local candidate_shader shader_size_human
    for lib in "${active_libraries[@]}"; do
        candidate_shader="$lib/steamapps/shadercache"
        [[ ! -d "$candidate_shader" && -d "$lib/shadercache" ]] && candidate_shader="$lib/shadercache"
        if [[ -d "$candidate_shader" ]]; then
            shader_size_human=$(du -sh -- "$candidate_shader" 2>/dev/null | awk '{print $1}' || echo "0B")
            echo -e "  ${CYAN}[PERF-TUNING] Shader Cache at ${lib}:${RESET} ${BOLD}${shader_size_human}${RESET}"
            echo "[$(date -Iseconds)] [STEAM-PERF] Shadercache at ${candidate_shader}: ${shader_size_human}" >> "$LOG_FILE"
        fi
    done

    # Index installed AppIDs across manifests
    print_progress "Indexing installed game manifests (appmanifest_<AppID>.acf)..."
    declare -A installed_appids=()
    local installed_count=0
    local manifest_dirs=()

    for lib in "${active_libraries[@]}"; do
        manifest_dirs=()
        [[ -d "$lib/steamapps" ]] && manifest_dirs+=("$lib/steamapps")
        [[ -d "$lib" ]] && manifest_dirs+=("$lib")

        for m_dir in "${manifest_dirs[@]}"; do
            for manifest_file in "$m_dir"/appmanifest_*.acf; do
                if [[ -f "$manifest_file" ]]; then
                    local base_name
                    base_name=$(basename -- "$manifest_file")
                    if [[ "$base_name" =~ ^appmanifest_([0-9]+)\.acf$ ]]; then
                        local appid="${BASH_REMATCH[1]}"
                        if [[ -z "${installed_appids[$appid]:-}" ]]; then
                            installed_appids["$appid"]=1
                            ((installed_count++)) || true
                        fi
                    fi
                fi
            done
        done
    done

    # Fail-safe: If 0 manifests indexed, prevent false orphan wipes
    if (( installed_count == 0 )); then
        print_warning "Zero installed Steam games indexed. Aborting orphan purge to protect valid library data."
        return 0
    fi

    print_info "Indexed ${BOLD}${installed_count}${RESET} installed game AppID(s)."

    # Scan shader caches (safe to delete) and compatdata (report candidates, do NOT delete)
    print_progress "Scanning for abandoned prefixes and shader caches..."
    local removed_shader_count=0
    local steam_step_freed=0
    local compatdata_candidates=0

    for lib in "${active_libraries[@]}"; do
        # 1. Inspect shadercache (Safe for automated deletion)
        local shader_dirs=()
        [[ -d "$lib/steamapps/shadercache" ]] && shader_dirs+=("$lib/steamapps/shadercache")
        [[ -d "$lib/shadercache" && "$lib/shadercache" != "$lib/steamapps/shadercache" ]] && shader_dirs+=("$lib/shadercache")

        for s_dir in "${shader_dirs[@]}"; do
            for entry in "$s_dir"/*; do
                if [[ -d "$entry" ]]; then
                    local entry_name
                    entry_name=$(basename -- "$entry")
                    if [[ "$entry_name" =~ ^[0-9]+$ ]]; then
                        if [[ -z "${installed_appids[$entry_name]:-}" ]]; then
                            local folder_freed=0
                            if folder_freed=$(track_directory_cleanup "$entry" delete_steam_dir "$entry"); then
                                steam_step_freed=$(( steam_step_freed + folder_freed ))
                                if [[ "$DRY_RUN" = true ]]; then
                                    echo -e "  ${CYAN}[DRY-RUN]${RESET} Would remove orphaned shadercache: AppID ${BOLD}${RED}${entry_name}${RESET} [Reclaimable: $(format_bytes "$folder_freed")]"
                                elif [[ "$SAFE_MODE" = true ]]; then
                                    echo -e "  ${YELLOW}[SAFE-MODE]${RESET} Orphaned shadercache detected; deletion skipped: AppID ${BOLD}${entry_name}${RESET}"
                                else
                                    echo -e "  ${YELLOW}• Removed orphan shadercache:${RESET} AppID ${BOLD}${RED}${entry_name}${RESET} [Path: ${entry}] [Freed: $(format_bytes "$folder_freed")]"
                                fi
                                ((removed_shader_count++)) || true
                            else
                                print_error "Failed to remove orphaned shadercache directory: $entry"
                            fi
                        fi
                    fi
                fi
            done
        done

        # 2. Inspect compatdata (Report only - never automatically delete save data)
        local compat_dirs=()
        [[ -d "$lib/steamapps/compatdata" ]] && compat_dirs+=("$lib/steamapps/compatdata")
        [[ -d "$lib/compatdata" && "$lib/compatdata" != "$lib/steamapps/compatdata" ]] && compat_dirs+=("$lib/compatdata")

        for c_dir in "${compat_dirs[@]}"; do
            for entry in "$c_dir"/*; do
                if [[ -d "$entry" ]]; then
                    local entry_name
                    entry_name=$(basename -- "$entry")
                    if [[ "$entry_name" =~ ^[0-9]+$ ]]; then
                        if [[ -z "${installed_appids[$entry_name]:-}" ]]; then
                            local compat_size
                            compat_size=$(format_bytes "$(get_dir_size_bytes "$entry")")
                            echo -e "  ${YELLOW}[CANDIDATE]${RESET} Uninstalled game prefix retained: AppID ${BOLD}${entry_name}${RESET} (${compat_size}) at ${entry}"
                            echo -e "    ${CYAN}ℹ Notice:${RESET} compatdata contains user saves and Wine configuration; deletion skipped for safety."
                            echo "[$(date -Iseconds)] [STEAM-COMPATDATA-RETAINED] AppID: ${entry_name}, Size: ${compat_size}, Path: ${entry}" >> "$LOG_FILE"
                            ((compatdata_candidates++)) || true
                        fi
                    fi
                fi
            done
        done
    done

    STEAM_ORPHANS_FREED=$(( STEAM_ORPHANS_FREED + steam_step_freed ))

    if [[ $removed_shader_count -gt 0 ]]; then
        print_success "Processed ${removed_shader_count} orphaned shadercache folder(s) (Freed: $(format_bytes "$steam_step_freed"))."
    else
        print_info "No orphaned Steam shader caches found."
    fi

    if [[ $compatdata_candidates -gt 0 ]]; then
        print_info "Identified ${compatdata_candidates} uninstalled compatdata prefix(es); retained safely on disk."
    fi
}

print_step "4/5" "Multi-Drive Steam Orphan Sweeper"
if [[ "${MODULES[steam]}" = true ]]; then
    run_steam_cleanup
else
    print_info "Module 'Steam orphan sweeper' skipped."
fi

# ==============================================================================
# STEP 5: PROTON DRIVE PAYLOAD & FINISH FUNCTIONS
# ==============================================================================
detect_desktop_dir() {
    local xdg_desktop=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        xdg_desktop=$(run_as_target_user xdg-user-dir DESKTOP 2>/dev/null || true)
    fi

    if [[ -n "$xdg_desktop" && -d "$xdg_desktop" ]]; then
        echo "$xdg_desktop"
    elif [[ -d "$TARGET_HOME/Desktop" ]]; then
        echo "$TARGET_HOME/Desktop"
    else
        # Create Desktop directory as the target user to prevent root-owned folders
        run_as_target_user mkdir -p -- "$TARGET_HOME/Desktop" 2>/dev/null || mkdir -p -- "$TARGET_HOME/Desktop"
        chown -- "$TARGET_USER:$TARGET_GROUP" "$TARGET_HOME/Desktop" 2>/dev/null || true
        echo "$TARGET_HOME/Desktop"
    fi
}

run_backup_module() {
    local desktop_dir
    desktop_dir=$(detect_desktop_dir)

    local backup_timestamp
    backup_timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local archive_filename="CachyOS-Config-Backup-${backup_timestamp}.tar.zst"
    local archive_target="${desktop_dir}/${archive_filename}"
    local tmp_archive="${desktop_dir}/.tmp-${archive_filename}.$$"

    print_progress "Assembling selective configuration backup archive..."

    local backup_items=()
    [[ -d "$TARGET_HOME/.config" ]] && backup_items+=(".config")
    [[ -f "$TARGET_HOME/.bashrc" ]] && backup_items+=(".bashrc")
    [[ -f "$TARGET_HOME/.zshrc" ]] && backup_items+=(".zshrc")

    local kde_share_folders=(
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
        return 0
    fi

    print_progress "Archiving items atomically with tar (zstd) -> ${archive_target}..."
    if [[ "$DRY_RUN" = true ]]; then
        print_info "[DRY-RUN] Would create restricted tar.zst archive at: ${archive_target}"
    else
        # Create archive atomically to temporary file first
        local tar_rc=0
        tar --zstd \
            --warning=no-file-changed \
            --ignore-failed-read \
            --exclude=".config/BraveSoftware" \
            --exclude=".config/librewolf" \
            --exclude=".config/mozilla" \
            --exclude=".config/google-chrome" \
            --exclude=".config/chromium" \
            --exclude=".config/vivaldi" \
            --exclude=".config/microsoft-edge" \
            --exclude=".config/opera" \
            --exclude=".config/vesktop" \
            --exclude=".config/discord" \
            --exclude=".config/Antigravity" \
            --exclude=".config/Code" \
            --exclude="*/Singleton*" \
            --exclude="*/lock" \
            --exclude="*/Cache/*" \
            --exclude="*/Code Cache/*" \
            --exclude="*/GPUCache/*" \
            --exclude="*/Cache" \
            --exclude="*/Code Cache" \
            --exclude="*/GPUCache" \
            --exclude="*/cache/*" \
            --exclude="*/proxy/*" \
            -cf "$tmp_archive" \
            -C "$TARGET_HOME" \
            "${backup_items[@]}" || tar_rc=$?

        if (( tar_rc == 0 || tar_rc == 1 )); then
            # Move atomically, set correct group ownership and restrict permissions
            mv -f -- "$tmp_archive" "$archive_target"
            chown -- "$TARGET_USER:$TARGET_GROUP" "$archive_target"
            chmod 600 -- "$archive_target"

            local archive_size
            archive_size=$(du -h -- "$archive_target" 2>/dev/null | cut -f1 || echo "unknown")
            print_success "Configuration archive created: ${archive_target} (${archive_size})"
            echo -e "    ${CYAN}ℹ Permissions:${RESET} Restricted to mode 0600 (owner: ${TARGET_USER}:${TARGET_GROUP})."
        else
            safe_rm_rf "$tmp_archive"
            print_error "Failed to create configuration backup archive."
        fi
    fi
}

print_step "5/5" "Proton Drive Payload & Finish"
if [[ "${MODULES[backup]}" = true ]]; then
    run_backup_module
else
    print_info "Module 'Backup' skipped."
fi

# ==============================================================================
# SUMMARY TABLE & NOTIFICATION
# ==============================================================================
print_summary_table

# Final Banner & Exit Handling
echo -e "${GREEN}${BOLD}==============================================================================${RESET}"
echo -e "${GREEN}${BOLD}             ALL HOUSEKEEPING OPERATIONS COMPLETED!                           ${RESET}"
echo -e "${GREEN}${BOLD}==============================================================================${RESET}"

if [[ "${MODULES[backup]}" = true ]]; then
    echo ""
    echo -e "${CYAN}${BOLD}==> PROTON DRIVE BACKUP ACTION REQUIRED:${RESET}"
    echo -e "    Drag your new configuration archive directly into ${BOLD}Proton Drive${RESET}:"
    echo -e "    ${WHITE}${BOLD}$(detect_desktop_dir)/CachyOS-Config-Backup-*.tar.zst${RESET}"
    echo ""
    echo -e "${GREEN}${BOLD}==============================================================================${RESET}"
fi
echo ""

# Exit with appropriate operational status code
if (( FAILURE_COUNT > 0 )); then
    exit 2
fi
exit 0
