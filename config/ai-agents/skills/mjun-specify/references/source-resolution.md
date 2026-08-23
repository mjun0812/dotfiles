# Source Resolution

specを扱うskill (mjun-specify / mjun-to-tasks / mjun-implement) が、GitHub modeとLocal modeを同じ規則で解決するための定義。modeはどこにも保存せず、毎回この規則で解決する。

## mode選択規則

上から順に評価し、最初に該当したものを採用する。

1. `--local` がある → Local mode
2. `--github` がある → GitHub mode
3. sourceがIssue番号 (`#123` / `123`) またはGitHub URL → GitHub mode
4. sourceがMarkdownパスまたは `.mjun/specs/<slug>` のディレクトリパス → Local mode
5. sourceもflagもない → GitHubかLocalかを1回だけユーザーに聞く

矛盾する入力 (例: `#123 --local`) は中止してユーザーに確認する。後続skillへはIssue番号またはローカルパスを明示的に渡す。

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

## GitHub Issueとの対応

現在有効な情報だけをIssue本文に置き、決定の経緯はコメントへ分離する。

| Local        | GitHub Issue                                                                       |
| ------------ | ---------------------------------------------------------------------------------- |
| spec.md      | 本文のcontractセクション群 (Context〜Out of Scope)                                 |
| decisions.md | 本文の `## Decision Log` = 採用decisionの要約表。却下案・検討経緯はIssueコメントへ |
| design.md    | 本文の `## Design Notes` (現在有効な設計)                                          |
| tasks.md     | 本文の `## Tasks` checklist + `## Implementation Notes`                            |
| research/    | Issueコメント (要約 + 出典)                                                        |

Issue本文の書き換えは、承認後の一括更新 + 変更サマリの1コメントで行う (body編集はwatcherに通知されないため、コメントで通知を補う)。task checklistとImplementation Notesの更新は本文編集で行ってよい。

## git管理と参照規則

`.mjun/` はグローバルgitignoreによりgit管理外である。したがって:

- worktreeやPR checkoutには `.mjun/specs/` が**存在しない**。worktree内の作業からspec文書を参照・更新するときは、必ずメインrepositoryの絶対パスを使う。SubAgentへはspec内容をプロンプトに合成して渡し、worktree内のパスを読ませない
- specは**内部文書**である。PR本文・PRタイトル・commit messageなど外部向けの出力では、`.mjun/` 配下のパスやspecの存在に言及しない。外部へ見せるspecの参照はGitHub Issue (`Closes #N`) だけを使う
- PRレビュー側は、contractを「`--spec` 引数で明示されたsource → PR本文の `Closes #N` が指すIssue」の順で解決する。どちらも無ければContract観点をスキップする (Local specを読めるのは `.mjun/` を持つマシンだけ)
- resumeとtask進捗の永続化は、`.mjun/` が残っている同一working tree上でのみ有効
