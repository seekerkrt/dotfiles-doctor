# Dotfiles Doctor

English: [README.md](README.md)

Dotfiles Doctorは、dotfilesおよびGNU Stowで管理された環境向けの、小さな診断
ツールです。CLI command名は`dotdoc`です。

## 概要

Dotfiles Doctorは、利用者のdotfilesを対象とするC++のプロジェクトです。GNU
Stowで管理された環境も主要な対象の一つですが、GNU Stow専用ツールではありません。

現時点の方向性は、小さな診断向けコマンドです。dotfiles全体を管理する新しい
マネージャーになることではなく、ファイルの状態を把握する助けになることを
意図しています。

診断機能はまだ実装されていません。現時点で利用可能なCLIはありません。

## 現状

Early development（初期開発段階）です。

利用可能なreleaseはありません。source code、test、build systemもまだ整っていません。

## プロジェクトの方針

- 小さく、対象を絞る
- 診断を中心にする
- 既定ではread-only
- 理解しやすく、保守しやすく保つ
- 本格的なdotfilesマネージャーへ肥大化させない

## 開発

Dotfiles DoctorはC++20を使用します。

プロジェクト固有のコーディング規約は
[docs/CODING_CONVENTIONS.md](docs/CODING_CONVENTIONS.md) を参照してください。

build systemはまだ決まっていません。このREADMEにはbuild commandを書いていません。

## Repository構成

現在のトップレベル構成は次のとおりです。

- `LICENSE` — GNU GPL v3 or later
- `README.md` / `README.ja.md` — 英語版と日本語版の概要
- `docs/` — プロジェクト文書。現時点ではコーディング規約
- `.editorconfig` — editorの既定値
- `.clang-format` — clang-format設定
- `.markdownlint-cli2.jsonc` — Markdown lint設定

## License

このプロジェクトは`GPL-3.0-or-later`で提供します。
GNU GPL version 3の全文は[LICENSE](LICENSE)を参照してください。
