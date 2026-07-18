---
name: github-pr-review
description: >-
  GitHubのpull request(PR)のコードレビューを行うSkill。worktreeを作成してソースコード全体を読みながら専門Reviewer SubAgentを並列実行し、統合されたレビューレポートとインラインコメントを投稿する。self reviewにも対応する。
  ユーザーが「このPRをレビューして」のように依頼したら使うこと。PRの問題修正まで求められた場合はgithub-pr-fixを使う。
allowed-tools: Task, Read, Write, AskUserQuestion, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*), Bash(bash:*), Bash(mktemp:*)
---

# Pull Request Review

PRのhead commitを worktree にチェックアウトし，「mergeを止めるリスク」の種類ごとに分かれた Finder SubAgent を並列実行する．
Finder が出した Must Fix 候補は，1件ずつ verifier SubAgent が反証を試み，生き延びた指摘だけをレビューレポートと inline comment として投稿する．
GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)
- `--dry-run`: 統合レビューレポートとinline commentのプレビューをチャットに提示するのみで、`post_review.sh` 等の投稿スクリプト・dismiss・resolve操作を一切呼ばない(worktreeの後片付けは通常どおり行う)
- `--run-tests`: verifier に worktree 内でのテスト実行を許可する。PR が fork からのもの(head repo が別 owner)の場合は無効化して警告する。既定では worktree 内のコードを一切実行しない

## Task

### Phase 1: 対象 PR の特定と事前準備

1. **前提チェック**: `gh auth status` が失敗した場合は作業を停止し、認証を案内して終了する
2. **対象 PR の特定**:
   - **引数にPR番号が指定されている場合**: `gh pr view <number>` で対象PRを取得する
   - **引数なし**
     - **現在のブランチに紐づくopen PRが存在する場合**: そのPRをそのまま使用する(確認なし)
     - **現在のブランチに紐づくopen PRが存在しない場合**: RemoteのOpen PR一覧を取得し、`AskUserQuestion`でユーザーに対象PRを確認する。Open PRが1件もなければその旨を報告して終了する
3. **言語検出**:
   - `gh pr view <number> --json title,body` で取得した PR のタイトル・本文を分析して言語を検出する(例: 日本語、英語、中国語)
   - **重要**: すべてのレビューコメントとレポートは、検出された言語で記述すること
   - 言語が曖昧な場合は、英語をデフォルトとする
4. **レポートテンプレートの選択**:
   - Phase 1.3 で検出した言語に応じて、Phase 4.3 で使うレビューレポートのテンプレートを決定する
     - 日本語: [`references/report-ja.md`](references/report-ja.md)
     - それ以外(デフォルトの英語含む): [`references/report-en.md`](references/report-en.md)
   - 選択したテンプレートのパスを保持し、Phase 4.3 で読み込んで使用する

### Phase 2: レビュー用 worktree の作成

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-review` を専用 worktree path とする。`<repo-name>` は `gh repo view --json name --jq '.name'` で取得する。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PR head と base branch を fetch する(`<base-ref-name>` は `gh pr view <number> --json baseRefName --jq '.baseRefName'`):

   ```bash
   git fetch origin +pull/<number>/head:refs/pr-review/<number>/head
   git fetch origin +<base-ref-name>:refs/pr-review/<number>/base
   ```

4. 専用 worktree は、fetch済みの `refs/pr-review/<number>/head` を直接 checkout して作成する:

   ```bash
   git worktree add --detach <worktree-path> refs/pr-review/<number>/head
   ```

   `headRefName` は表示・報告用のメタデータとして扱い、checkout対象にはしない。fork PR や同名branchの衝突で別branchをレビューしないよう、worktreeの `HEAD` が `refs/pr-review/<number>/head` の commit SHA と一致することを確認する。
   このとき取得した PR head の最新 commit SHA を `<latest-commit-sha>` として保持し、Phase 4.3 と Phase 5.3 で使用する。

5. Phase 3 以降のレビュー対象ソースの参照は、すべて `<worktree-path>` 配下で行う。
6. **worktree 作成に失敗した場合**: エラーをユーザーに表示して中断する(worktree なしのレビューは品質が大きく落ちるため，フォールバックは行わない)

### Phase 3: Review

Reviewは2段構成で行う。
「mergeを止めるリスク」の種類ごとに分かれたFinder SubAgentを並列実行して修正候補を収集し、
候補1件ごとにVerifier SubAgentが反証を試みてfalse positiveを落とす。

#### Phase 3.1: レビュー前の情報収集

レビューに必要な情報を事前に収集する。

- PR のタイトル・本文、変更ファイル一覧、diff、コミットメッセージ
- レビューに関係するリポジトリ固有ルール(AGENTS.md、CLAUDE.md、README、docs/以下など)
- CI結果: `gh pr checks <number>` で取得する(失敗中のチェックがあると非0で終了するが、出力は利用して続行する)。失敗があればレポートの概要に1行で記載し、CIが既に検出している問題は Finder への「重複指摘禁止」リストに加える
- 既存レビュースレッド: 未resolveのスレッドと会話を取得し、作者が既に対応・反論・却下した論点の一覧を作る。この一覧を Finder に「議論済みの論点。蒸し返さない」として渡す

  ```bash
  gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){
    repository(owner:$owner,name:$repo){pullRequest(number:$pr){
      reviewThreads(first:100){nodes{isResolved path line
        comments(first:20){nodes{author{login} body}}}}}}}' \
    -f owner=<owner> -f repo=<repo> -F pr=<number> \
    --jq '.data.repository.pullRequest.reviewThreads.nodes | map(select(.isResolved | not))'
  ```

既存レビューを後で dismiss して新規レビューとして更新するため、
投稿前のこの時点で自分の `APPROVED` / `CHANGES_REQUESTED` レビュー ID 一覧を取得し、`<existing-review-ids>` として保持する。
配列が空(初回レビュー)でも問題ない。

```bash
current_user="$(gh api graphql -f query='{ viewer { login } }' --jq '.data.viewer.login')"
gh api "repos/<owner>/<repo>/pulls/<number>/reviews" \
  --jq "[.[] | select(.user.login == \"${current_user}\") | select(.state == \"APPROVED\" or .state == \"CHANGES_REQUESTED\") | .id]"
```

#### Phase 3.2: Finder SubAgentの選択と実行

PRの変更内容に関係するFinder SubAgentを選択して並列起動する。
起動対象は Phase 3.1 で収集した情報から判断する。
判断に迷う場合は関連しそうなSubAgentを広めに起動する。
大規模変更・横断変更・影響範囲が不明な変更では全 Finder を起動してよい。
SubAgent機能が使えない環境では、各観点のレビューをメイン会話内で順に実施する。

起動可能なFinder SubAgentは以下の5つで、それぞれが「mergeを止めるリスク」への問いを1つ持つ。

- `pr-reviewer-correctness`: この変更は主張どおりに動くか。既存の挙動を壊さないか
- `pr-reviewer-integration`: 呼び出し元・API利用者・既存データ・設定はこの変更後も生きているか
- `pr-reviewer-security`: この差分は悪用可能な脆弱性を導入したか
- `pr-reviewer-reliability`: 本番でこのコードは倒れないか(N+1・リーク・無制限増加・リトライ嵐)
- `pr-reviewer-test-evidence`: このPRは自分が正しいことを証明しているか(回帰テスト・assertion弱体化)

各 Finder には以下の情報を渡す:

- PRのタイトル・本文
- PR全体の変更サマリ(changedFiles / additions / deletions)
- 起動対象に選んだ理由
- worktree のパス(絶対パス)
- base branch と head branch の最新 commit SHA
- 使用言語(検出された言語)
- CI結果のサマリと、CIが検出済みの問題の「重複指摘禁止」リスト(Phase 3.1)
- 既存レビューで議論済みの論点一覧(Phase 3.1。「対応済み・議論済みの論点。蒸し返さない」と明示する)
- 全指摘に、問題へ実際に到達する実行パス(`file:line` の連鎖)を `証拠` として必須で付けること

#### Phase 3.3: 候補選別と敵対的検証

**指摘候補選別**: 各Finderの出力から指摘候補を確定する。

- Finder の `[must]` はそのまま候補とする
- `[should]` / `[question]` は、「このまま merge してはいけない」と判断できる根拠が揃っている場合のみ候補へ昇格させ、それ以外は破棄する
- 候補は以下をすべて満たすこと: PRのdiffが導入・露出した問題である / `証拠` の実行パスがある / 影響が具体的である / `確度` が `high` または `medium` である
- verifier の起動前に、同じ `filepath:line` または同じ根本原因の候補を1件にまとめる(reviewer カテゴリと補助項目は統合して残す)

**敵対的検証**: 候補1件ごとに `pr-reviewer-verifier` を並列起動して反証を試みる。

- 選別の結果、候補が0件ならこのステップをスキップする
- 各 verifier には、候補1件の全文(証拠チェーン含む)、worktree のパス、PRのタイトル・本文、base / head の commit SHA、テスト実行の許可有無を渡す
- テスト実行は `--run-tests` が指定され、かつ fork PR でない(`gh pr view <number> --json isCrossRepository` が false の)場合のみ許可する。それ以外は「worktree 内のコードを一切実行しない」と明示して渡す
- verdict が `confirmed` の候補のみ通過させる。`refuted` / `uncertain` は破棄し、件数を記録して Phase 8 で報告する
- SubAgent機能が使えない環境では、verifier の検証手順をメイン会話内で候補ごとに順に実施する

### Phase 4: レビュー結果の統合とレポート生成

#### Phase 4.1: 検証を通過した指摘を統合する

最終レビューのに載せてよいのは、Phase 3.3 で verifier が `confirmed` と判定した指摘のみ。それ以外は最終レビューに出さない。

統合時は以下を行う。

- 同じ `filepath:line` または同じ根本原因の指摘が残っていれば 1 件にまとめる
- reviewer カテゴリと `理由` / `影響` / `対応` (`Reason` / `Impact` / `Action`)は統合して残す
- verifier の「修正案の評価」を反映し、`対応` をより小さく確実な修正に磨く

#### Phase 4.2: レビューレポートに記述するVerdictの判定

- 指摘事項が1件以上 → `REQUEST_CHANGES`
- 指摘事項が0件 → `APPROVE`

**重要**: レビューレポートに記述するVerdictは `APPROVE` / `REQUEST_CHANGES` の 2 択のみ。`COMMENT` は使用しない(self review でも同様)。
GitHub API へ渡すevent種別は Phase 5.2 で決定する。

#### Phase 4.3: レビューレポートを生成する

Phase 1.4 で選択したレポートテンプレートを読み込み、その先頭コメントの記述ルールに従って埋める。
プレースホルダ `<reviewer-name>` は実行中のレビュワー名(Claude Code 実行時は `Claude`)、`<short-sha>` はPhase 2 で取得した最新 commit SHA の先頭 7 文字に置換する。
Phase 3.1 で取得した CI に失敗がある場合は、概要にその旨を1行含める。

### Phase 5: レビューを投稿する

レビューをGitHubに投稿する。レビューはinline commentとレビューレポート本文の2つの要素から構成される。
inline comment, レビューレポート本文ともに、GitHub API へ直接渡すのではなく、
一時ファイルに保存してから `--body-file` / `--comments-file` で渡すこと。

`--dry-run` が指定された場合は、Phase 4.3 で生成した統合レビューレポートと Phase 5.1 で作成した inline comment のプレビューをチャットに提示し、
`post_review.sh` 等の投稿スクリプトを呼ばずに Phase 6 をスキップして Phase 7 に進む。

#### Phase 5.1: inline commentsを作成

レポートの `## Must Fix` セクション配下の項目のみをinline comment化する。最終レビューに `Should Fix` / `Question` セクションは存在しない。
各項目の直後に続くインデント済みの補助項目(`理由` / `影響` / `対応` / `確度` / `証拠` または `Reason` / `Impact` / `Action` / `Confidence` / `Evidence`)も同じ inline comment 本文に含める。

各項目を以下の JSON 形式に変換し，配列としてファイルに保存する(例: `/tmp/pr-review-comments.json`)。

````json
[
  {
    "path": "src/auth.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "🔴 [must] 1: **[security]** Issue summary\n\n理由: ...\n影響: ...\n対応: ...\n確度: high\n証拠: ...\n\n```suggestion\nconst token = sanitize(input);\n```\n\n---\nCommented by <reviewer-name>"
  }
]
````

`path` / `line` / `body` は必須。`side` は既定 `RIGHT` とし、削除行など変更前ファイル側にコメントする場合のみ `LEFT` を明示する。
`N:` は **レポート本文の `N:` 番号とそのまま一致させる**(再採番しない)。

**suggestionブロック**: 修正がコメント対象行1行の置換で完結し、かつ確実な場合のみ、本文の署名の前に GitHub の ` ```suggestion ` ブロックを含める(対象行を丸ごと置き換える内容を書く)。複数行にまたがる修正・確実でない修正は suggestion 化せず、`対応` にテキストで方針を書く(投稿スクリプトが `start_line` 未対応のため、複数行 suggestion は投稿できない)。

#### Phase 5.2: レビューの種類を決定する

Review の種類(`APPROVE` / `REQUEST_CHANGES` / `COMMENT`)を決定する。レビューレポートのVerdictに基づいて、以下のルールで決定する。

- self review モードでは `--event COMMENT` を渡すが，body 内の Verdict 表記は元のまま(`APPROVE` または `REQUEST_CHANGES`)にする(GitHub の仕様で自分の PR に `APPROVE` / `REQUEST_CHANGES` は投稿できないため)。
- self review 以外の通常レビューでは、レビューレポートのVerdictが `APPROVE` → `--event APPROVE`、`REQUEST_CHANGES` → `--event REQUEST_CHANGES` を渡す

#### Phase 5.3: レビューの投稿

Phase 4.3 で生成したレビューレポートを一時ファイルに保存する。
`scripts/post_review.sh` を呼び出してInline Commentsとレビューレポート本文を投稿する。
必要な引数を渡して、GitHub API 経由でレビューを投稿する。

```bash
bash "<skill-dir>/scripts/post_review.sh" \
  --repo "<owner/repo>" \
  --pr "<number>" \
  --commit "<latest-commit-sha>" \
  --event "<APPROVE|REQUEST_CHANGES|COMMENT>" \
  --body-file "/tmp/pr-review-body.md" \
  --comments-file "/tmp/pr-review-comments.json"
```

- 成功時は PR レビューの URL が標準出力に出力される
- スクリプトは `jq --rawfile` で本文ファイルを読み込み，`gh api --input <payload-file>` で投稿する。レビュー本文・inline comment 本文をシェル引数として直接渡さないこと
- **重要**: `gh pr review --body ...`、`gh api -f body=...`、シェル上で組み立てた JSON 文字列の直接渡しは禁止
- Inline Coments のルール:
  - inline comments がない場合は `--comments-file` を省略
  - 行番号は，`side` が `RIGHT`(既定)の場合は変更後ファイル(diff の右側)の行に，`LEFT` の場合は変更前ファイル(diff の左側)の行に対応していなければならない
  - `post_review.sh` は投稿前に PR の files API から各ファイルの patch を取得し，`(path, line, side)` が diff に含まれているかをプリフライト検証する。invalid なエントリは無視して、残りの inline 投稿は継続される(422 エラーで全件失敗するのを防ぐため)。降格件数は標準エラーに `Warning:` として出力される

### Phase 6: 既存レビューの後始末

Phase 5 の投稿が成功した後にのみ実行する。投稿が失敗した場合は何もしない(古いレビューを残すことで「新規レビューなし」の空白状態を回避する)。初回レビュー時は対象 0 で自然にスキップされる。

#### Phase 6.1: 既存レビューの dismiss

**重要**: 必ず Phase 3.1 で取得した `<existing-review-ids>`(投稿前のスナップショット)を `--review-id` で明示的に渡す。`--review-id` を渡さないと「投稿直後の自分の最新レビュー」までマッチしてしまい、たった今投稿したレビュー自身が dismiss される事故が起きる。

```bash
bash "<skill-dir>/scripts/dismiss_my_reviews.sh" \
  --repo "<owner/repo>" \
  --pr "<number>" \
  --review-id "<id1>" --review-id "<id2>"  # Phase 3.1 で取得したスナップショットを全て指定
```

`<existing-review-ids>` が空の場合は dismiss スクリプトを呼び出さない。

スクリプトは指定された review id を REST API (`PUT /pulls/<n>/reviews/<id>/dismissals`) で順次 dismiss する。

#### Phase 6.2: 自分の outdated な inline comment を resolve する

過去のレビューで残っている自分の inline comment のうち、対象行が diff から外れた(outdated)かつ未 resolve のものを resolve する。

```bash
bash "<skill-dir>/scripts/resolve_outdated_threads.sh" \
  --repo "<owner/repo>" \
  --pr "<number>"
```

スクリプトは review thread を GraphQL で走査し、`isOutdated && !isResolved` かつ thread の最初のコメント author が認証ユーザーのものを `resolveReviewThread` mutation で resolve する。

### Phase 7: worktree のクリーンアップ

worktree と一時 ref を削除する:

```bash
git worktree remove --force <worktree-path>
git update-ref -d refs/pr-review/<number>/head
git update-ref -d refs/pr-review/<number>/base
```

**重要**: Phase 3 / Phase 4 / Phase 5 / Phase 6 が例外的に中断した場合も，このクリーンアップは必ず実行する。`trap` のようなシェル機構ではなく，オーケストレーション側の制御フローで「中断 → 直ちに Phase 7 を実行」を保証する。

### Phase 8: 結果の報告

以下を簡潔にまとめてユーザーに提示して終了する:

- レビューURL(`post_review.sh` の標準出力。`--dry-run` 時は投稿していない旨を明記)
- Verdict(`APPROVE` / `REQUEST_CHANGES`)と Must Fix の件数
- verifier が棄却した候補の件数(`refuted` / `uncertain` の内訳)
- dismiss した既存レビューと resolve した outdated thread の件数(Phase 6 を実行した場合のみ)
