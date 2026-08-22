# Maintainer: seekerkrt
pkgname=dotfiles-doctor
pkgver=0.1.0
pkgrel=1
pkgdesc='Read-only diagnostic CLI for dotfiles trees'
arch=('x86_64')
url='https://github.com/seekerkrt/dotfiles-doctor'
license=('GPL-3.0-or-later')
depends=('glibc' 'libgcc' 'libstdc++')
makedepends=('cmake')

_commit=da5569dd7944f2d81c67f32f490e290120e023c1
_srcdir="$pkgname-$_commit"

source=("$pkgname-$_commit.tar.gz::$url/archive/$_commit.tar.gz")
sha256sums=('96705260c4b39aa3b3f4a82a79635a4762e9d50a320bbff70e28a4177cf76016')

build() {
    cmake \
        -B build \
        -S "$_srcdir" \
        -DCMAKE_BUILD_TYPE=None \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_TESTING=ON

    cmake --build build
}

check() {
    ctest \
        --test-dir build \
        --output-on-failure
}

package() {
    DESTDIR="$pkgdir" cmake --install build
}
