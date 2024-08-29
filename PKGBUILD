pkgname=yubikey-challenge-response-disk-encryption
pkgver=r25.c2c3597
pkgrel=1
plgdesc='Package to enroll and unlock LUKS containers with yubikey challenge-response system where challenge compromises of user password and UUID of partition'
arch=('any')
license=('GPL')
depends=('bash' 'yubikey-personalization' 'util-linux' 'coreutils' 'expect' 'gawk')
url='https://github.com/peto59/yubikey-challenge-response-disk-encryption'
backup=('etc/ykchrde.conf')
source=('git+https://github.com/peto59/yubikey-challange-response-disk-encryption.git')
sha256sums=('SKIP')

pkgver() {
  printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}


package() {
    install -Dm644 "$srcdir/ykchrde.conf" "$pkgdir/etc/ykchrde.conf"

    install -Dm755 "$srcdir/ykchrde.sh" "$pkgdir/usr/bin/ykchrde.sh"

    install -Dm644 "$srcdir/hooks/ykchrde" "$pkgdir/usr/lib/initcpio/hooks/ykchrde"

    install -Dm644 "$srcdir/install/ykchrde" "$pkgdir/usr/lib/initcpio/install/ykchrde"
    install -Dm644 "$srcdir/install/sd-ykchrde" "$pkgdir/usr/lib/initcpio/install/sd-ykchrde"
}
