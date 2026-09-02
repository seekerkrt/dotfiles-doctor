# Dotfiles Doctor

日本語: [README.ja.md](README.ja.md)

Dotfiles Doctor is a small, read-only diagnostic CLI for directory trees,
with dotfiles as its primary use case.
The command is `dotdoc`.

## Overview

`dotdoc` recursively scans a directory tree, reports the problems it finds,
and does not modify the scanned files.

Dotfiles and GNU Stow managed environments are primary use cases, but
Dotfiles Doctor is not limited to dotfiles or GNU Stow. When an explicit
path is provided, `dotdoc` can be used as a generic directory tree
diagnostic tool.

Diagnostics are based on filesystem facts rather than GNU Stow-specific
metadata or layout. Dotfiles Doctor is also not a dotfiles manager or
deployer: it tells you what looks wrong and leaves the fix to you.

In short, Dotfiles Doctor is **dotfiles-first, but not dotfiles-only**.

## Status

Early development. This source tree reports version `0.2.0`.

Available today:

- Broken symbolic link detection
- Absolute symbolic link detection
- `--exclude PATH`
- `--max-depth N`
- `--only KIND`
- Diagnostic kind summary counts
- `-h` / `--help`
- `--version`

Further diagnostics are planned; the roadmap lives in the GitHub issues
linked below.

## Usage

```text
dotdoc [OPTIONS] [PATH]
```

- `dotdoc` — scan `$HOME/dotfiles`
- `dotdoc PATH` — scan the specified directory tree
- `dotdoc --exclude PATH` — exclude `PATH` relative to the scan root; may be repeated
- `dotdoc --max-depth N` — scan through depth `N`; the scan root is depth 0; may be repeated
- `dotdoc --only KIND` — show only findings of the selected diagnostic kind; may be repeated
- `dotdoc -h`, `dotdoc --help` — show usage and exit
- `dotdoc --version` — show version information and exit

For example, the default dotfiles tree can be scanned with:

```sh
dotdoc
```

An explicitly selected directory tree can be scanned with:

```sh
dotdoc "$HOME"
```

Known-noise subtrees can be skipped with `--exclude`:

```sh
dotdoc --exclude .local/share/Steam --exclude .cache "$HOME"
```

`--exclude PATH` is a scan-root-relative literal path, not a glob, regular
expression, or ignore-file rule.

Scan depth can be limited with `--max-depth`:

```sh
dotdoc --max-depth 3 "$HOME"
```

`--max-depth N` treats the scan root as depth 0. `N` must be a
non-negative integer. If repeated, the last value is used.

`--only` filters the displayed diagnostic kinds. The currently available
kinds are `broken` and `absolute`.

```sh
dotdoc --only broken "$HOME/dotfiles"
dotdoc --only absolute "$HOME/dotfiles"
dotdoc --only broken --only absolute "$HOME/dotfiles"
```

`--only` may be repeated, and multiple values use OR semantics. The scan
still collects all diagnostic findings first and applies the filter
afterward. If no findings remain after filtering, `dotdoc` prints
`OK: no findings.` and exits with status `0`; one or more filtered findings
produce status `1`. An unknown kind is an invocation error and exits with
status `2`.

`--help` and `--version` are handled before `$HOME` and the scan root are
inspected, so they work even when neither is usable.

## Output

Findings are written to standard output, one line per diagnostic finding,
sorted by path. Each line shows the path relative to the scan root followed
by the raw symbolic link target.
A single symbolic link can produce more than one finding.

```console
$ dotdoc ~/dotfiles
ABSOLUTE: "gitconfig" -> "/home/example/.config/git/config"
BROKEN: "nvim/init.lua" -> "../missing/init.lua"
Found 2 findings (BROKEN: 1, ABSOLUTE: 1).
```

After the finding lines, `dotdoc` prints one summary line with the total
finding count and the count for each diagnostic kind. Kind counts are always
shown in the fixed order `BROKEN`, `ABSOLUTE`, including kinds whose count is
zero. When `--only` is used, both the total and kind counts are based only on
the filtered findings.

When nothing is found:

```console
$ dotdoc ~/dotfiles
OK: no findings.
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
- Without `PATH`, the scan root remains `$HOME/dotfiles`.
- With `PATH`, the specified directory is used as the scan root.
- `--exclude PATH` is interpreted relative to the scan root and may be
  repeated. An excluded directory is pruned during traversal, so its
  subtree is not scanned. An excluded file or symbolic link is skipped on
  exact match.
- Exclude matching is literal after lexical normalization. It is not glob
  or regular-expression matching, the path is not canonicalized, and
  symbolic-link targets are not followed when deciding whether a path is
  excluded.
- `--exclude .`, or a path that lexically normalizes to `.`, excludes the
  entire scan root. A nonexistent exclude path is ignored. An empty
  exclude path, an absolute exclude path, or an exclude path that
  lexically escapes the scan root is an invocation error and exits with
  status `2`.
- `--exclude` applies to both `BROKEN` and `ABSOLUTE` findings.
- `--max-depth N` limits the scan to depth `N`. The scan root is depth 0,
  and a direct entry is depth 1. `--max-depth 0` validates the scan root
  but does not scan any entries. `--max-depth N` diagnoses through depth
  `N` and does not descend deeper.
- `N` must be a non-negative integer. An invalid value is an invocation
  error and exits with status `2`. `--max-depth` may be combined with
  `--exclude`. If `--max-depth` is repeated, the last value is used.
- `--only KIND` accepts `broken` or `absolute`. Repeated values use OR
  semantics. All findings are collected before filtering, and output,
  finding counts, and exit status are based on the filtered findings.
  An unknown kind is an invocation error and exits with status `2`.
- Symbolic links are inspected as symbolic links. A directory symbolic link
  is checked itself, but the tree behind it is not traversed.
- Diagnostics are based on filesystem state and do not require a GNU Stow
  layout.
- Dotfiles Doctor is read-only. It never creates, moves, edits, or deletes
  your files, and it performs no automatic repair.

Scanning a broad directory tree such as `$HOME` or `/` can produce a large
number of findings. Runtime environments, containers, Wine or Proton,
Electron applications, and similar software may create temporary,
environment-specific, or intentionally unresolved symbolic links that are
still correctly reported as filesystem findings. Use `--exclude` to skip
known-noise subtrees, or `--max-depth` to limit how deep the scan
descends, without changing how remaining findings are judged.

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
