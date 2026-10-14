#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Distribution Detection Engine
# Part of Experimental Phase 1: Distro Abstraction Framework
# ==============================================================================
# Detects and classifies the host distribution using /etc/os-release standard.
# Supported Classifications:
#   - Arch Family:   cachyos, arch, endeavouros
#   - Fedora Family: nobara, fedora
#   - Debian Family: ubuntu, linuxmint, pop, debian
#   - SUSE Family:   opensuse (tumbleweed / leap)
# ==============================================================================

# Global detection state
DETECTED_DISTRO_ID=""
DETECTED_DISTRO_NAME=""
DETECTED_DISTRO_FAMILY=""
DETECTED_DISTRO_VERSION=""
DETECTED_DISTRO_ID_LIKE=""

detect_distribution() {
    local os_release_file="${1:-/etc/os-release}"
    local fallback_os_release="/usr/lib/os-release"

    # Reset detection variables
    DETECTED_DISTRO_ID="unknown"
    DETECTED_DISTRO_NAME="Unknown Linux"
    DETECTED_DISTRO_FAMILY="unknown"
    DETECTED_DISTRO_VERSION=""
    DETECTED_DISTRO_ID_LIKE=""

    # Locate valid os-release file
    if [[ ! -f "$os_release_file" ]]; then
        if [[ -f "$fallback_os_release" ]]; then
            os_release_file="$fallback_os_release"
        else
            echo "[WARN] Neither /etc/os-release nor /usr/lib/os-release found." >&2
            return 1
        fi
    fi

    # Parse key-value pairs safely without arbitrary code execution
    local raw_id="" raw_name="" raw_id_like="" raw_version=""
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        # Ignore comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Strip surrounding whitespace and quotes
        key=$(echo "$key" | tr -d '[:space:]')
        val=$(echo "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')

        case "$key" in
            ID)           raw_id=$(echo "$val" | tr '[:upper:]' '[:lower:]') ;;
            NAME)         raw_name="$val" ;;
            ID_LIKE)      raw_id_like=$(echo "$val" | tr '[:upper:]' '[:lower:]') ;;
            VERSION_ID)   raw_version="$val" ;;
        esac
    done < "$os_release_file"

    DETECTED_DISTRO_NAME="${raw_name:-Unknown Linux}"
    DETECTED_DISTRO_VERSION="${raw_version:-rolling}"
    DETECTED_DISTRO_ID_LIKE="$raw_id_like"

    # Distro classification logic (order matters: derivative distros precede parent bases)
    case "$raw_id" in
        cachyos)
            DETECTED_DISTRO_ID="cachyos"
            DETECTED_DISTRO_FAMILY="arch"
            ;;
        endeavouros)
            DETECTED_DISTRO_ID="endeavouros"
            DETECTED_DISTRO_FAMILY="arch"
            ;;
        arch)
            DETECTED_DISTRO_ID="arch"
            DETECTED_DISTRO_FAMILY="arch"
            ;;
        nobara)
            DETECTED_DISTRO_ID="nobara"
            DETECTED_DISTRO_FAMILY="fedora"
            ;;
        fedora)
            DETECTED_DISTRO_ID="fedora"
            DETECTED_DISTRO_FAMILY="fedora"
            ;;
        linuxmint)
            DETECTED_DISTRO_ID="linuxmint"
            DETECTED_DISTRO_FAMILY="debian"
            ;;
        pop)
            DETECTED_DISTRO_ID="pop"
            DETECTED_DISTRO_FAMILY="debian"
            ;;
        ubuntu)
            DETECTED_DISTRO_ID="ubuntu"
            DETECTED_DISTRO_FAMILY="debian"
            ;;
        debian)
            DETECTED_DISTRO_ID="debian"
            DETECTED_DISTRO_FAMILY="debian"
            ;;
        opensuse*|suse|sles)
            DETECTED_DISTRO_ID="opensuse"
            DETECTED_DISTRO_FAMILY="suse"
            ;;
        *)
            # Fallback to ID_LIKE inspection for derivatives
            if [[ "$raw_id_like" =~ (arch|cachyos) ]]; then
                DETECTED_DISTRO_ID="${raw_id:-arch-derivative}"
                DETECTED_DISTRO_FAMILY="arch"
            elif [[ "$raw_id_like" =~ (fedora|rhel|centos) ]]; then
                DETECTED_DISTRO_ID="${raw_id:-fedora-derivative}"
                DETECTED_DISTRO_FAMILY="fedora"
            elif [[ "$raw_id_like" =~ (debian|ubuntu) ]]; then
                DETECTED_DISTRO_ID="${raw_id:-debian-derivative}"
                DETECTED_DISTRO_FAMILY="debian"
            elif [[ "$raw_id_like" =~ (suse|opensuse) ]]; then
                DETECTED_DISTRO_ID="${raw_id:-suse-derivative}"
                DETECTED_DISTRO_FAMILY="suse"
            else
                DETECTED_DISTRO_ID="${raw_id:-unknown}"
                DETECTED_DISTRO_FAMILY="unknown"
            fi
            ;;
    esac

    return 0
}

# Helper interrogation predicates
is_distro_family() {
    local target_family="${1:?Target family required}"
    [[ "$DETECTED_DISTRO_FAMILY" == "$target_family" ]]
}

is_distro() {
    local target_distro="${1:?Target distro ID required}"
    [[ "$DETECTED_DISTRO_ID" == "$target_distro" ]]
}

print_distro_info() {
    echo "Distribution ID:     ${DETECTED_DISTRO_ID}"
    echo "Distribution Name:   ${DETECTED_DISTRO_NAME}"
    echo "Distribution Family: ${DETECTED_DISTRO_FAMILY}"
    echo "Version ID:          ${DETECTED_DISTRO_VERSION}"
    echo "ID_LIKE Hierarchy:   ${DETECTED_DISTRO_ID_LIKE:-<none>}"
}
