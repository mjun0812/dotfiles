# Source Resolution

このskillが従う、正本と投影の規則。専用のindexや同期状態ファイルは持たず、specと実装状態は毎回この規則で解決する。

## 目次

- 原則: 正本は常にLocal、GitHubは投影
- Local specの配置
- ライフサイクル状態 (`status`)
- Contract承認状態 (`approval`)
- spec間の依存と境界
- `Source:` 行
- Context
- 取り込み (Issue → spec)
- 投影 (spec → Issue)
- 同期規則
- 用語集と決定記録 (steering配下の共通記録とCONTEXT.md)
- git管理と参照規則

## 原則: 正本は常にLocal、GitHubは投影

specの正本 (source of truth) は常に `.mjun/specs/<slug>/` である。GitHub Issueは入口 (取り込み) と出口 (投影) のアダプタであり、作業中にIssueを正本として読み書きしない。

```text
取り込み: Issue → .mjun/specs/<slug>/ へspec化
作業:     spec作成・task分解・実装のどの段階でもLocalのspec文書と共通の決定記録を読み書きする
投影:     承認後、Localのcontractを Issue本文へ反映 (Sourceを持つspecのみ)
配送:     worktreeで実装 → PR (SourceがあればCloses #N)
```

## Local specの配置

```text
.mjun/specs/<slug>/
├── spec.md          # 必須。人間が承認するcontract
├── design.md        # 必須。contract内の実装設計。承認前に書く
├── tasks.md         # taskと実装状態。実装開始後は単一taskでも持つ
├── prototype/       # artifact自体を一次資料として残す場合だけ
└── research/        # 外部調査が発生した場合だけ
```

- `<slug>` は内容を表す英語kebab-case。既存slugと衝突する場合は末尾に `-2`, `-3` を付ける
- 最初からすべては作らない。`spec.md` だけから開始できる
- frontmatterにはライフサイクル状態 `status: active | done` とcontract承認状態 `approval: pending | approved` を持つ。実装の対象になるのは `approval: approved` のspecだけである
- decision確定ごとの更新は常にLocalファイルへ逐次行う。task進捗は `tasks.md` の `Status`、resume先は同ファイルの `Implementation Branch` で管理する
- task分解は単一taskでも `tasks.md` を作る。分解を省略した単一taskでは、実装側がworktree作成後に同じ形式で作る
- `Implementation Branch` があり、そのlocal branchが存在すればtaskのstatusにかかわらずそのbranchからresumeする。branchが存在しない場合は記録を破棄して新規branchで続行する。done taskのAcceptance Criteriaが変わった場合は `ready` に戻し、再実装・再検証の対象にする

## ライフサイクル状態 (`status`)

specは増えていくため、堆積管理のためのライフサイクル状態をfrontmatterで持つ。

- 作成・取り込み時に `status: active` を書き、配送の完了時に実装側が `status: done` へ更新する
- 通常の一覧と進行中spec間の照合は `status: active` のspecを対象とする。Issue番号からの逆引きはactiveを優先し、見つからなければdoneも検索する。明示的にパスを渡されたspecはstatusを問わず読める
- 放棄したspecは手動でdoneにするか削除する
- `status` は堆積管理であり承認ゲートではない。contract承認は別の `approval` で管理する

## Contract承認状態 (`approval`)

- contractの作成・更新を始める前に `approval: pending` を書き、Phase 6で人間が「反映する」を選んだ後にだけ `approval: approved` へ更新する
- session中断、tool障害、明示的なキャンセルのいずれでも、承認が完了していないspecは `pending` のまま残る
- 実装側は `approval: approved` 以外のspecを受け付けない (spec外の単発Markdownを起点にする実装には適用しない)

### 一覧の手順

activeなspecの一覧は、索引ファイルを作らず毎回導出する。

```bash
grep -l "^status: active" .mjun/specs/*/spec.md   # activeなspecの列挙
grep -m1 "^# " <spec.md>                          # H1タイトル
grep -m1 "^Source: " <spec.md>                    # 投影先 (あれば)
```

## spec間の依存と境界

複数のspecが同時にactiveになり、別々の会話 (別のagent) で並行して実装されることを前提にする。

- 他のactive specの成果に依存するspecは、BoundariesのDependenciesに `spec: <slug>` の行を書く。実装側はそのspecが `status: done` になるまで実装を開始しない
- 境界の重なり (Ownsの重なり、Public Contracts Affectedが同じ公開interfaceを指す、`design.md` のChange Outlineのdirectoryの重なり) は、spec作成時の調査とspec review、および状況表示で検出する。どちらのspecが所有するか、分割・統合するかは人間が決める (Human-owned)
- `design.md` のChange Outlineはmodule / directory単位で書き、ファイルは書かない。実装のreviewerはdiffのパスがこの範囲に収まるかを機械的に照合し、feature検証ではbranch全体で同じ照合を行う
- 配送の前に作業branchをbase branchの最新へrebaseし、全検査を再実行する。並行するspecの成果が先にmergeされている場合の衝突をここで拾う

## `Source:` 行

GitHub Issueから取り込んだspec (または投影時に投影先Issueを作ったspec) は、`spec.md` のH1直下に投影先への参照を1行持つ。

```markdown
# <Title>

Source: #123

## Context
```

- `Source:` 行が無いspecは純Local (投影しない)
- これはIssueへの**参照**であり、lifecycle状態ではない。snapshotや同期状態のファイルは作らない
- Issue番号からspecを逆引きするときは、**activeなspec** (`status: active`) の中から `Source: #<N>` を検索する。複数ヒットした場合は一覧を提示してユーザーに選んでもらい、選ばれなかった方の整理 (doneへの変更または統合) を促す
- activeでmissした場合はdoneのspecからも検索し、あれば実装済みの可能性と再開方法 (statusをactiveへ戻す、または取り込み直し) を案内する (未取り込みと誤認して取り込み直しへ誤誘導しない)

## 取り込み (Issue → spec)

- Issue本文とコメントを読み、spec.mdのcontract構成へ構造化する (slugはIssueタイトルから)。**取り込みを行うのはこのskillだけ**である
- **入口は常にこのskill**: task分解や実装に未取り込みのIssue番号が渡された場合、それらは中止してこのskillでの取り込みを案内する。Issueが直行で実装できる品質かの判断を取り込み側で肩代わりしない (trivialな依頼はPhase 1の「spec化が過剰なら直接実装を提示」で振り分ける)

## 投影 (spec → Issue)

`Source:` を持つspecは、contract承認後にIssue本文へ投影する。取り込んだIssueの元の本文は消さず、その下へ追記する。

- 投影範囲: contract (Context〜Out of Scope) + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes` + `tasks.md` があれば `## Tasks` (taskタイトルのチェックボックス一覧)
- Dependenciesの `spec: <slug>` は、そのspecに `Source: #M` があれば `#M` に置き換え、無ければ投影しない (specは内部文書)
- **task進捗は投影しない**。進捗は内部 (tasks.md) だけで管理し、外部からはPRで見える。実装はIssueへ一切書き込まない (Issueの `## Tasks` は承認時点のスナップショット)
- 本文の構成: 元の本文 → 区切り行 `<!-- projected-spec -->` → 投影範囲。本文に区切り行が無ければ本文全体を元の本文として残し、あれば区切り行より上を残して下だけを置き換える (再投影で元の本文が増えない)。投影時に作成したIssueは元の本文が無いため、区切り行から始める。Issueのタイトルは変更しない
- 書き換えは一時ファイル経由の一括更新 (`gh issue edit --body-file`) + 変更サマリの1コメント (body編集はwatcherに通知されないため)
- 却下案・検討経緯はIssueコメントへ記録する
- 純Local specは投影しない

## 同期規則

- 投影の直前に `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントがあれば内容を提示し、specへ取り込むかを確認する
- 区切り行より下が外部で編集されていても、投影は承認済みのLocal contractで上書きする (正本はLocal)。上書き内容は承認フローで提示済みのため、そこで差分に気付ける。区切り行より上 (元の本文) は上書きしない

## 用語集と決定記録

判断履歴とADRは `.mjun/steering/decisions.md` に集約する。存在しなければ記録時に作成する。形式は [decisions-template.md](decisions-template.md)、Scope・状態・追記規則は [用語集と決定記録](../../mjun-steering/references/glossary_and_adr.md) に従う。

spec.mdのH1直下の `Decisions: D-001, D-002` が、そのspecの判断への参照である。本文は複製せず、承認前のtentative検査とIssueへのDecision Log投影はこの参照先に限定する。projectのacceptedは共通方針として読み、無関係なspecのtentativeは対象に含めない。

用語集はrepo直下のCONTEXT.md、無ければ.mjun/CONTEXT.mdを使う。用語と既存のacceptedな判断に反する要求は、人間の判断で解決してからcontractへ反映する。

## git管理と参照規則

`.mjun/` はグローバルgitignoreによりgit管理外である。したがって:

- worktreeやPR checkoutには `.mjun/specs/` が**存在しない**。worktree内の作業からspec文書を参照・更新するときは、必ずメインrepositoryの絶対パスを使う。SubAgentへはspec内容をプロンプトに合成して渡し、worktree内のパスを読ませない
- specは**内部文書**である。PR本文・PRタイトル・commit messageなど外部向けの出力では、`.mjun/` 配下のパスやspecの存在に言及しない。外部へ見せるspecの参照はGitHub Issue (`Closes #N`) だけを使う
- PRレビュー側は、contractを「`--spec` 引数で明示されたsource → PR本文の `Closes #N` が指すIssue」の順で解決する。どちらも無ければContract観点をスキップする (Issue本文は承認時点の投影であり、最新の正本はLocal specにある)
- resumeとtask進捗の永続化は、`.mjun/` が残っている同一working tree上でのみ有効
- repo直下の `CONTEXT.md` はgit管理下にありworktreeにも存在する。共通の決定記録はgit管理外なのでメインrepositoryの絶対パスを使う。配送時のADR転記は行わない
