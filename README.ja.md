# Dotfiles Doctor

English: [README.md](README.md)

Dotfiles Doctorは、dotfiles treeを対象とする小さなread-only診断CLIです。
command名は`dotdoc`です。

## 概要

`dotdoc`はdotfiles treeを走査し、見つかった問題を報告します。走査対象の
ファイルは変更しません。

GNU Stowで管理された環境も主要な対象の一つですが、GNU Stow専用ツールでは
ありません。dotfilesのmanagerやdeployerでもなく、おかしな箇所を報告するまでを
役割とし、修正は利用者に委ねます。

## 現状

Early development（初期開発段階）で、最初のreleaseへ向けて開発中です。
現時点で`dotdoc --version`が返すversionは`0.1.0`で、tag付きreleaseはまだ
ありません。

現在利用できる機能は次のとおりです。

- broken symbolic linkの検出
- `-h` / `--help`
- `--version`

診断機能は今後追加予定です。roadmapは後述のGitHub issuesにあります。

## 使い方

```text
dotdoc [OPTIONS] [PATH]
```

- `dotdoc` — `$HOME/dotfiles`を走査する
- `dotdoc PATH` — 指定したdirectoryだけを走査する
- `dotdoc -h`、`dotdoc --help` — usageを表示して終了する
- `dotdoc --version` — version情報を表示して終了する

`--help`と`--version`は`$HOME`やscan rootの確認より先に処理されるため、
どちらも利用できない状態でも動作します。

## 出力

findingsは標準出力へ書き出されます。broken symbolic link 1件につき1行で、
path順に並びます。各行にはscan rootからの相対pathと、symbolic linkのraw target
が表示されます。

```console
$ dotdoc ~/dotfiles
BROKEN: "nvim/init.lua" -> "../missing/init.lua"
BROKEN: "zshrc" -> "/home/example/does-not-exist/zshrc"
```

findingsがない場合は次のようになります。

```console
$ dotdoc ~/dotfiles
OK: no broken symlinks found.
```

invocation errorとfilesystem errorは標準エラー出力へ書き出されます。

## 終了コード

- `0` — scanが完了し、findingsはなかった
- `1` — scanが完了し、findingsを報告した
- `2` — invocation、filesystem、またはscanのerrorが発生した

`1`は**diagnostic findingsがあったという意味であり、program failureでは
ありません**。`dotdoc`自身が処理を完了できなかったことを示すのは`2`だけです。

## 動作と安全性

- scanは再帰的に行います。
- symbolic linkはsymbolic link自身として検査します。directory symbolic linkは
  それ自体を検査しますが、その先のtree（target tree）は辿りません。
- Dotfiles Doctorはread-onlyです。利用者のファイルを作成、移動、編集、削除する
  ことはなく、自動修復も行いません。

## Build

必要なものは、C++20対応のcompilerとCMake 3.20以上です。C++ standard library
以外は使用しません。

```sh
make
```

`make`はCMakeの薄いwrapperです。同等の明示的なcommandは次のとおりです。

```sh
cmake -S . -B build
cmake --build build
```

binaryは`build/dotdoc`へ生成されます。

## Test

```sh
make test
```

CTest経由でintegration test（`tests/test_dotdoc.sh`）を実行します。testは
一時directory内にfixtureを構築するため、実際の`$HOME`やdotfilesを変更する
ことはありません。

## Sourceからのinstall

installにはCMakeのinstall rulesを使用します。user-local installの例は次の
とおりです。

```sh
cmake -S . -B build
cmake --build build
cmake --install build --prefix "$HOME/.local"
```

これにより次が配置されます。

- `$HOME/.local/bin/dotdoc`
- `$HOME/.local/share/man/man1/dotdoc.1`

`$HOME/.local/bin`が`PATH`に含まれていることを確認してください。

一般的なsystem-wide source installでは`/usr/local`を使用します。

```sh
sudo cmake --install build --prefix /usr/local
```

Arch Linuxでは、後述のpackageによるinstallを推奨します。

### Source installの削除

`uninstall` targetは提供していません。source installを削除する場合は、使用した
install prefix配下のファイルを手動で削除してください。

```sh
rm -f "$HOME/.local/bin/dotdoc"
rm -f "$HOME/.local/share/man/man1/dotdoc.1"
```

## Arch Linux

repository rootに`PKGBUILD`を用意しています。Arch Linuxでは、source install
よりもpackageとしてのinstallを推奨します。pacmanがファイルを管理し、削除も
pacmanで行えるためです。

このrepository自身がトップレベルに`src/`directoryを持つため、makepkgの作業
directoryを分けて指定してください。

```sh
BUILDDIR="$PWD/.makepkg" makepkg --cleanbuild
```

`PKGBUILD`はpin済みのupstream source tarballからbuildするもので、手元の
working treeをbuildするわけではありません。makepkgはrepository rootへ
`.pkg.tar.zst`を生成するので、pacmanでinstall / removeします。

```sh
sudo pacman -U dotfiles-doctor-*.pkg.tar.zst
sudo pacman -R dotfiles-doctor
```

Dotfiles DoctorはAURへは公開していません。

## ドキュメント

- `man dotdoc` — manual page。binaryと一緒にinstallされます
- [docs/CODING_CONVENTIONS.md](docs/CODING_CONVENTIONS.md) — プロジェクト固有のC++コーディング規約
- [GitHub issues](https://github.com/seekerkrt/dotfiles-doctor/issues) — roadmapと今後の診断機能

## License

このプロジェクトは`GPL-3.0-or-later`で提供します。
GNU GPL version 3の全文は[LICENSE](LICENSE)を参照してください。
