# Source Resolution

specと実装状態を解決する規則。専用のindexや同期状態ファイルは持たず、毎回この規則で導出する。

## 原則: Localが正、GitHubは投影

specの実体は常に `.mjun/specs/<slug>/` である。GitHub Issueは取り込みと投影のアダプタであり、作業中にIssueを読み書きの対象にしない。

```text
取り込み: Issue → .mjun/specs/<slug>/ へspec化
作業:     spec作成・task分解・実装のどの段階でもLocalのspec文書とADRを読み書きする
投影:     承認後、Localのcontractを Issue本文へ反映 (Sourceを持つspecのみ)
配送:     worktreeで実装 → PR (SourceがあればCloses #N)
```

## Local specの配置

```text
.mjun/specs/<slug>/
├── spec.md          # 必須。人間が承認するcontract
├── design.md        # 必須。contract内の実装設計。承認前に書く
├── tasks.md         # taskと実装状態。承認後に作り、単一taskでも持つ
├── prototype/       # artifact自体を一次資料として残す場合だけ
└── research/        # 外部調査が発生した場合だけ
```

- `<slug>` は内容を表す英語kebab-case。既存slugと衝突する場合は末尾に `-2`, `-3` を付ける
- 最初からすべては作らず、`spec.md` だけから開始できる
- task進捗は `tasks.md` の `Status`、resume先は同ファイルの `Implementation Branch` で管理する。実装側はtaskを自分で分解せず、`tasks.md` が無ければ着手しない
- `Implementation Branch` のlocal branchが存在すれば、taskのstatusにかかわらずそこからresumeする。存在しなければ記録を破棄して新規branchで続行する。done taskのAcceptance Criteriaが変わった場合は `ready` に戻し、再実装・再検証の対象にする

## ライフサイクル状態 (`status`)

増えていくspecを整理するための状態で、承認とは別に管理する。

- 作成・取り込み時に `status: active` を書き、配送の完了時に実装側が `status: done` へ更新する
- 通常の一覧と進行中spec間の比較は `status: active` を対象とする。明示的にパスを渡されたspecはstatusを問わず読める
- 放棄したspecは手動でdoneにするか削除する

## Contract承認状態 (`approval`)

- `approved` へ更新するのは、Phase 5で人間が「反映する」を選んだ後だけである。session中断、tool障害、キャンセルのいずれでも、承認が完了していないspecは `pending` のまま残る
- 実装側は `approval: approved` 以外のspecを受け付けない (spec外の単発Markdownを起点にする実装には適用しない)

### 一覧の手順

activeなspecの一覧は、索引ファイルを作らず毎回導出する。

```bash
grep -l "^status: active" .mjun/specs/*/spec.md   # activeなspecの列挙
grep -m1 "^# " <spec.md>                          # H1タイトル
grep -m1 "^Source: " <spec.md>                    # 投影先 (あれば)
```

## spec間の依存と境界

複数のspecが同時にactiveになり、別々の会話で並行して実装される前提で扱う。

- 他のactive specの成果に依存するspecは、BoundariesのDependenciesに `spec: <slug>` の行を書く。実装側はそのspecが `status: done` になるまで実装を開始しない
- 境界の重なり (Ownsの重なり、Public Contracts Affectedが同じ公開interfaceを指す、`design.md` のChange Outlineのdirectoryの重なり) は、spec作成時の調査、spec review、状況表示で検出する。どちらのspecが所有するか、分割・統合するかは人間が決める (Human-owned)
- feature検証では、branch全体の変更パスが `design.md` のChange Outlineに収まるかを確かめる
- 配送の前に作業branchをbase branchの最新へrebaseし、すべてのチェックを再実行して、先にmergeされた並行specとの衝突を拾う

## `Source:` 行

GitHub Issueから取り込んだspec (または投影先Issueを作ったspec) は、`spec.md` のH1直下に投影先への参照を1行持つ。無いspecは純Local (投影しない) である。snapshotや同期状態のファイルは作らない。

```markdown
# <Title>

Source: #123

## Context
```

Issue番号からspecを逆引きするときは、activeなspecから `Source: #<N>` を検索する。

- 複数ヒットした場合は一覧を提示して選んでもらい、選ばれなかった方の整理 (doneへの変更または統合) を促す
- activeに無ければdoneからも検索し、あれば実装済みの可能性と再開方法 (activeへ戻す、または取り込み直し) を案内する。未取り込みと誤認して取り込み直しへ誘導しない

## 取り込み (Issue → spec)

- Issueを取り込むのはこのskillだけである。task分解や実装に未取り込みのIssue番号が渡された場合、それらは中止してこのskillでの取り込みを案内する
- Issueが直接実装できる品質かの判断を取り込み側で肩代わりしない (specが不要な依頼はPhase 0の振り分けで直接実装へ回す)

## 投影 (spec → Issue)

`Source:` を持つspecは、contract承認後に [issue-projection.md](issue-projection.md) に従ってIssue本文へ投影する。

## git管理と参照規則

`.mjun/` はグローバルgitignoreによりgit管理外であり、次のように扱う。

- worktreeやPR checkoutは `.mjun/` を含まない (skillが作るworktreeには作成直後に `<repo-root>/.mjun` へのsymlinkを張る)。worktree内の作業からspec文書を参照・更新するときは、メインrepositoryの絶対パスを使う。SubAgentへはspec内容をプロンプトに合成して渡し、worktree内のパスを読ませない
- specは内部文書である。PR本文・PRタイトル・commit messageなど外部向けの出力では、`.mjun/` 配下のパスやspecの存在に言及せず、specの参照にはGitHub Issue (`Closes #N`) だけを使う
- PRレビュー側は、contractを「`--spec` 引数で明示されたsource → PR本文の `Closes #N` が指すIssue」の順で解決し、どちらも無ければContract観点をスキップする (Issue本文は承認時点の投影であり、最新はLocal specにある)
- resumeとtask進捗の永続化は、`.mjun/` が残っている同一working tree上でのみ有効
- repo直下の `CONTEXT.md` はgit管理下にありworktreeにも存在する。ADRもGit管理へ移行済みなら作業中のworktreeの `docs/adr/` を使って変更をcommitに含め、未移行ならメインrepositoryの絶対パスを使う。配送時のADR転記は行わない
