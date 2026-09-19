# Dotfiles Doctor固有 C++ コーディング規約

## 位置づけと優先順位

C/C++共通規約は`cpp-conventions` Skillを基準とする。
この文書はDotfiles Doctor固有の追加・上書き規約だけを定める。

矛盾する場合は、この文書と実際に使用されるbuild設定を優先する。ここに書かれていない共通規則は`cpp-conventions`へ従う。

CLI仕様、診断対象、終了code、互換性等の設計判断は対応する正式docsを正とし、この文書へ詳細を複製しない。

## 言語・実行環境

* C++20を基準とする。
* hosted環境を前提とし、standard libraryを積極的に利用する。
* filesystem操作には原則として`std::filesystem`を使用する。
* standard libraryで十分に表現できる処理のためにexternal libraryやexternal commandを追加しない。
* 例外は内部の失敗伝播に使用できる。CLI境界で`std::exception`等を捕捉し、利用者向けerrorと終了codeへ変換する。
* destructorから例外を外へ出さない。cleanup failureを無視する場合は、その契約が重要なら理由を残す。
* RTTI / `dynamic_cast`は基本設計の前提としない。新しく必要になった場合は、型判別よりinterfaceやdata modelで表現できないかを先に確認する。
* `reinterpret_cast`を通常のapplication logicへ導入しない。OS固有API等との境界で必要な場合は、狭いadapterに閉じて前提を明示する。

## File構成と分割

* entry pointにはCLI parsingとtop-level wiringを置き、filesystem走査や診断判定等のdomain実装を詰め込まない。
* 新しい非自明な型や複数箇所から使うinterfaceは、必要に応じて宣言を`.hpp`、定義を`.cpp`へ分ける。
* filesystem走査、path処理、診断判定、表示処理は、それぞれの責務が大きくなった時点で分離する。
* 既存の責務へ自然に収まる変更では、新しいgeneric moduleやwrapperを増やさない。
* 1箇所からしか使わない小さな処理を、将来利用を想定して早期に共通化しない。
* file分割そのものを目的に既存moduleを一括移動しない。
* testは対象moduleと既存`tests/`の構成に対応させる。

## 命名

* 型、class、struct、`enum class`はPascalCaseを基本とする。
* `enum class`のvalueもPascalCaseを基本とする。
* free function、method、private / internal helper、local variable、argumentはsnake_caseを基本とする。
* 新しいclass memberは`_`接尾辞、単純なdata aggregateのstruct memberは接尾辞なしを基本とする。
* translation-unit localなhelper、定数、補助型は無名namespaceへ閉じる。
* boolは`is_`、`has_`、`should_`、`can_`、`needs_`等、真偽の意味が読める名前を優先する。
* path関連では`path`、`target`、`resolved_path`、`root`等、値の意味や解決状態が区別できる名前にする。
* filesystem上の状態と診断結果を同じ名前で混同しない。
* repository全体をnamespaceや命名へ揃えるだけの変更は行わない。

## Functionとerrorの境界

* filesystem走査、情報取得、診断判定、表示を1つの関数へ詰め込まない。
* filesystemから事実を取得する処理と、その事実を診断結果へ分類する処理を可能な範囲で分ける。
* diagnostic dataを生成する処理とstdout / stderrへの表示を密結合させない。
* exceptionを投げる関数、`bool`、`std::optional`、exit codeを返す関数のfailure contractを混ぜない。
* recover可能なfilesystem errorとinternal invariant violationを同じerror表現へ潰さない。
* exception messageはCLI境界で利用者へ表示される可能性を前提に、失敗内容と対象pathを含める。
* 個別entryの読み取り失敗を継続可能として扱う場合、その判断をcall siteから理解できるようにする。

## Path・filesystem処理

* filesystem pathの基本表現には`std::filesystem::path`を使用する。
* 表示目的だけで早期に`std::string`へ変換しない。
* symlink entry自身の状態と、targetをfollowした後の状態を区別する。
* `status()`、`symlink_status()`、`read_symlink()`等は意味の違いを理解して使い分ける。
* broken symlinkを扱う処理で、無条件に`canonical()`を使用しない。
* `weakly_canonical()`等を利用する場合も、元のpathやraw symlink targetが必要なら別に保持する。
* relative pathとabsolute pathを明示的に区別する。
* path containmentの判定を単純な文字列prefix比較だけで実装しない。
* `..`やnormalizationを考慮したうえでpathを比較する。
* directory symlinkを意図せず再帰followしない。
* symlink loop等による無限走査を発生させない。
* pathの表示表現とfilesystem上のidentityを混同しない。
* filesystem APIの`std::error_code` overloadを利用する場合、errorを黙って消さず、callerが必要な判断を行える形にする。

## Data model

* filesystem上の事実とuser-facingな表示文字列を同一の型へ押し込まない。
* 複数の値を常に一緒に扱う場合は、意味のあるstructとして表現する。
* stringで状態を表現できても、閉じた集合である場合は`enum class`を優先する。
* optionalな値にはsentinel stringより`std::optional`等を優先する。
* ownershipを必要としない参照にraw owning pointerを使用しない。
* data aggregateは必要以上にclass化せず、invariantを持たない単純dataならstructを使用できる。
* bool argumentがcall siteで意味不明になる場合は、enumや意味のある型への置き換えを検討する。

## External command・dependency

* filesystem情報を取得するためだけに`find`、`readlink`、`realpath`等のexternal commandをspawnしない。
* standard libraryだけでは取得できない情報が必要な場合にのみexternal commandやOS固有APIを検討する。
* shell commandが避けられない場合は、未検証の値をshell stringへ直接連結しない。
* external dependencyを追加する場合は、standard libraryでは不足する具体的な理由を明確にする。
* 小さなutilityのために大規模frameworkを導入しない。

## Resource管理

* file、directory iterator、一時resource等はRAIIで管理する。
* raw owning pointerを導入しない。
* ownershipは型とscopeから理解できる形を優先する。
* temporary directoryやtemporary fileを作成する場合は、一意なownerを持たせcleanupを明確にする。
* current working directory等のprocess-global stateを変更する処理を安易に導入しない。
* filesystem traversal中のresource lifetimeを不必要に長く保持しない。

## 書式とtool設定

* repository rootの`.editorconfig`、`.clang-format`、compiler option等が存在する場合は、それらをSSOTとする。
* 存在しないformatter設定をこの文書だけで仮定しない。
* compiler warningを可能な限りcleanに保つ。
* warningを消すためだけのcastやsuppressionを安易に追加しない。
* formatterやlint toolを新規導入する変更は、機能変更と分けた明示的な作業にする。
* unrelated formatting changeをfeature diffへ混ぜない。

## Project固有の確認入口

build / test commandはrepository内の実際のbuild設定をSSOTとする。

build systemとtest runnerが確定した場合は、この節も合わせて更新する。

C++実装を変更した場合は最低限、

* buildが成功すること
* 新しいcompiler warningを発生させないこと
* 関連testが成功すること
* filesystem fixtureを使用するtestが利用者の実際の`$HOME`やdotfilesを変更しないこと

を確認する。
