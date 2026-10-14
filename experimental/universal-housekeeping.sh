#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Experimental Driver Harness
# Part of Experimental Phase 1: Distro Abstraction Framework
# ==============================================================================
# Demonstrates the integration of distribution detection, package manager
# discovery, and modular backend dispatching.
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

echo "=================================================================="
echo " Universal Linux Housekeeping Suite (Experimental Architecture)  "
echo "=================================================================="

# 1. Distribution Detection
echo -e "\n[1/3] Detecting Host Operating System..."
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
