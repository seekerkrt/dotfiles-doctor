# Maintainer: seekerkrt
pkgname=dotfiles-doctor
_srcname=dotfiles-doctor-src

# pkgver selects the upstream release tag to package.
# pkgver() verifies that the checked-out release carries the same VERSION.
pkgver=0.2.0
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

# Verify that the checked-out release matches the package version.
pkgver() {
    local version

    version=$(tr -d '[:space:]' < "$srcdir/$_srcname/VERSION")

    if [[ "$version" != "$pkgver" ]]; then
        printf 'error: PKGBUILD pkgver (%s) does not match upstream VERSION (%s)\n' \
            "$pkgver" "$version" >&2
        return 1
    fi

    printf '%s\n' "$version"
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
