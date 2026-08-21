# AGENTS.md

## 位置づけ

この文書は、Dotfiles Doctor repositoryで作業するときの入口・SSOT地図・固有の作業境界を定める。

言語非依存の共通契約はCodexのグローバル`AGENTS.md`、C/C++共通規約は`cpp-conventions` Skillを基準とし、ここでは再掲しない。

Dotfiles Doctor固有の指示、`docs/CODING_CONVENTIONS.md`、実際に使用されるbuild / tool設定が共通規約と矛盾する場合は、より具体的なrepository側の契約を優先する。

## Repository概要と優先事項

Dotfiles Doctorは、dotfilesおよびGNU Stowで管理された環境を主要対象とする、小さなC++診断CLIである。

CLI command名は`dotdoctor`。

GNU Stow専用toolではなく、dotfiles repositoryを診断するtoolとして扱う。GNU Stowは主要な対象環境の一つである。

このrepositoryでは、特に次を優先する。

* 小さく理解しやすいdiagnostic toolとして維持する
* filesystem上の事実取得、診断判定、CLI表示の責務を不用意に混ぜない
* path / symlinkの意味を正確に扱い、false positiveを抑える
* read-onlyを基本とし、診断を理由に利用者のdotfilesを暗黙に変更しない
* standard libraryで十分な処理を独自wrapperやexternal commandで再実装しない
* 将来の拡張だけを理由に、現在不要なframeworkや抽象化を導入しない

## 最初に読む文書

* `README.md`: project概要、現状、利用者向け情報
* `README.ja.md`: READMEの日本語版
* `docs/CODING_CONVENTIONS.md`: Dotfiles Doctor固有のC++追加・上書き規約
* `LICENSE`: GPL-3.0-or-later license

設計文書が追加された場合は、その責務に対応する正式文書をSSOTとする。

設計判断の詳細をこの文書やコーディング規約へ重複して書かない。

## 重要な責務境界

* filesystem traversalはfilesystem上の事実を収集する責務とし、user-facingなdiagnostic policyを必要以上に埋め込まない。
* symlink entry自身、raw target、解決済みtargetを区別する。
* broken symlinkを扱う経路で、targetが存在することを暗黙の前提にしない。
* path containmentを単純な文字列prefixだけで判定しない。
* directory symlinkを意図せず再帰followしない。
* diagnosticとして発見した問題と、Dotfiles Doctor自身の実行failureを区別する。
* diagnostic dataとstdout / stderrへの表示を必要以上に密結合させない。
* 利用者が指定したrepositoryや`$HOME`をtest fixtureとして直接変更しない。
* GNU Stow固有の情報を扱う場合も、dotfiles一般の診断責務とStow固有logicを混ぜすぎない。

## Skill routing

* C/C++の生成・編集・レビューでは`cpp-conventions`を使い、続けて`docs/CODING_CONVENTIONS.md`を必ず読む。
* read-onlyの責務監査、unused判定、docs整合確認では`audit`を使う。
* 非自明な変更後のbuild / test / CLI確認では`verify`を使う。
* commit前の差分整理では`commit-prep`、GitHub操作では`github`を使う。
* handoffは依頼された保存方式に対応するhandoff系Skillへroutingする。

## Build・testの入口

現時点ではbuild systemとtest runnerをこの文書で固定しない。

repositoryに実際のbuild / test設定が追加された場合は、それをSSOTとしてこの節を更新する。

存在しない`make`、CMake target、test command等を推測して実行しない。

現時点で共通して使用できる確認:

* `git diff --check`: docs-onlyを含む差分の基本確認
* Markdown変更時はrepositoryに存在するmarkdownlint設定を確認し、利用可能な既存toolだけを使う
* C++変更時はrepositoryに存在する`.clang-format`、`.editorconfig`、compiler設定を基準とする

filesystem testを追加する場合はtemporary directory / fixture内だけで状態を構築し、利用者の実際のdotfilesや`$HOME`を変更しない。

## Branch・remote

現在のrepository状態を確認してから操作する。

branch、remote、GitHub repository、release運用等について、この文書に存在しないpolicyを推測で補わない。

Issue、PR、commit message等の運用規約が別途定義された場合は、その正式文書をSSOTとする。

## Repository固有の慎重領域

* symlink自身の状態とtargetをfollowした状態の区別
* relative / absolute pathの意味
* broken symlink
* path normalizationとrepository境界判定
* symlink chain / loop
* directory traversalとdirectory symlink
* filesystem permission / I/O failure
* machine固有の`$HOME`、username、absolute path依存
* diagnosticのfalse positive / false negative
* stdout / stderr、CLI wording、終了code等のpublic contract
* GNU Stow固有logicを導入する場合の一般diagnosticとの責務境界

## Repository固有のnon-goal

少なくとも明示的な設計変更が行われるまでは、次を暗黙に追加しない。

* dotfiles deployment
* dotfiles managerそのものの再実装
* diagnostic結果に基づく自動修復
* 利用者file / symlinkの暗黙な書き換え
* Git repository mutation
* GNU Stowの暗黙なapply / remove
* package installation
* systemd設定変更
* convenienceだけを理由にした汎用wrapperやglobal state
* file分割、namespace導入、整形自体を目的にした一括変更

新しい責務を追加する場合は、現在の小さなdiagnostic toolというproject境界に収まるかを先に確認する。
