#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping Framework - Driver Harness
# Author: Zarrotox
# Branch: universal-dev (Experimental Phase 2)
# ==============================================================================
# Demonstrates cross-distribution detection, package manager discovery, and
# concrete modular backend execution across Arch, Fedora, Debian, and SUSE.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source abstraction components
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/distro/detect.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/distro/package_manager.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/backends/backend_interface.sh"

# Default runtime options
DRY_RUN="true"
SAFE_MODE="true"
OS_RELEASE_TARGET="/etc/os-release"

show_help() {
    cat << 'EOF'
Universal Linux Housekeeping Framework (Experimental Driver)
Author: Zarrotox | Branch: universal-dev

Usage:
  universal-housekeeping.sh [OPTIONS] [OS_RELEASE_FILE]

Execution Modes:
  --apply, --execute      Execute live changes (disables default Dry-Run simulation)
  --yes, --no-safe-mode   Disable Safe Mode (allows automated deletions without prompts)
  -h, --help              Display this help message and exit

Testing & Overrides:
  OS_RELEASE_FILE         Optional path to mock/alternative os-release file for testing

Examples:
  ./universal-housekeeping.sh                      # Dry-run audit on current host
  ./universal-housekeeping.sh --apply              # Live run with Safe Mode confirmation
  ./universal-housekeeping.sh --apply --yes        # Fully unattended live execution
  ./universal-housekeeping.sh /path/to/os-release  # Test distro detection on mock os-release
EOF
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply|--execute)
            DRY_RUN="false"
            shift
            ;;
        --yes|--no-safe-mode)
            SAFE_MODE="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            echo "Run with --help for usage instructions." >&2
            exit 1
            ;;
        *)
            OS_RELEASE_TARGET="$1"
            shift
            ;;
    esac
done

export DRY_RUN
export SAFE_MODE

# Render stylized ZARROTOX startup banner
print_banner() {
    local bold="\033[1m"
    local cyan="\033[0;36m"
    local yellow="\033[1;33m"
    local blue="\033[0;34m"
    local gray="\033[0;90m"
    local reset="\033[0m"

    echo -e "${cyan}${bold}"
    cat << 'EOF'
███████╗ █████╗ ██████╗ ██████╗  ██████╗ ████████╗ ██████╗ ██╗  ██╗
╚══███╔╝██╔══██╗██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔═══██╗╚██╗██╔╝
  ███╔╝ ███████║██████╔╝██████╔╝██║   ██║   ██║   ██║   ██║ ╚███╔╝ 
 ███╔╝  ██╔══██║██╔══██╗██╔══██╗██║   ██║   ██║   ██║   ██║ ██╔██╗ 
███████╗██║  ██║██║  ██║██║  ██║╚██████╔╝   ██║   ╚██████╔╝██╔╝ ██╗
╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝
EOF
    echo -e "${reset}"
    echo -e "                 ${bold}${yellow}UNIVERSAL LINUX HOUSEKEEPING${reset}"
    echo -e "               ${blue}Linux Housekeeping Framework (Experimental)${reset}"
    echo -e "                       ${bold}Author: ${reset}Zarrotox"
    echo -e "                   ${gray}Branch: universal-dev | Phase 2${reset}\n"
}

print_banner

# Display active runtime configuration
echo "Active Mode Configuration:"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  - Execution Mode: DRY-RUN (Simulation only, no live changes)"
else
    echo "  - Execution Mode: LIVE EXECUTION (--apply active)"
fi

if [[ "$SAFE_MODE" == "true" ]]; then
    echo "  - Safety Filter:  SAFE-MODE ENABLED (Deletions require confirmation)"
else
    echo "  - Safety Filter:  UNATTENDED (--yes active, deletions authorized)"
fi
echo ""

# 1. Distribution Detection
echo -e "[1/3] Detecting Host Operating System..."
detect_distribution "$OS_RELEASE_TARGET"
print_distro_info

# 2. Package Manager Detection
echo -e "\n[2/3] Detecting Package Managers & Runtimes..."
detect_package_manager "$DETECTED_DISTRO_FAMILY" || echo "[INFO] Simulating package manager on test host."
print_package_manager_info

# Export companion runtime status for backends
FLATPAK_SUPPORT="${HAS_FLATPAK:-false}"
SNAP_SUPPORT="${HAS_SNAP:-false}"
export FLATPAK_SUPPORT
export SNAP_SUPPORT

# 3. Backend Initialization & Execution
echo -e "\n[3/3] Initializing Distribution Backend..."
init_package_backend "$DETECTED_DISTRO_FAMILY"
echo "Active Backend: ${CURRENT_BACKEND}"

echo -e "\nExecuting Backend Lifecycle Hooks:"
package_update_metadata
package_remove_orphans
package_clean_cache
package_scan_config_diffs

echo -e "\nUniversal Framework execution completed successfully."
