---
name: mjun-steering
description: >-
  `.mjun/steering/` のプロジェクトメモリ (product.md、tech.md、structure.md、ドメイン別のcustom steering) と、用語集 `CONTEXT.md`・共通の決定記録 `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) を、コードベースと履歴から作成・更新するSkill。
  ユーザーが「steeringを作って」「steeringを更新して」「プロジェクトメモリを整備して」のように依頼したら使うこと。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(find:*), Bash(rg:*), Bash(git:*), Bash(cat:*), Bash(head:*), Bash(tail:*), Bash(wc:*), Bash(tree:*), Bash(mkdir:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh issue list:*), Bash(gh issue view:*)
---

# mjun-steering

## 目的

`.mjun/steering/` をプロジェクトの永続メモリとして維持する。

- **Bootstrap**: 初回にコードベースを分析してcore steeringを生成し、続けて証拠のあるドメインのcustom steeringを生成する
- **Sync**: steeringとコードベースの整合を保ち、新たに証拠が揃ったドメインのcustom steeringを追加する
- **Mine**: 履歴 (merged PR、closed Issue、設計doc) から用語と根拠が明文の決定を発掘し、用語集 `CONTEXT.md` (repo直下にあればそれ、無ければ `.mjun/CONTEXT.md`) と決定記録 `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) へ追記する (追記専用。既存項目を書き換えない)
- **Preserve**: ユーザーのカスタマイズは神聖。更新は追記で行い、置換しない

成功条件:

- core / customが網羅的なリストではなく、パターンと原則を記録している
- steeringとコードのdriftが検出・報告されている
- `.mjun/steering/*.md` はcore・customを問わずすべて等しく扱われている
- customファイルはすべて、根拠となる実在のコードパターンに基づいている
- `CONTEXT.md` と `decisions.md` への追記は、すべて由来 (出典) を持つ

## Git管理への移行

用語集や判断記録をGit管理へ移す依頼では、[共通記録規則の移行手順](references/glossary_and_adr.md#git管理へ移す場合) を適用する。全内容と参照を移して検証し、移行先をGit管理対象にした後で `.mjun/` 側の元ファイルを削除する。これは追記・削除禁止の保存先移行に限った例外である。以後は移行先だけを使う。

## 決定の追記

spec作成や会話中に判断を記録する場合は [共通記録規則](references/glossary_and_adr.md) だけを適用する。`decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) が無ければ親ディレクトリとともに作り、暫定案も状態付きで追記する。Git管理へ移行済みならそこへ追記し、旧ファイルは再作成しない。この操作だけでは以下のBootstrap / Syncを開始しない。decisions.mdはcustom作成基準の対象外である。

## モード判定

`.mjun/steering/` の状態を確認してモードを自動判別する。

- **Bootstrap Mode**: ディレクトリが空、またはcoreファイル (product.md, tech.md, structure.md) のいずれかが欠けている
- **Sync Mode**: coreファイルが3つとも存在する

会話の中でsteeringの内容が既に得られている場合、重複するファイル読み込みは省略してよい。

## Bootstrap Flow

Phase 1でcore 3ファイルを完成させてから、Phase 2でcustomファイル、Phase 3で用語集と決定記録に取りかかる。
customの検討をPhase 1に持ち込まないこと。

### Phase 1: core 3ファイル

1. [`references/`](references) のテンプレートを読み込む
   - [`references/product_template.md`](references/product_template.md)
   - [`references/tech_template.md`](references/tech_template.md)
   - [`references/structure_template.md`](references/structure_template.md)
2. コードベースを分析する。以下の3観点は独立しているため、並列に調査する
   - **Product分析**: README、package.json等のマニフェスト、ドキュメントから、目的・価値・core capabilities を読み取る
   - **Tech分析**: 設定ファイル、依存関係、frameworkから、技術パターンと技術的決定を読み取る
   - **Structure分析**: ディレクトリツリー、命名規則、importパターンから、構成方針を読み取る
3. パターンを抽出する (リストではなく)
   - Product: 目的、価値、core capabilities
   - Tech: framework、決定事項、規約
   - Structure: 構成、命名、import
4. テンプレートに従って `.mjun/steering/` にcore steeringファイルを生成する
5. [`references/steering_principles.md`](references/steering_principles.md) の原則に沿っているか確認する

### Phase 2: customファイル

core 3ファイルの生成が完了してから開始する。Phase 1で得た分析結果 (tech.mdの技術スタック、structure.mdの構成パターン) を前提知識として再利用する。

6. コードベースをドメイン横断でスキャンし、[作成基準](#customファイルの作成基準) を満たすドメインをすべて特定する
7. 各ドメインを `.mjun/steering/<domain>.md` に確認なしで一括生成する
8. サマリを提示してレビューを求める (Phase 3の結果も同じサマリに含める)

**Focus**: 判断を導くパターンを書く。ファイルや依存の一覧 (カタログ) を書かない。

### Phase 3: 用語集と決定記録の発掘

core / custom steeringは「コードに証拠がある事実」を書く場所であり、用語の呼び分けと決定の理由は `CONTEXT.md` と `decisions.md` に分けて書く (置き場所の解決を含む形式と規則は [references/glossary_and_adr.md](references/glossary_and_adr.md) に従う)。どちらも**追記専用**で、既存の用語・判断本文は書き換えず削除しない (決定の状態更新は共通記録規則に従う)。

9. 発掘元を集める。全件を読まず、理由が書かれているものに絞る
   - 本文に理由が書かれたmerged PR (`gh pr list --state merged --json number,title,body` で本文を持つものを選ぶ)
   - 議論のあるclosed Issue (`gh issue list --state closed --json number,title,body,comments`)
   - README・docs配下の設計記述、既存の `docs/adr/`
   - `gh` が使えない (GitHubリポジトリでない) 場合は、docsとcommit message (`git log`) だけを対象にする
10. **用語集**: コードの識別子 (型名、module名、テーブル名など) をcanonical nameとし、Issue・PR・docsで同じ概念に使われている別の呼び名を `_Avoid_` に集めて `CONTEXT.md` へ追記する (どちらも無ければ `.mjun/CONTEXT.md` を作る)。プロジェクト固有の概念だけを対象にし、一般的なプログラミング用語と実装詳細は書かない。既存の用語は触らない
11. **決定記録**: 理由が明文の非自明な判断を `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) に追記する。3条件 (覆しにくい・文脈なしでは不可解・本物のtrade-offがあった) をすべて満たすものは `Kind: adr`、それ以外は `Kind: decision` とする。Sourceと判断内容で重複を確認し、Scopeを証拠から特定する。コードから推測した理由は記録しない。形式と状態変更は [共通記録規則](references/glossary_and_adr.md) に従う。
12. サマリに追加した用語と判断のD番号を由来付きで列挙する (誤りの訂正も履歴として残す)

## Sync Flow

1. 既存の `.mjun/steering/*.md` をすべて読み込む。decisions.mdは状態とScopeを持つ判断履歴として扱い、コードから再生成しない。以下のコードとのdrift検査とcustom作成基準はcore / customに適用する
2. コードベースの変更を分析する
3. driftを検出する
   - **Steering → Code**: steeringに書かれているがコードに無い要素 → Warning
   - **Code → Steering**: コードに現れた新パターン → 更新候補
   - **Customファイル**: 内容がまだ有効か確認する
4. 更新を提案する (追記主義。ユーザーが書いた内容は保持する)
5. [作成基準](#customファイルの作成基準) を新たに満たしたドメインがあれば、その場で `.mjun/steering/<domain>.md` を作成する (候補の提示や推奨で止めない)
6. 用語集と決定記録を追記する: 共通記録のSourceと判断内容に重複しないmerged PRとclosed Issueを対象に、Bootstrap Phase 3と同じ基準で発掘して `CONTEXT.md` と `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) へ追記する。既存項目は書き換えない。コードが適用対象のacceptedな判断に反していれば、対象specの承認・実装状態を確認し、実装済みならCode Driftとして報告する
7. 報告する: 更新内容、新規作成したcustomファイル、追記した用語とADR、警告

**Update Philosophy**: 置換せず追記する。ユーザーが書いたセクションは保持する。
詳細は [`references/steering_principles.md` の Preservation](references/steering_principles.md#preservation-when-updating) を参照。

## customファイルの作成基準

customファイルを作るかどうかは、次の1点だけで判断する。

> **コードベースに実在するパターンを、具体的なファイルパス付きで挙げられるか。**

- 証拠を挙げられるドメインは、数の上限なくすべて作成する
- 証拠を挙げられないドメインは作成しない。「あった方が良さそう」という一般論のベストプラクティス集を書かない
- 分量の目安は設けない。実在する証拠の量に文書量を従わせる (パターンが豊富なドメインは長く、薄いドメインは短く)
- 1ファイル1ドメインとし、coreファイルと内容を重複させない

### customテンプレート

以下のドメインは [`references/steering_custom/`](references/steering_custom) にテンプレートがある。該当があれば起点にし、プロジェクトの実態に合わせて書き換える。

| ドメイン                                                            | 内容                                    |
| ------------------------------------------------------------------- | --------------------------------------- |
| [`api-standards.md`](references/steering_custom/api-standards.md)   | REST/GraphQL規約、エラー形式            |
| [`testing.md`](references/steering_custom/testing.md)               | テスト構成、mock、カバレッジ            |
| [`security.md`](references/steering_custom/security.md)             | 認証パターン、入力検証、secret          |
| [`database.md`](references/steering_custom/database.md)             | スキーマ設計、migration、クエリパターン |
| [`error-handling.md`](references/steering_custom/error-handling.md) | エラー型、ログ、retry戦略               |
| [`authentication.md`](references/steering_custom/authentication.md) | 認証フロー、権限、session管理           |
| [`deployment.md`](references/steering_custom/deployment.md)         | CI/CD、環境、rollback手順               |

テンプレートの無いドメイン (例: i18n、ロギング、ジョブキュー) も、作成基準を満たすならテンプレートなしで作成してよい。

## 粒度の原則

> "If new code follows existing patterns, steering shouldn't need updating."
> (新しいコードが既存パターンに従う限り、steeringの更新は不要であるべき)

パターンと原則を記録する。網羅的なリストを記録しない。
詳細は [`references/steering_principles.md` の Content Granularity](references/steering_principles.md#content-granularity) を参照。

- **Bad**: ディレクトリツリーの全ファイルを列挙する
- **Good**: 構成パターンを例付きで記述する

## 調査方針

ファイル探索・読み込み・パターン検索は必要になった時点で行う (JIT)。最初にすべてを読み込まない。

## 出力

チャットにはサマリのみを出す (ファイルは直接更新する)。
customファイルは確認なしで作成する代わりに、**それぞれの根拠となったファイルパスを必ずサマリに列挙**し、事後レビューで削除できるようにする。

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
- decisions.md D-001 (Kind: adr) — 由来: PR #42
- decisions.md D-002 (Kind: adr) — 由来: Issue #17

レビューし、Source of Truthとして承認してください。不要なcustomファイルを指摘してください。判断の変更は履歴を残して追記します。
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
- decisions.md D-003 (Kind: adr) — 由来: PR #88

## Code Drift:
- import規約に従っていないコンポーネントあり
- src/orders/ が decisions.md D-001 (event-sourced) に反して直接UPDATEしている
```

## Safety & Fallback

- **Security**: API key、パスワード、secretは絶対に書かない ([`references/steering_principles.md` の Security](references/steering_principles.md#security) を参照)
- **Uncertainty**: steeringとコードのどちらが正か判断できない場合は、両方の状態を報告してユーザーに確認する
- **Preservation**: 迷ったら置換ではなく追記する
- **Custom**: 証拠の有無が判断できないドメインは作成せず、サマリで「見送ったドメインと理由」として報告する
- **判断履歴**: 理由が明文でない履歴から判断を捏造しない。ADRの3条件が確認できない判断はKind: decisionとし、採択自体が不確かな案はtentativeにする

## Notes

- `.mjun/steering/*.md` はすべてプロジェクトメモリとして読み込まれる
- パターンを書き、カタログを書かない
- **Golden Rule**: 既存パターンに従う新コードのためにsteeringの更新が必要になってはいけない
- agent固有のツールディレクトリ (`.claude/`, `.codex/`, `.gemini/` など) や `.mjun/` 配下のメタ情報のカタログはcore / customに書かない。decisions.mdのSource / Evidenceには判断をたどるためのspecパスを記録してよい
- `CONTEXT.md` と `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) の本文は追記で保持する。決定のStatus / Owner更新とEvidence追記の例外は共通記録規則に従う。コードから再生成しない
