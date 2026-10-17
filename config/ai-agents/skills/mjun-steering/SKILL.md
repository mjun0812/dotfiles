---
name: mjun-steering
description: >-
  `.mjun/steering/` のプロジェクトメモリ (product.md、tech.md、structure.md、ドメイン別のcustom steering) と、用語集 `CONTEXT.md`・ADR (Git管理へ移行済みなら `docs/adr/`、それ以外は `.mjun/steering/adr/`) を、コードベースと履歴から作成・更新するSkill。
  ユーザーが「steeringを作って」「steeringを更新して」「プロジェクトメモリを整備して」のように依頼したら使うこと。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(find:*), Bash(rg:*), Bash(git:*), Bash(cat:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(tree:*), Bash(mkdir:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh issue list:*), Bash(gh issue view:*)
disable-model-invocation: true
---

# mjun-steering

## 目的

`.mjun/steering/` を、agentがコードを書く前に読むプロジェクトの永続メモリとして維持する。steeringは「このプロジェクトではこう書く」というパターンと原則を伝えるもので、コードの写しではない。既存パターンに従う新しいコードのためにsteeringを更新せずに済む粒度を目安にする。何を書き何を省くかは [references/steering_principles.md](references/steering_principles.md) を参照する。

置き場所は内容の性質で分ける。

- core (`product.md`、`tech.md`、`structure.md`) とcustom (`<domain>.md`): 現在のコードに証拠があるパターン。コードに合わせて更新する
- 用語集 `CONTEXT.md` とADR: 用語の呼び分けと判断の理由。履歴から発掘して追記し、コードから再生成しない。保存先・書式・規則は [references/glossary_and_adr.md](references/glossary_and_adr.md) に従う

`.mjun/steering/*.md` はcore・customを問わずすべてプロジェクトメモリとして読み込まれるので、両者を同じ重みで扱う。

## 守ること

- secret (API key、パスワード、認証情報、DBのURL、内部IP) を書かない。steeringはagentのcontextへ毎回読み込まれ、Git管理されることもあるので、書いた時点で流出する
- ユーザーが書いた記述を置換・削除しない。更新は追記を基本にし、変えた理由をサマリに書く。ユーザーの記述とコードが食い違い、どちらが正か判断できないときは、書き換えずに両方の状態を報告して確認する
- `CONTEXT.md` とADRは追記専用にする。例外 (supersededの追記、Git管理への移行、番号の振り直し) は [共通記録規則](references/glossary_and_adr.md) に従う。判断の理由は失うと取り戻せず、捏造すると将来の判断を誤らせるので、理由が明文でない履歴から判断を作らない

## 作業の選び方

- 用語集やADRをGit管理に移す依頼: [Git管理へ移す場合](references/glossary_and_adr.md#git管理へ移す場合) の手順だけを行う。`.mjun/` 側の元ファイルの削除はこの移行に限った例外で、移行先の検証が済んでから行う
- spec作成や会話の中でADRを書く場合: [共通記録規則](references/glossary_and_adr.md) だけを適用し、Bootstrap / Syncは始めない
- それ以外: `.mjun/steering/` にcore 3ファイルがそろっていればSync Flow、1つでも欠けていればBootstrap Flowを行う

会話の中で既に読んだsteeringは読み直さなくてよい。

## Bootstrap Flow

coreの分析結果 (技術スタック、構成パターン) をcustomの判断に使うため、Phase 1から順に進める。

### Phase 1: core 3ファイル

次の3観点でコードベースを調べ、[product](references/product_template.md)・[tech](references/tech_template.md)・[structure](references/structure_template.md) のテンプレートに沿って `.mjun/steering/` へ書く。3観点は独立しているので並列に調べてよい。

- Product: README、マニフェスト、docsから目的・価値・core capabilities
- Tech: 設定ファイル、依存、frameworkから技術上の決定と規約
- Structure: ディレクトリ構成、命名、importから構成方針

### Phase 2: customファイル

ドメイン横断でコードを調べ、[作成基準](#customファイルの作成基準) を満たすドメインをすべて `.mjun/steering/<domain>.md` として確認なしで作る。

### Phase 3: 用語集とADRの発掘

全件は読まず、理由が書かれている履歴に絞る。対象は本文に理由があるmerged PR、議論のあるclosed Issue、README・docsの設計記述、既存の `docs/adr/` である。GitHubリポジトリでなく `gh` が使えなければ、docsとcommit messageを対象にする。用語集とADRへ入れる内容の基準は [履歴の発掘](references/glossary_and_adr.md#履歴の発掘) と [ADRにする基準](references/glossary_and_adr.md#adrにする基準) を参照する。

Phase 1〜3の結果は1つのサマリにまとめて [出力](#出力) する。

## Sync Flow

1. 既存の `.mjun/steering/*.md` をすべて読み、コードベースの変更を調べる
2. core / customとコードのdriftを調べる。steeringにあってコードに無い要素はWarningにし、コードに現れた新しいパターンは追記で反映する。customファイルはまだ有効かを確かめる
3. [作成基準](#customファイルの作成基準) を新たに満たしたドメインがあれば、候補の提示で止めずにcustomファイルを作る
4. 既存ADRと判断が重複しないmerged PRとclosed Issueから、Bootstrap Phase 3と同じ基準で用語とADRを追記する。コードが有効なADRに反していれば、未実装の計画かどうかを確かめ、実装済みならCode Driftとして報告する
5. [出力](#出力) する

## customファイルの作成基準

コードベースに実在するパターンを、具体的なファイルパス付きで挙げられるドメインだけを作る。証拠の無い一般論のベストプラクティス集は、読んだagentに実在しない規約を守らせてしまう。

- 証拠を挙げられるドメインは数の上限なく作り、分量は証拠の量に従わせる
- 1ファイル1ドメインにし、coreと内容を重ねない
- 証拠があるか判断できないドメインは作らず、見送った理由をサマリで報告する
- ADRはこの基準の対象外である

[`references/steering_custom/`](references/steering_custom) のテンプレート (api-standards、testing、security、database、error-handling、authentication、deployment) は見出し構成の起点に使う。本文は一般論の例なので、コードに証拠のある内容に置き換え、証拠の無い節は削る。テンプレートの無いドメイン (i18n、ロギング、ジョブキューなど) も、基準を満たせば作ってよい。

## 出力

ファイルは直接更新し、チャットにはサマリだけを出す。customファイルは確認なしで作る代わりに、事後レビューで不要なものを消せるよう、それぞれの根拠にしたファイルパスを必ず列挙する。追加した用語とADRには由来を付ける。

Bootstrap:

```text
Steering Created

## Core:
- product.md: [概要]
- tech.md: [主要スタック]
- structure.md: [構成方針]

## Custom:
- testing.md — 根拠: vitest.config.ts, tests/ の共通fixtureパターン
- api-standards.md — 根拠: src/routes/*.ts の統一エラー形式

## Glossary / ADR:
- CONTEXT.md: 追加 12語 (Order, Invoice, ...)
- adr/0001-use-event-sourcing.md — 由来: PR #42
- adr/0002-split-billing-service.md — 由来: Issue #17

レビューし、Source of Truthとして承認してください。不要なcustomファイルを指摘してください。判断の変更は新しいADRで追記します。
```

Sync:

```text
Steering Updated

## Changes:
- tech.md: React 18 → 19
- structure.md: APIパターンを追記

## Created:
- error-handling.md — 根拠: src/errors/ の型付きエラー階層が新設された

## Glossary / ADR:
- CONTEXT.md: 追加 2語
- adr/0003-adopt-graphql-gateway.md — 由来: PR #88

## Code Drift:
- import規約に従っていないコンポーネントあり
- src/orders/ が ADR-0001 (event-sourced) に反して直接UPDATEしている
```
