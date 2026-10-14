#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping Framework - Driver Harness
# Author: Zarrotox
# Branch: universal-dev (Experimental)
# ==============================================================================
# Demonstrates cross-distribution detection, package manager discovery, and
# modular backend dispatching under the unified ZARROTOX branding.
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
    echo -e "                   ${gray}Branch: universal-dev | Phase 1${reset}\n"
}

print_banner

# 1. Distribution Detection
echo -e "[1/3] Detecting Host Operating System..."
detect_distribution "${1:-/etc/os-release}"
print_distro_info

# 2. Package Manager Detection
echo -e "\n[2/3] Detecting Package Managers & Runtimes..."
detect_package_manager "$DETECTED_DISTRO_FAMILY" || echo "[INFO] Simulating package manager on test host."
print_package_manager_info

# 3. Backend Initialization & Demonstration
echo -e "\n[3/3] Initializing Distribution Backend..."
init_package_backend "$DETECTED_DISTRO_FAMILY"
echo "Active Backend: ${CURRENT_BACKEND}"

echo -e "\nTesting Backend Hooks (Dry-Run Mode):"
DRY_RUN=true
export DRY_RUN

package_update_metadata
package_remove_orphans
package_clean_cache
package_scan_config_diffs

echo -e "\nUniversal Framework initialization completed successfully."
