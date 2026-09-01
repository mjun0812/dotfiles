---
name: mjun-to-tasks
description: >-
  spec (`.mjun/specs/` のLocal spec、またはGitHub Issue) を、単独で検証可能なvertical sliceのtaskへ分解し、
  `.mjun/specs/` 配下の `tasks.md` へ永続化するSkill。
  通常はspecの承認後に自動で呼び出される。ユーザーが「taskに分解して」「分解をやり直して」と依頼したときや、
  specの変更後に再分解したいときに単体で使うこと。実装そのもの、およびspec本文の作成・修正には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, Task, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(ls:*), Bash(mkdir:*)
---

# mjun-to-tasks

specをtaskへ分解し、`.mjun/specs/<slug>/tasks.md` として永続化するSkill。分解はAgent-ownedの作業として承認なしで行い、保存前にcoverage検査とfresh contextのtask-plan reviewで分解全体を検査する。正本は常に `.mjun/specs/<slug>/` のLocal specとし、GitHub Issueは `Source: #N` で逆引きする入口としてだけ扱う (Issueを正本として読み書きしない)。

## Arguments

- `source` (必須): 分解対象。`.mjun/specs/<slug>` のLocal specディレクトリ、またはGitHub Issue番号 (`#123` / `123`)

呼び出し元から調査済みの文脈 (requirements、boundary、変更対象の見当) を渡された場合はそれを使い、specの読み直しを最小にする。

### source解決

1. `.mjun/specs/<slug>` のパス → そのspecを対象にする
2. Issue番号 → activeなspec (`status: active`) から `Source: #<number>` を逆引きする (複数ヒットした場合は一覧を提示して選んでもらう)。無ければ中止し、先にIssueをLocal specへ取り込む必要があることを案内する (取り込みはspec作成側の仕事で、このskillでは行わない)
3. 判定できない場合は中止してユーザーに確認する

対象specのRequirements・Acceptance Criteriaを読み取れない場合、または `design.md` が無い場合は中止し、specの磨き上げが先に必要であることを案内する。

## 分解規則

- **vertical slice**: 各taskは、DB・API・UIのようなlayer別ではなく、単独で検証・デモできるend-to-end behaviorにする。horizontal layerのtaskを作らない
- **大きさ**: 1 taskは1つのfresh contextで実装しきれる大きさにする。「収まるか」は次の条件で判定する
  - **検証可能なdeliverableを1つ持つ**: taskのAcceptance Criteriaを、1つの失敗コマンド (テスト、スクリプト、CLI呼び出し) でredにできる。できなければ複数taskに分ける。これは検証可能性の条件であってサイズの上限ではない (巨大な機能も1本のE2Eテストでredにできる)
  - **変更が1 moduleに収まる**: そのコマンドをgreenにする変更が `design.md` のModulesのうち1つに収まる。複数moduleへ及ぶ場合は分割するか、統合taskとして明示する
  - **1つの責務に閉じる**: BoundaryはspecのOwnsのうち1つ。2つ以上に触るなら統合taskと明示し、触る責務の先行taskの後に置く
  - **前提を先行taskにする**: 型・設定・配線・整形 (prefactoring) が要るなら別taskにしてBlocked byで結ぶ。存在すると仮定しない
  - **数の目安**: AC ≤ 3、触る責務 = 1。超える場合と、変更ファイルが5〜6を超える見込みの場合は分割候補として扱う (数字はrepositoryに合わせて調整してよい)
- **分割と統合**: 独立に検証できる成果が2つ以上あるtaskは分割する。帳簿だけのtaskや単独で検証できないtaskは隣のtaskに統合する
- **属性**: 各taskにBoundary (specのOwns内のどの責務か)、Blocked by (先に完了が必要なtask)、Done when (完了時に観察できることを1行)、Seam (検証する公開interfaceを1行。`design.md` の Interfaces & Seams から取る。CLI全体や1つのendpointのようなcompositeな境界でもよい。実装時にはここに対して検査が書かれる)、Acceptance Criteria (機械的に判定できるcheckbox) を付ける
- **記述**: task本文にファイルパス、関数名、コード断片を書かない (実装の間に腐るため)。振る舞いとSeamで書く。Acceptance Criteriaは「操作 → 観察できる結果」の形で、1件が1つの検査コマンドに落とせるように書く
- **wide refactorの例外**: 1つの機械的変更のblast radiusがコードベース全体へ及ぶ場合だけvertical slice以外の分割を許可する。ただし旧形と新形を併存させる互換レイヤーや段階移行は作らない。各taskを独立に検証できる単位へ分けられない場合は、変更全体を1taskとして扱う。既存データを保護する必要があるDB変更だけは、repositoryの規約に従って安全なmigrationへ分解してよい
- **依存検査**: Blocked byのグラフにcycleが無いことを確認する。cycleがあればtaskの切り方を見直す
- **単一task**: 分解して1 taskにしかならない場合も、実装状態とresume先を複数taskと同じ形式で永続化できるよう、spec全体を表す1つのtaskとして `tasks.md` へ書く

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

- `Status` は `ready | in-progress | blocked | done`。新規taskは `ready` とする。`blocked` のtaskには `Blocked reason` と `Resume when` を追加する
- 統合taskは `Boundary: <責務A>, <責務B> (integration)` と書く
- 実装時のresumeと進捗管理に使われるため、この形式を崩さない
- 実装側が初回worktreeの作成後、選択したbranchを `Implementation Branch: <branch-name>` としてファイル先頭へ記録する。このskillは新規作成時にはこの行を書かない

## 手順

1. source解決に従って対象specを確定し、`spec.md` と `design.md` を読む
2. 分解規則に従ってtask一覧のdraftを作る
3. 依存グラフ (Blocked by) を確認し、実装順に並べる
4. **coverage検査**: draftに対して次の対応表を内部生成し、未カバーと重複をdraftの修正で解消する (修正と再検査は最大2周)。対応表はtasks.mdへ書かない
   - specのAcceptance Criteria 1件ごと → それを含むtaskがちょうど1つある (どのtaskにも無い、または複数taskに重複していれば修正する)
   - specのRequirements 1件ごと → 実現するtaskが1つ以上ある
   - `design.md` のModules (新設・変更) 1件ごと → いずれかのtaskのBoundaryが触る
   - `design.md` のInterfaces & Seamsのうち、specのAcceptance Criteriaが観測するもの1件ごと → いずれかのtaskのSeamに現れる (ACが観測しないinterfaceと、差し替える依存点は対象外)
   - `design.md` のData Flowでmodule境界をまたぐ箇所ごと → 統合taskで検証される、または単一taskの中で完結する
   - taskが前提とする型・設定・配線ごと → 先行taskとして存在する、または既存コードに存在する
   - 2周の修正後も残る未カバーは、task分解では解消できないspec / designの穴として扱う。中止して未カバー一覧を報告し、specの磨き直しが先に必要であることを案内する
5. **task-plan review**: draftが2 task以上の場合、[templates/reviewer-prompt.md](templates/reviewer-prompt.md) に `spec.md` の全文、`design.md` の全文、draftのtask一覧を合成し、fresh contextのSubAgentを1体起動する。reviewerには読み取り (Read / Glob / Grep) だけを許可し、ファイルを変更させない。単一taskの場合は省略する (graphとして検査するものが無いため)
   - 出力の `## Task Plan Review` から `- VERDICT:` だけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する (作業したSubAgentを継続して求める。継続できなければreviewerを最初からやり直す。作業していないagentが返すブロックは捏造になる)
   - `NEEDS_REPAIR` の各指摘を、specと `design.md` の明文に照らして妥当なものだけdraftへ反映し、妥当でない指摘は捨てる。反映後は手順4のcoverage検査だけを再実行して閉じ、**再レビューはしない**
6. 分解結果を提示する: task一覧 (各taskのBoundary、AC数、Done when)、依存関係、coverage (specのAC数とカバー数)、reviewerのVERDICTと反映した指摘の件数 (省略した場合はその旨)、数の目安を超える分割候補、単一taskの場合はその旨
7. `.mjun/specs/<slug>/tasks.md` へTask形式で書き込む。新規作成時は末尾に空の `## Implementation Notes` と `## Run Log` セクションを置く。既存のtasks.mdがある場合は次を守って更新する:
   - doneのtaskはAcceptance Criteriaが変わっていない場合だけ、そのまま保持する
   - spec変更によりdone taskのAcceptance Criteriaが変わった場合は、変更後の基準へ更新して `ready` に戻す
   - in-progressのtaskは `ready` へ戻した上で置き換え対象に含める
   - blockedのtaskは、原因と再開条件が新しい分解でも有効なら `Blocked reason` と `Resume when` を保持する。分解によって原因が解消したと確認できる場合だけ `ready` へ戻す
   - 既存の `Implementation Branch:` は必ず保持する
   - 既存の `## Implementation Notes` と `## Run Log` は必ず保持する
8. 結果を報告する: task数、依存関係、書き込み先、coverage、reviewerのVERDICTと反映した指摘の件数、`ready` に戻したtask、保持したblocked task。呼び出し元がいる場合は手順6と同じ形式のtask一覧 (分割候補の印を含む) を返す
