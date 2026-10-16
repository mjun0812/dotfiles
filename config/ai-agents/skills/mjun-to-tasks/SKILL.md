---
name: mjun-to-tasks
description: >-
  spec (`.mjun/specs/` のLocal spec、またはGitHub Issue) を、単独で検証可能なvertical sliceのtaskへ分解し、
  `.mjun/specs/` 配下の `tasks.md` へ永続化するSkill。
  通常はspecの承認後と、実装中にtaskの再分解が必要になったときに自動で呼び出される。ユーザーが「taskに分解して」「分解をやり直して」と依頼したときや、
  specの変更後に再分解したいときに単体で使うこと。実装そのもの、およびspec本文の作成・修正には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, Task, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(ls:*), Bash(mkdir:*)
---

# mjun-to-tasks

specを、実装者がtaskごとにfresh contextで着手し、単独で検証してcommitできる単位へ分解し、`.mjun/specs/<slug>/tasks.md` に永続化する。`tasks.md` はmjun-implementのキュー、進捗、resume先になる。そのため、分解の質と並んで、形式と既存の実装状態を壊さないことが重要である。分解はAgent-ownedの作業なので承認は取らない。

正本は `.mjun/specs/<slug>/` のLocal specである。GitHub Issueは `Source: #N` からspecを逆引きするためだけに使い、Issueを読み書きしない (Issueの取り込みはmjun-specifyの仕事)。

## Arguments

- `source` (必須): 分解対象。`.mjun/specs/<slug>` のLocal specディレクトリ、またはGitHub Issue番号 (`#123` / `123`)
- `--draft` (任意): 分解のdraftを `.mjun/specs/<slug>/tasks.draft.md` に書いて終える。task-plan reviewと `tasks.md` への書き込みは行わない。mjun-specifyが、承認前のspec reviewでdraftを検査するために使う

呼び出し元から次のものを渡されたら使う。

- 調査済みの文脈 (requirements、boundary、変更対象の見当): specの読み直しを最小にする
- spec reviewを経たdraft (`tasks.draft.md`): draftを作り直さず、draftの後に変わったspecとdesignの記述 (追加・変更されたAcceptance Criteriaなど) だけを反映する。draftはspec reviewのtasks軸で検査済みなので、task-plan reviewは省く

### source解決

- `.mjun/specs/<slug>` のパス: そのspecを対象にする
- Issue番号: activeなspec (`status: active`) から `Source: #<number>` を逆引きする。複数見つかれば一覧を示して選んでもらう。activeに無くdoneのspecで見つかった場合は、「実装済みのspec (`<path>`) がある。再分解する場合は `status` を `active` へ戻す」と案内して中止する。どちらにも無ければ、先にIssueをLocal specへ取り込む必要があると案内して中止する
- 判定できない場合は、中止してユーザーに確認する

`spec.md` のRequirementsとAcceptance Criteriaを読み取れない場合と、`design.md` が無い場合は、分解の根拠が無い。中止して、specの磨き上げが先に必要だと案内する。

## 分解規則

目的は、各taskを「1つのfresh contextの実装者がそのtaskだけを読んで実装し、1つのコマンドで検証してcommitできる」単位にすることである。taskごとに実装・レビュー・検証・commitの固定コストがかかるため、この目的に必要な分だけ分け、それ以上は分けない。

- **vertical slice**: 各taskは、DB・API・UIのようなlayer別ではなく、単独で検証・デモできるend-to-end behaviorにする。layer別に切ると、どのtaskも単独では振る舞いを示せず、検証が最後のtaskまで先送りになる
- **大きさ**: 1つのfresh contextで実装しきれるかを、次の基準で判断する
  - taskのAcceptance Criteriaを、1つの実行可能なコマンド (テスト、スクリプト、CLI呼び出し) で検証できる。できなければ分ける。これは検証可能性の条件で、サイズの上限ではない (巨大な機能も1本のE2Eテストで検証できる)。実装前のREDは条件にしない
  - そのコマンドを通す変更が `design.md` のModulesの1つに収まり、BoundaryがspecのOwnsの1つに閉じる。2つ以上に及ぶなら分けるか、統合taskと明示して、触る責務の先行taskより後に置く
  - 数の目安は、ACが3〜6件、触る責務が1つ。ACの件数だけを理由に分割しない。ACが8件を超えるtaskと、変更ファイルが10を超える見込みのtaskは分割する (mjun-implementと実装時のverifierも同じ基準で大きすぎると判定し、再分解に戻ってくる)
- **分割と統合**: 独立に検証できる成果が2つ以上あるtaskは分ける。帳簿だけのtask、単独で検証できないtask、同じmoduleの同じSeamを検証して単独では小さな成果しか持たないtaskは、隣のtaskにまとめる
- **順序**: 依存順に1 taskずつ完了させたとき、どの時点でもビルドと型検査が通るようにする。実装者は自分のtaskしか見ないので、途中でビルドが通らない状態を残すと、後続taskの検証が濁る。具体的には次のとおり
  - 型・設定・配線・整形 (prefactoring) の前提は、存在すると仮定せず、先行taskにしてBlocked byで結ぶ
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

mjun-implementがこの形式を読んでキューとresume先にするので、見出し、フィールド名、値の語彙を変えない。

- Status: `ready | in-progress | blocked | done`。新規taskは `ready`。`blocked` のtaskには `Blocked reason` と `Resume when` を足す
- Boundary: specのOwnsのうちどの責務か。統合taskは `Boundary: <責務A>, <責務B> (integration)` と書く
- Blocked by: 先に完了が必要なtask
- Done when: 完了時に観察できることを1行で
- Seam: 検証する公開interfaceを1行で。`design.md` のInterfaces & Seamsから取る。CLI全体や1つのendpointのようなcompositeな境界でもよい。実装時にはここに対して検査が書かれる
- Acceptance Criteria: 機械的に判定できるcheckbox
- `Implementation Branch: <branch-name>`: 実装側が初回worktreeの作成後にファイル先頭へ記録する。このskillは新規作成時にこの行を書かない

## 手順

1. source解決で対象specを確定し、`spec.md` と `design.md` を読む。ADR (Git管理へ移行済みなら `docs/adr/`、それ以外は `.mjun/steering/adr/`) があれば、[共通記録規則](../mjun-steering/references/glossary_and_adr.md) に従って有効なものを読む。`Status: tentative` のdecisionと、superseded / deprecatedのADRは、確定した設計制約として扱わない
2. 分解規則に従ってtask一覧のdraftを作り、依存順に並べる。spec reviewを経たdraftを渡された場合は、差分だけを反映する
3. **coverage検査**: spec・designの約束がどのtaskからも漏れず、各ACの担当が1つに決まっていることを確かめる。次の対応表を内部で作り、未カバーと重複をdraftの修正で解消する。修正と再検査は最大2周とし、対応表は `tasks.md` に書かない
   - specのAcceptance Criteria 1件ごと → それを含むtaskがちょうど1つある (0件なら誰も実装せず、2件以上なら完了判定が割れる)
   - specのRequirements 1件ごと → 実現するtaskが1つ以上ある
   - `design.md` のModules (新設・変更) 1件ごと → いずれかのtaskのBoundaryが触る
   - `design.md` のInterfaces & SeamsのうちspecのACが観測するもの1件ごと → いずれかのtaskのSeamに現れる (ACが観測しないinterfaceと、差し替える依存点は対象外)
   - `design.md` のData Flowでmodule境界をまたぐ箇所ごと → 統合taskで検証されるか、単一taskの中で完結する
   - taskが前提とする型・設定・配線ごと → 先行taskか既存コードに存在する

   2周の修正後も残る未カバーは、task分解では埋められないspec / designの欠落である。中止して未カバーの一覧を報告し、specの磨き直しが先に必要だと案内する

4. **task-plan review**: 分解した会話の判断を共有しないreviewerに、1 taskだけを見ても分からないtask間の問題 (隠れた前提、順序、境界の重なり) を探させる。`--draft` の場合、spec reviewを経たdraftを渡された場合、draftが単一taskの場合 (graphとして検査するものが無い) は省く。それ以外は、[templates/reviewer-prompt.md](templates/reviewer-prompt.md) に `spec.md` の全文、`design.md` の全文、draftのtask一覧を合成し、fresh contextのSubAgentを1体起動する。reviewerには読み取り (Read / Glob / Grep) だけを許可する
   - 出力の `## Task Plan Review` から `- VERDICT:` を読む。構造化値が無い、または曖昧なら1回だけ再要求する。再要求は作業したSubAgentを継続して行い、継続できなければreviewerを最初からやり直す (作業していないagentが書いたブロックは捏造になる)
   - `NEEDS_REPAIR` の指摘は、specと `design.md` の明文に照らして妥当なものだけdraftへ反映し、残りは捨てる。反映後は手順3のcoverage検査だけを再実行して閉じ、再レビューはしない (指摘と修正の往復が収束しないため)
5. 下の「書き込み」に従ってファイルへ書く
6. 結果を報告する。task一覧 (各taskのBoundary、AC数、Done when。変更ファイル数の見込みが多いものには分割候補の印)、依存関係、書き込み先、coverage (specのAC数とカバー数)、reviewerのVERDICTと反映した指摘の件数 (省いた場合はその旨)、単一taskの場合はその旨、`ready` に戻したtask、保持したblocked taskを含める。mjun-specifyはこのtask一覧をそのまま利用者への提示に使う

## 書き込み

- 通常は `.mjun/specs/<slug>/tasks.md` へTask形式で書く。新規作成時は末尾に空の `## Implementation Notes` と `## Run Log` を置く
- `--draft` の場合は、代わりに `tasks.draft.md` へ同じ形式で書き (既存の `tasks.draft.md` は上書きする)、`tasks.md` には触れない
- spec reviewを経たdraftから `tasks.md` を書いた場合は、書き込み後に `tasks.draft.md` を削除する。残すと、どちらが現行の分解か分からなくなる

既存の `tasks.md` を更新するときは、実装済みの成果と実装側の記録を失わないことを優先する。このファイルには実装側が書いた進捗、branch、メモ、Run Logがあり、上書きで消すと復元できない。

- doneのtaskは、Acceptance Criteriaが変わっていなければそのまま保持する。spec変更でAcceptance Criteriaが変わった場合は、変更後の基準へ更新して `ready` に戻す
- in-progressのtaskは `ready` へ戻し、置き換え対象に含める
- blockedのtaskは、原因と再開条件が新しい分解でも有効なら `Blocked reason` と `Resume when` を保持する。分解によって原因が解消したと確認できる場合だけ `ready` へ戻す
- 既存の `Implementation Branch:`、`## Implementation Notes`、`## Run Log` は必ず保持する
