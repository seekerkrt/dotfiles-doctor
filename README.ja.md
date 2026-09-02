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

Early development（初期開発段階）です。このsource treeが返すversionは`0.2.0`
です。

現在利用できる機能は次のとおりです。

- broken symbolic linkの検出
- absolute symbolic linkの検出
- `--exclude PATH`
- `--max-depth N`
- `--only KIND`
- `-h` / `--help`
- `--version`

診断機能は今後追加予定です。roadmapは後述のGitHub issuesにあります。

## 使い方

```text
dotdoc [OPTIONS] [PATH]
```

- `dotdoc` — `$HOME/dotfiles`を走査する
- `dotdoc PATH` — 指定したdirectory treeを走査する
- `dotdoc --exclude PATH` — scan rootからの相対`PATH`を除外する。複数回指定できる
- `dotdoc --max-depth N` — depth `N`まで走査する。scan rootはdepth 0。複数回指定できる
- `dotdoc --only KIND` — 指定したdiagnostic kindのfindingだけを表示する。複数回指定できる
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

既知のnoiseとなるsubtreeは`--exclude`で除外できます。

```sh
dotdoc --exclude .local/share/Steam --exclude .cache "$HOME"
```

`--exclude`の`PATH`はscan root基準のliteral pathであり、glob、正規表現、
ignore fileの規則ではありません。

走査する最大depthは`--max-depth`で制限できます。

```sh
dotdoc --max-depth 3 "$HOME"
```

`--max-depth N`はscan rootをdepth 0と見なします。`N`は0以上の整数です。
複数回指定した場合は、最後の値が有効です。

`--only`を使うと、表示するdiagnostic kindを絞り込めます。現在指定できる
kindは`broken`と`absolute`です。

```sh
dotdoc --only broken "$HOME/dotfiles"
dotdoc --only absolute "$HOME/dotfiles"
dotdoc --only broken --only absolute "$HOME/dotfiles"
```

`--only`は複数回指定でき、複数指定はORとして扱います。scan時には従来どおり
全diagnostic findingをcollectし、その後でfilterします。filter後findingが0件なら
`OK: no findings.`を表示して終了コード`0`、1件以上なら終了コード`1`です。
未知のkindはinvocation errorとなり、終了コードは`2`です。

`--help`と`--version`は`$HOME`やscan rootの確認より先に処理されるため、
どちらも利用できない状態でも動作します。

## 出力

findingsは標準出力へ書き出されます。diagnostic finding 1件につき1行で、
path順に並びます。各行にはscan rootからの相対pathと、symbolic linkのraw target
が表示されます。
1つのsymbolic linkから複数のfindingsが報告される場合があります。

```console
$ dotdoc ~/dotfiles
ABSOLUTE: "gitconfig" -> "/home/example/.config/git/config"
BROKEN: "nvim/init.lua" -> "../missing/init.lua"
Found 2 findings.
```

findingsがない場合は次のようになります。

```console
$ dotdoc ~/dotfiles
OK: no findings.
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
- `--exclude PATH`はscan root基準の相対pathとして解釈し、複数回指定できます。
  除外したdirectoryは走査時点でsubtreeごとpruneします。除外したfileまたは
  symbolic linkはexact matchでskipします。
- 除外判定はlexical normalization後のliteral path一致です。globや正規表現では
  なく、canonicalizeせず、symbolic linkのtargetをfollowして判定することも
  ありません。
- `--exclude .`、およびlexical normalizationの結果`.`になる指定は、scan root
  全体を除外します。存在しないexclude pathは無視されます。空のexclude path、
  絶対path、またはscan root外へescapeするexclude pathはinvocation errorとなり、
  終了コードは`2`です。
- `--exclude`は`BROKEN`と`ABSOLUTE`の両方の診断に共通して適用されます。
- `--max-depth N`は走査する最大depthを制限します。scan rootはdepth 0、
  direct entryはdepth 1です。`--max-depth 0`はrootをvalidateしますが、
  entryはscanしません。`--max-depth N`はdepth `N`まで診断し、それより
  深くdescendしません。
- `N`は0以上の整数です。invalidな値はinvocation errorとなり、終了コード
  は`2`です。`--max-depth`は`--exclude`と併用できます。複数回指定した
  場合は、最後の値が有効です。
- `--only KIND`は`broken`または`absolute`を指定でき、複数回指定した場合は
  ORとして扱います。全findingをcollectした後でfilterし、表示、finding数、
  終了コードはfilter後findingを基準にします。未知のkindはinvocation errorで
  終了コード`2`です。
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
既知のnoiseとなるsubtreeは`--exclude`で除外でき、走査depthは`--max-depth`
で制限できます。残りのfindingsの判定は変わりません。

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
