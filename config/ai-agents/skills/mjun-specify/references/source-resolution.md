# Source Resolution

specを扱うskill (mjun-specify / mjun-to-tasks / mjun-implement) が共有する、正本と投影の規則。状態ファイルは持たず、毎回この規則で解決する。

## 原則: 正本は常にLocal、GitHubは投影

specの正本 (source of truth) は常に `.mjun/specs/<slug>/` である。GitHub Issueは入口 (取り込み) と出口 (投影) のアダプタであり、作業中にIssueを正本として読み書きしない。

```text
取り込み: Issue → .mjun/specs/<slug>/ へspec化
作業:     specify / to-tasks / implement はLocalの4文書だけを読み書きする
投影:     承認後、Localのcontractを Issue本文へ反映 (Sourceを持つspecのみ)
配送:     worktreeで実装 → PR (SourceがあればCloses #N)
```

## Local specの配置

```text
.mjun/specs/<slug>/
├── spec.md          # 必須。人間が承認するcontract
├── decisions.md     # 非自明な意思決定が発生した場合だけ
├── design.md        # contractだけでは実装方針が伝わらない場合だけ
├── tasks.md         # 複数taskに分ける場合だけ
├── prototype/       # artifact自体を一次資料として残す場合だけ
└── research/        # 外部調査が発生した場合だけ
```

- `<slug>` は内容を表す英語kebab-case。既存slugと衝突する場合は末尾に `-2`, `-3` を付ける
- 最初からすべては作らない。`spec.md` だけから開始できる
- frontmatterやstatusフィールドは持たない。承認状態は保存せず、内容 (要確認の残留) で判定する
- decision確定ごとの更新は常にLocalファイルへ逐次行う。task進捗とresumeは `tasks.md` の `Status` だけの1系統とする

## `Source:` 行

GitHub Issueから取り込んだspec (または `--issue` で投影先を作ったspec) は、`spec.md` のH1直下に投影先への参照を1行持つ。

```markdown
# <Title>

Source: #123

## Context
```

- `Source:` 行が無いspecは純Local (投影しない)
- これはIssueへの**参照**であり、lifecycle状態ではない。snapshotや同期状態のファイルは作らない
- Issue番号からspecを逆引きするときは、`.mjun/specs/*/spec.md` の `Source: #<N>` を検索する

## 取り込み (Issue → spec)

- Issue本文とコメントを読み、spec.mdのcontract構成へ構造化する (slugはIssueタイトルから)
- `mjun-to-tasks` / `mjun-implement` に未取り込みのIssue番号が渡された場合は、**自動取込み**として機械的なspec化 (本文とコメントの構造化のみ。磨き・grill・調査はしない) を行ってから、内容検査で続行可否を判定する

## 投影 (spec → Issue)

`Source:` を持つspecは、contract承認後にIssue本文へ投影する。

- 投影範囲: contract (Context〜Out of Scope) + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes`
- **Tasksとtask進捗は投影しない**。進捗は内部 (tasks.md) だけで管理し、外部からはPRで見える。implementはIssueへ一切書き込まない
- 書き換えは一時ファイル経由の一括更新 (`gh issue edit --body-file`) + 変更サマリの1コメント (body編集はwatcherに通知されないため)
- 却下案・検討経緯はIssueコメントへ記録する
- 純Local specは投影しない

## 同期規則

- 投影の直前に `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントがあれば内容を提示し、specへ取り込むかを確認する
- 外部でIssue本文が編集されていても、投影は承認済みのLocal contractで上書きする (正本はLocal)。上書き内容は承認フローで提示済みのため、そこで差分に気付ける

## git管理と参照規則

`.mjun/` はグローバルgitignoreによりgit管理外である。したがって:

- worktreeやPR checkoutには `.mjun/specs/` が**存在しない**。worktree内の作業からspec文書を参照・更新するときは、必ずメインrepositoryの絶対パスを使う。SubAgentへはspec内容をプロンプトに合成して渡し、worktree内のパスを読ませない
- specは**内部文書**である。PR本文・PRタイトル・commit messageなど外部向けの出力では、`.mjun/` 配下のパスやspecの存在に言及しない。外部へ見せるspecの参照はGitHub Issue (`Closes #N`) だけを使う
- PRレビュー側は、contractを「`--spec` 引数で明示されたsource → PR本文の `Closes #N` が指すIssue」の順で解決する。どちらも無ければContract観点をスキップする (Issue本文は承認時点の投影であり、最新の正本はLocal specにある)
- resumeとtask進捗の永続化は、`.mjun/` が残っている同一working tree上でのみ有効
