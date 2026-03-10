# Maintainer: Roberto Gogoni <your-email@example.com>
# Contributor: Roberto Gogoni <your-email@example.com>

pkgname=update-beeper
pkgver=1.8.0
pkgrel=1
pkgdesc="Self-healing Beeper Desktop updater for Arch Linux with automatic rollback"
arch=('any')
url="https://github.com/robertogogoni/update-beeper"
license=('MIT')
depends=('bash' 'curl' 'coreutils')
optdepends=(
    'libnotify: for desktop notifications'
    'beeper-v4-bin: Beeper Desktop from AUR'
)
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/robertogogoni/${pkgname}/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('SKIP')  # Update this after creating the release

package() {
    cd "${pkgname}-${pkgver}"

    # Install scripts
    install -Dm755 update-beeper "${pkgdir}/usr/bin/update-beeper"
    install -Dm755 beeper-version "${pkgdir}/usr/bin/beeper-version"
    install -Dm755 beeper-health "${pkgdir}/usr/bin/beeper-health"

    # Install systemd user units
    install -Dm644 systemd/update-beeper-user.service "${pkgdir}/usr/lib/systemd/user/update-beeper.service"
    install -Dm644 systemd/update-beeper-user.timer "${pkgdir}/usr/lib/systemd/user/update-beeper.timer"

    # Install license
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"

    # Install documentation
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    install -Dm644 CHANGELOG.md "${pkgdir}/usr/share/doc/${pkgname}/CHANGELOG.md"
}
