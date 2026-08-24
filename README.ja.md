# Dotfiles Doctor

English: [README.md](README.md)

Dotfiles Doctorは、dotfilesを主要なユースケースとする、directory tree向けの
小さなread-only診断CLIです。
command名は`dotdoc`です。

## 概要

`dotdoc`はdirectory treeを再帰的に走査し、見つかった問題を報告します。
走査対象のファイルは変更しません。

dotfilesやGNU Stowで管理された環境を主要なユースケースとしていますが、
Dotfiles DoctorはdotfilesやGNU Stowだけに限定されたツールではありません。
明示的にpathを指定した場合は、任意のdirectory treeを対象とする汎用的な
diagnostic toolとして利用できます。

diagnosticはGNU Stow固有のmetadataやdirectory構造ではなく、filesystem上の
事実に基づいて行います。また、dotfilesのmanagerやdeployerでもなく、
おかしな箇所を報告するまでを役割とし、修正は利用者に委ねます。

つまり、Dotfiles Doctorは**dotfiles-first, but not dotfiles-only**です。

## 現状

Early development（初期開発段階）です。このsource treeが返すversionは`0.1.0`
です。

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
- `dotdoc PATH` — 指定したdirectory treeを走査する
- `dotdoc -h`、`dotdoc --help` — usageを表示して終了する
- `dotdoc --version` — version情報を表示して終了する

defaultのdotfiles treeは次のように走査できます。

```sh
dotdoc
```

明示的に指定したdirectory treeを走査する場合は次のようにします。

```sh
dotdoc "$HOME"
```

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
Found 2 broken symlinks.
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
- `PATH`を省略した場合、scan rootは従来どおり`$HOME/dotfiles`です。
- `PATH`を指定した場合、そのdirectoryをscan rootとして使用します。
- symbolic linkはsymbolic link自身として検査します。directory symbolic linkは
  それ自体を検査しますが、その先のtree（target tree）は辿りません。
- diagnosticはfilesystemの状態に基づいて行い、GNU Stow固有のdirectory構造を
  必要としません。
- Dotfiles Doctorはread-onlyです。利用者のファイルを作成、移動、編集、削除する
  ことはなく、自動修復も行いません。

`$HOME`や`/`のような広いdirectory treeを走査すると、大量のfindingsが現れる
場合があります。runtime環境、container、WineやProton、Electron application
などは、一時的、環境依存、または意図的に解決できないsymbolic linkを生成する
ことがあります。それらもfilesystem上のfindingとして正しく報告されます。

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

```sh
git clone https://github.com/seekerkrt/dotfiles-doctor.git
cd dotfiles-doctor
makepkg -si
```

`PKGBUILD`はrepository rootの`VERSION`からversionを読み、対応するupstreamの
Git tag `v<version>`からbuildします。手元のworking treeをbuildするわけでは
ないため、そのtagがupstreamに存在している必要があります。

makepkgはrepository root直下に自身の`src/`と`pkg/`を作成します。本project
自身のC++ sourceは`source/`に置いているため、`makepkg -csi`がこれらを片付け
てもproject sourceは削除されません。

makepkgはbuildした`.pkg.tar.zst`もrepository rootへ生成するので、pacmanから
直接install / removeできます。

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
