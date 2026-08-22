# Maintainer: seekerkrt
pkgname=dotfiles-doctor
_srcname=dotfiles-doctor-src

# The repository root VERSION file is the single authority for the version.
# This PKGBUILD sits next to it, so read it directly.
pkgver=$(tr -d '[:space:]' < "$startdir/VERSION")
pkgrel=1
pkgdesc='Read-only diagnostic CLI for dotfiles trees'
arch=('x86_64')
url='https://github.com/seekerkrt/dotfiles-doctor'
license=('GPL-3.0-or-later')
depends=('glibc' 'libgcc' 'libstdc++')
makedepends=('cmake' 'git')

# Build from the upstream release tag, not from the local working tree.
source=("$_srcname::git+$url.git#tag=v$pkgver")
sha256sums=('SKIP')

# The checked out tag carries its own VERSION file, which stays authoritative.
pkgver() {
    tr -d '[:space:]' < "$srcdir/$_srcname/VERSION"
}

build() {
    cmake \
        -B build \
        -S "$_srcname" \
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
