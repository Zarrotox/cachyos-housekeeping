#!/usr/bin/env bash
# ==============================================================================
# Universal Linux Housekeeping - Distro Detection Unit Test
# ==============================================================================
# Validates detect_distribution() against mock /etc/os-release files for all
# 10 target distributions.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../distro/detect.sh"

TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "$TMP_DIR"' EXIT

passed=0
failed=0

run_test() {
    local test_name="$1"
    local os_release_content="$2"
    local expected_id="$3"
    local expected_family="$4"

    local test_file="${TMP_DIR}/os-release.${test_name}"
    echo -e "$os_release_content" > "$test_file"

    detect_distribution "$test_file"

    if [[ "$DETECTED_DISTRO_ID" == "$expected_id" && "$DETECTED_DISTRO_FAMILY" == "$expected_family" ]]; then
        echo "  [PASS] ${test_name}: id=${DETECTED_DISTRO_ID}, family=${DETECTED_DISTRO_FAMILY}"
        passed=$(( passed + 1 ))
    else
        echo "  [FAIL] ${test_name}: expected (${expected_id}, ${expected_family}), got (${DETECTED_DISTRO_ID}, ${DETECTED_DISTRO_FAMILY})" >&2
        failed=$(( failed + 1 ))
    fi
}

echo "Testing detect_distribution() across target distributions:"

# 1. CachyOS
run_test "CachyOS" "NAME=\"CachyOS\"\nID=cachyos\nID_LIKE=arch\nPRETTY_NAME=\"CachyOS\"" "cachyos" "arch"

# 2. Arch Linux
run_test "Arch Linux" "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"" "arch" "arch"

# 3. EndeavourOS
run_test "EndeavourOS" "NAME=\"EndeavourOS\"\nID=endeavouros\nID_LIKE=arch\nPRETTY_NAME=\"EndeavourOS\"" "endeavouros" "arch"

# 4. Nobara
run_test "Nobara" "NAME=\"Nobara Linux\"\nID=nobara\nID_LIKE=\"fedora\"\nVERSION_ID=40" "nobara" "fedora"

# 5. Fedora
run_test "Fedora" "NAME=Fedora\nID=fedora\nVERSION_ID=41\nPRETTY_NAME=\"Fedora Linux 41\"" "fedora" "fedora"

# 6. Ubuntu
run_test "Ubuntu" "NAME=\"Ubuntu\"\nID=ubuntu\nID_LIKE=debian\nVERSION_ID=\"24.04\"" "ubuntu" "debian"

# 7. Linux Mint
run_test "Linux Mint" "NAME=\"Linux Mint\"\nID=linuxmint\nID_LIKE=ubuntu\nVERSION_ID=\"22\"" "linuxmint" "debian"

# 8. Pop!_OS
run_test "Pop!_OS" "NAME=\"Pop!_OS\"\nID=pop\nID_LIKE=\"ubuntu debian\"\nVERSION_ID=\"22.04\"" "pop" "debian"

# 9. Debian
run_test "Debian" "NAME=\"Debian GNU/Linux\"\nID=debian\nVERSION_ID=\"12\"" "debian" "debian"

# 10. openSUSE Tumbleweed
run_test "openSUSE Tumbleweed" "NAME=\"openSUSE Tumbleweed\"\nID=\"opensuse-tumbleweed\"\nID_LIKE=\"opensuse suse\"" "opensuse" "suse"

# 11. openSUSE Leap
run_test "openSUSE Leap" "NAME=\"openSUSE Leap\"\nID=\"opensuse-leap\"\nID_LIKE=\"suse opensuse\"" "opensuse" "suse"

echo "------------------------------------------------------------------"
echo "Tests Passed: ${passed} | Tests Failed: ${failed}"

if (( failed > 0 )); then
    exit 1
fi
