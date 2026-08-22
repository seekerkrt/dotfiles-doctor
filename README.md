# Dotfiles Doctor

日本語: [README.ja.md](README.ja.md)

Dotfiles Doctor is a small, read-only diagnostic CLI for dotfiles trees.
The command is `dotdoc`.

## Overview

`dotdoc` scans a dotfiles tree, reports the problems it finds, and does not
modify the scanned files.

GNU Stow managed environments are a primary target, but Dotfiles Doctor is
not a GNU Stow-only tool. It is also not a dotfiles manager or deployer: it
tells you what looks wrong and leaves the fix to you.

## Status

Early development. This source tree reports version `0.1.0`.

Available today:

- Broken symbolic link detection
- `-h` / `--help`
- `--version`

Further diagnostics are planned; the roadmap lives in the GitHub issues
linked below.

## Usage

```text
dotdoc [OPTIONS] [PATH]
```

- `dotdoc` — scan `$HOME/dotfiles`
- `dotdoc PATH` — scan only the given directory
- `dotdoc -h`, `dotdoc --help` — show usage and exit
- `dotdoc --version` — show version information and exit

`--help` and `--version` are handled before `$HOME` and the scan root are
inspected, so they work even when neither is usable.

## Output

Findings are written to standard output, one line per broken symbolic link,
sorted by path. Each line shows the path relative to the scan root followed
by the raw symbolic link target.

```console
$ dotdoc ~/dotfiles
BROKEN: "nvim/init.lua" -> "../missing/init.lua"
BROKEN: "zshrc" -> "/home/example/does-not-exist/zshrc"
```

When nothing is found:

```console
$ dotdoc ~/dotfiles
OK: no broken symlinks found.
```

Invocation and filesystem errors are written to standard error.

## Exit status

- `0` — the scan completed and found nothing
- `1` — the scan completed and reported findings
- `2` — an invocation, filesystem, or scan error occurred

Note that `1` means **diagnostic findings, not program failure**. Only `2`
means `dotdoc` itself could not do its job.

## Behavior and safety

- The scan is recursive.
- Symbolic links are inspected as symbolic links. A directory symbolic link
  is checked itself, but the tree behind it is not traversed.
- Dotfiles Doctor is read-only. It never creates, moves, edits, or deletes
  your files, and it performs no automatic repair.

## Build

Requirements: a C++20 compiler and CMake 3.20 or newer. Only the C++
standard library is used.

```sh
make
```

`make` is a thin wrapper around CMake. The equivalent explicit commands are:

```sh
cmake -S . -B build
cmake --build build
```

The binary is written to `build/dotdoc`.

## Test

```sh
make test
```

This runs the integration tests (`tests/test_dotdoc.sh`) through CTest. The
tests build their fixtures in a temporary directory and never touch your
real `$HOME` or dotfiles.

## Install from source

Installation uses the CMake install rules. For a user-local install:

```sh
cmake -S . -B build
cmake --build build
cmake --install build --prefix "$HOME/.local"
```

That installs:

- `$HOME/.local/bin/dotdoc`
- `$HOME/.local/share/man/man1/dotdoc.1`

Make sure `$HOME/.local/bin` is on your `PATH`.

For a typical system-wide source install, use `/usr/local`:

```sh
sudo cmake --install build --prefix /usr/local
```

On Arch Linux, prefer the packaged install described below.

### Removing a source install

There is no `uninstall` target. To remove a source install, delete the
installed files by hand under the prefix you used:

```sh
rm -f "$HOME/.local/bin/dotdoc"
rm -f "$HOME/.local/share/man/man1/dotdoc.1"
```

## Arch Linux

A `PKGBUILD` is included in the repository root. On Arch Linux, install
Dotfiles Doctor as a package rather than from source, so that pacman owns
the files and can remove them again.

```sh
git clone https://github.com/seekerkrt/dotfiles-doctor.git
cd dotfiles-doctor
makepkg -si
```

The `PKGBUILD` reads the version from the repository root `VERSION` file and
builds from the matching upstream Git tag `v<version>`, not from your local
working tree, so that tag has to exist upstream.

`makepkg` uses its own `src/` and `pkg/` directories in the repository root.
This project keeps its own C++ sources in `source/`, so `makepkg -csi` can
clean up after itself without deleting them.

`makepkg` also writes the built `.pkg.tar.zst` into the repository root, so
you can install or remove it with pacman directly:

```sh
sudo pacman -U dotfiles-doctor-*.pkg.tar.zst
sudo pacman -R dotfiles-doctor
```

Dotfiles Doctor is not published on the AUR.

## Documentation

- `man dotdoc` — manual page, installed together with the binary
- [docs/CODING_CONVENTIONS.md](docs/CODING_CONVENTIONS.md) — project-specific C++ conventions
- [GitHub issues](https://github.com/seekerkrt/dotfiles-doctor/issues) — roadmap and planned diagnostics

## License

This project is licensed under `GPL-3.0-or-later`.
See [LICENSE](LICENSE) for the full GNU GPL version 3 text.
