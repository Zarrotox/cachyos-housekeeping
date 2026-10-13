# Maintainer: Zarrotox <zarrotox at users.noreply.github.com>
pkgname=cachyos-housekeeping
pkgver=2026.10.15
pkgrel=1
pkgdesc="Comprehensive sysadmin-grade housekeeping, optimization, and backup suite for CachyOS / KDE Plasma"
arch=('any')
url="https://github.com/Zarrotox/cachyos-housekeeping"
license=('MIT')
depends=(
    'bash'
    'coreutils'
    'findutils'
    'gawk'
    'grep'
    'pacman-contrib'
    'sed'
    'tar'
    'util-linux'
    'zstd'
)
optdepends=(
    'gum: modern interactive module selection and prompts'
    'whiptail: standard dialog-based interactive module selection fallback'
    'timeshift: automated system safety snapshots before maintenance'
    'flatpak: cleanup of unused Flatpak runtimes'
    'paru: automated build cache pruning for paru AUR helper'
    'yay: automated build cache pruning for yay AUR helper'
    'baloo: KDE Plasma file indexer health check and maintenance'
    'libnotify: native KDE desktop notifications via notify-send'
    'btrfs-progs: filesystem scrub and Btrfs maintenance'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "${srcdir}/${pkgname}-${pkgver}" 2>/dev/null || cd "${srcdir}"

    # Main binary
    install -Dm755 cachyos-housekeeping.sh "${pkgdir}/usr/bin/cachyos-housekeeping"

    # Command alias symlink
    ln -sf cachyos-housekeeping "${pkgdir}/usr/bin/cachy-clean"

    # License and documentation
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    install -Dm644 CHANGELOG.md "${pkgdir}/usr/share/doc/${pkgname}/CHANGELOG.md"
}
