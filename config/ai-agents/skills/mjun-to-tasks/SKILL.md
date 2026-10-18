---
name: mjun-to-tasks
description: >-
  spec (`.mjun/specs/` のLocal spec、またはGitHub Issue) を、単独で検証可能なvertical sliceのtaskへ分解し、
  `.mjun/specs/` 配下の `tasks.md` へ永続化するSkill。
  通常はspecの承認後と、実装中にtaskの再分解が必要になったときに自動で呼び出される。ユーザーが「taskに分解して」「分解をやり直して」と依頼したときや、
  specの変更後に再分解したいときに単体で使うこと。実装そのもの、およびspec本文の作成・修正には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(ls:*), Bash(mkdir:*), Bash(zsh:*)
---

# mjun-to-tasks

specを、実装者がtaskごとにfresh contextで着手し、単独で検証してcommitできる単位へ分解し、`.mjun/specs/<slug>/tasks.md` に永続化する。`tasks.md` はmjun-implementのキュー、進捗、resume先になる。そのため、分解の質と並んで、形式と既存の実装状態を壊さないことが重要である。分解はAgent-ownedの作業なので承認は取らず、レビューも挟まない。taskの切り方の誤りは、コードの無い分解を読み比べても確かめようがなく、実装中に大きすぎるtaskの再分解やBLOCKEDとして現れたときに直せるからである。

正本は `.mjun/specs/<slug>/` のLocal specである。GitHub Issueは `Source: #N` からspecを逆引きするためだけに使い、Issueを読み書きしない (Issueの取り込みはmjun-specifyの仕事)。

## Arguments

- `source` (必須): 分解対象。`.mjun/specs/<slug>` のLocal specディレクトリ、またはGitHub Issue番号 (`#123` / `123`)
- `--draft` (任意): 分解のdraftを `.mjun/specs/<slug>/tasks.draft.md` に書いて終える。`tasks.md` には書き込まない。mjun-specifyが承認前に使う。taskの件数を判断シートへ載せ、分解で見つかるspecの欠落を承認の前に直すためである

呼び出し元から次のものを渡されたら使う。

- 調査済みの文脈 (requirements、boundary、変更対象の見当): specの読み直しを最小にする
- 承認前に作ったdraft (`tasks.draft.md`): draftを作り直さず、draftの後に変わったspecとdesignの記述 (追加・変更されたAcceptance Criteriaなど) だけを反映する

### source解決

- `.mjun/specs/<slug>` のパス: そのspecを対象にする
- Issue番号: activeなspec (`status: active`) から `Source: #<number>` を逆引きする。複数見つかれば一覧を示して選んでもらう。無ければ、先にIssueをLocal specへ取り込む必要があると案内して中止する。`status: done` のspecは作業を終えた使い捨ての文書なので探さない
- 判定できない場合は、中止してユーザーに確認する

`spec.md` のRequirementsとAcceptance Criteriaを読み取れない場合と、`design.md` が無い場合は、分解の根拠が無い。中止して、specの磨き上げが先に必要だと案内する。

## 分解規則

目的は、各taskを「1つのfresh contextの実装者がそのtaskだけを読んで実装し、親の検査とレビューを通して1つのcommitにできる」単位にすることである。taskはmjun-implementの実装・レビュー・commitの単位になり、1つ増えるごとに、implementer、検査、reviewer、commitの固定コストが1回ずつ増える。分けたtaskをつなぐ準備のtaskが増えると、依存の連鎖も伸びる。だから、1つのcontextに収まるかぎり分けない。分けるのは、収まらないときだけである。1つの機能は1人の担当が持ち、検証できる単位でcommitを重ねる、というpstackの進め方に合わせている。

- **vertical slice**: 各taskは、DB・API・UIのようなlayer別ではなく、単独で検証・デモできるend-to-end behaviorにする。layer別に切ると、どのtaskも単独では振る舞いを示せず、検証が最後のtaskまで先送りになる
- **大きさ**: 1 taskの上限は、Acceptance Criteriaが24件までで、変更が1つのcontextで読み切れる量 (互いに関係の薄い大きな変更が並ばない) である。この上限は、mjun-implementがimplementerへ一度に渡す量と同じである。上限に収まるなら、`design.md` のModulesやspecのOwnsがいくつにまたがっても、独立に検証できる成果が複数あっても、1 taskにする。spec全体が上限に収まれば、spec全体を1 taskにする
- **分けるとき**: 上限を超える見込みのときだけ分け、分ける数は、上限に収まる範囲で最も少なくする。切れ目は、前のtaskが単独で検証でき、そこまでをcommitしてもビルドとテストが通るところへ置く。後のtaskは前のtaskの成果の上に積む
- **検証**: 各Acceptance Criterionを、1つの実行可能なコマンド (テスト、スクリプト、CLI呼び出し) で判定できるようにする。これは検証可能性の条件で、taskの大きさの上限ではない。実装前のREDは条件にしない
- **順序**: 依存順に1 taskずつ完了させたとき、どの時点でもビルドと型検査が通るようにする。実装者は自分のtaskしか見ないので、途中でビルドが通らない状態を残すと、後続taskの検証が濁る。具体的には次のとおり
  - 型・設定・配線・整形 (prefactoring) は、それを使う最初のtaskに含める。準備だけのtaskは作らない。準備だけでは振る舞いを検証できず、依存の連鎖も伸びる
  - 公開interfaceのシグネチャや型を変えるtaskには、既存の呼び出し側の追従を含める
  - 共有のlayout、既定値、設定のように他taskの検査の前提を変えるtaskは、その前提に依存するtaskより先に置く
  - Blocked byのグラフにcycleを作らない。cycleが出たら切り方を見直す
- **記述**: task本文はファイルパス、関数名、コード断片を書かず、振る舞いとSeamで書く。実装が進むと腐るためである。Acceptance Criteriaは「操作 → 観察できる結果」の形で、1件を1つの検査コマンドで判定できるように書く
- **wide refactorの例外**: 1つの機械的変更のblast radiusがコードベース全体へ及ぶ場合だけ、vertical slice以外の分割を許す。旧形と新形を併存させる互換レイヤーや段階移行は作らない。独立に検証できる単位へ分けられなければ、変更全体を1 taskにする。既存データを守る必要があるDB変更だけは、repositoryの規約に従って安全なmigrationへ分けてよい
- **単一task**: 1 taskにしかならない場合も、実装状態とresume先を同じ形で残すため、spec全体を表す1つのtaskとして `tasks.md` に書く

## Task形式

```markdown
## T-001: <単独で検証可能な振る舞いを表すタイトル>

- Status: ready
- Boundary: <責務名>
- Blocked by: none | T-NNN
- Done when: <完了時に観察できること>
- Seam: <検証する公開インターフェース>

### Acceptance Criteria

- [ ] <観察可能な振る舞い>
```

mjun-implementがこの形式を読んでキューとresume先にするので、見出し、フィールド名、値の語彙を変えない。形式は `scripts/check_spec_format.sh` が検査する。

- Status: `ready | in-progress | blocked | done`。新規taskは `ready`。`blocked` のtaskには `Blocked reason` と `Resume when` を足す
- Boundary: specのOwnsのうち、そのtaskが触る責務。複数なら `Boundary: <責務A>, <責務B>` とカンマで区切る
- Blocked by: 先に完了が必要なtask
- Done when: 完了時に観察できることを1行で
- Seam: 検証する公開interface。複数ならカンマで区切って1行に書く。`design.md` のInterfaces & Seamsから取る。CLI全体や1つのendpointのようなcompositeな境界でもよい。実装時にはここに対して検査が書かれる
- Acceptance Criteria: 機械的に判定できるcheckbox
- `Implementation Branch: <branch-name>`: 実装側が初回worktreeの作成後にファイル先頭へ記録する。このskillは新規作成時にこの行を書かない

## 手順

1. source解決で対象specを確定し、`spec.md` と `design.md` を読む。ADR (`docs/adr/` か `.mjun/steering/adr/` のうち、置き場所として決まっているほう) があれば、[共通記録規則](../mjun-steering/references/glossary_and_adr.md) に従って有効なものを読む。`Status: tentative` のdecisionと、superseded / deprecatedのADRは、確定した設計制約として扱わない
2. 分解規則に従ってtask一覧のdraftを作り、依存順に並べる。承認前に作ったdraftを渡された場合は、差分だけを反映する
3. **coverage検査**: spec・designの約束がどのtaskからも漏れず、各ACの担当が1つに決まっていることを確かめる。次の対応表を内部で作り、未カバーと重複をdraftの修正で解消する。修正と再検査は最大2周とし、対応表は `tasks.md` に書かない
   - specのAcceptance Criteria 1件ごと → それを含むtaskがちょうど1つある (0件なら誰も実装せず、2件以上なら完了判定が割れる)
   - specのRequirements 1件ごと → 実現するtaskが1つ以上ある
   - `design.md` のModules (新設・変更) 1件ごと → いずれかのtaskのBoundaryが触る
   - `design.md` のInterfaces & SeamsのうちspecのACが観測するもの1件ごと → いずれかのtaskのSeamに現れる (ACが観測しないinterfaceと、差し替える依存点は対象外)
   - `design.md` のData Flowでmodule境界をまたぐ箇所ごと → どれかのtaskのAcceptance Criteriaで検証される
   - taskが前提とする型・設定・配線ごと → 先行taskか既存コードに存在する

   2周の修正後も残る未カバーは、task分解では埋められないspec / designの欠落である。中止して未カバーの一覧を報告し、specの磨き直しが先に必要だと案内する

4. 下の「書き込み」に従ってファイルへ書き、`zsh <skill-dir>/scripts/check_spec_format.sh <spec-dir> <書いたtasksファイル>` で形式を検査する。taskの形式 (見出し、フィールド、Statusの語彙、Blocked byの実在と循環、AC件数) の指摘は直して再実行する (最大2周)。specやdesignの形式の指摘はこのskillでは直さず、結果の報告に含める
   - scriptが見るのは、mjun-implementが機械的に読む形式だけである。人が目で確かめると取りこぼしやすく、形式が崩れたまま渡すと実装側がキューを組めずに止まるので、検査はscriptに任せる
5. 結果を報告する。task一覧 (各taskのBoundary、AC数、Done when。変更ファイル数の見込みが多いものには分割候補の印)、依存関係、書き込み先、coverage (specのAC数とカバー数)、単一taskの場合はその旨、`ready` に戻したtask、保持したblocked taskを含める。mjun-specifyはこのtask一覧をそのまま利用者への提示に使う

## 書き込み

- 通常は `.mjun/specs/<slug>/tasks.md` へTask形式で書く。新規作成時は末尾に空の `## Implementation Notes` と `## Run Log` を置く
- `--draft` の場合は、代わりに `tasks.draft.md` へ同じ形式で書き (既存の `tasks.draft.md` は上書きする)、`tasks.md` には触れない
- 承認前に作ったdraftから `tasks.md` を書いた場合は、書き込み後に `tasks.draft.md` を削除する。残すと、どちらが現行の分解か分からなくなる

既存の `tasks.md` を更新するときは、実装済みの成果と実装側の記録を失わないことを優先する。このファイルには実装側が書いた進捗、branch、メモ、Run Logがあり、上書きで消すと復元できない。

- doneのtaskは、Acceptance Criteriaが変わっていなければそのまま保持する。spec変更でAcceptance Criteriaが変わった場合は、変更後の基準へ更新して `ready` に戻す
- in-progressのtaskは `ready` へ戻し、置き換え対象に含める
- blockedのtaskは、原因と再開条件が新しい分解でも有効なら `Blocked reason` と `Resume when` を保持する。分解によって原因が解消したと確認できる場合だけ `ready` へ戻す
- 既存の `Implementation Branch:`、`## Implementation Notes`、`## Run Log` は必ず保持する
