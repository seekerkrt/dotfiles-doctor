# Dotfiles Doctor

日本語: [README.ja.md](README.ja.md)

Dotfiles Doctor is a small diagnostic tool for dotfiles and GNU Stow managed
environments. The CLI command is `dotdoctor`.

## Overview

Dotfiles Doctor is a C++ project for inspecting a user's dotfiles. GNU Stow
managed environments are a primary target, but this is not a GNU Stow-only
tool.

The initial direction is a small, diagnostic-oriented command. It is intended
to help people understand the state of their files, not to become another
full dotfiles manager.

Diagnostic features are not implemented yet. There is currently no usable
CLI.

## Status

Early development.

There is no usable release. Source code, tests, and a build system are not in
place yet.

## Project principles

- Small and focused
- Diagnostic-oriented
- Read-only by default
- Understandable and maintainable
- Avoid becoming another full dotfiles manager

## Development

Dotfiles Doctor uses C++20.

See [docs/CODING_CONVENTIONS.md](docs/CODING_CONVENTIONS.md) for
project-specific coding conventions.

The build system is not decided yet. This README does not list build
commands.

## Repository structure

Current top-level layout:

- `LICENSE` — GNU GPL v3 or later
- `README.md` / `README.ja.md` — English and Japanese overviews
- `docs/` — project documentation, currently coding conventions
- `.editorconfig` — editor defaults
- `.clang-format` — clang-format settings
- `.markdownlint-cli2.jsonc` — Markdown lint settings

## License

This project is licensed under `GPL-3.0-or-later`.
See [LICENSE](LICENSE) for the full GNU GPL version 3 text.
