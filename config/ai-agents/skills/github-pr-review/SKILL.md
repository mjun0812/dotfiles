---
name: github-pr-review
description: GitHubのpull request(PR)のコードレビューを行うSkill。worktreeを作成してソースコード全体を読みながら専門Reviewer SubAgentを並列実行し、統合されたレビューレポートとインラインコメントを投稿する。self reviewにも対応する。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*), Bash(bash:*), Bash(mktemp:*), Read, Write
---

# Pull Request Review

PRのhead commitを worktree にチェックアウトし，専門Reviewer SubAgent を並列実行する．各 SubAgent はworktree内の実際のソースコードを参照しながらレビューを行う．結果を統合してレビューレポートとMust Fix の項目を inline comment として投稿する．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)

## Task

### Phase 1: 対象 PR の特定と事前準備

1. **対象 PR の特定**:
   - **引数にPR番号が指定されている場合**: `gh pr view <number>` で対象PRを取得する
   - **引数なし**
     - **現在のブランチに紐づくopen PRが存在する場合**: そのPRをそのまま使用する（確認なし）
     - **現在のブランチに紐づくopen PRが存在しない場合**: RemoteのOpen PR一覧を取得し、`AskUserQuestion`でユーザーに対象PRを確認する
2. **言語検出**:
   - `gh pr view <number> --json title,body` で取得した PR のタイトル・本文を分析して言語を検出する（例: 日本語、英語、中国語）
   - **重要**: すべてのレビューコメントとレポートは、検出された言語で記述すること
   - 言語が曖昧な場合は、英語をデフォルトとする
3. **レポートテンプレートの選択**:
   - Phase 1.2 で検出した言語に応じて、Phase 3.2.C で使うレビューレポートのテンプレートを決定する
     - 日本語: [`references/report-ja.md`](references/report-ja.md)
     - それ以外（デフォルトの英語含む）: [`references/report-en.md`](references/report-en.md)
   - 選択したテンプレートのパスを保持し、Phase 3.2.C で読み込んで使用する

### Phase 2: レビュー用 worktree の作成

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-review` を専用 worktree path とする。`<repo-name>` は `gh repo view --json name --jq '.name'` で取得する。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PR head と base branch を fetch する（`<base-ref-name>` は `gh pr view <number> --json baseRefName --jq '.baseRefName'`）:

   ```bash
   git fetch origin +pull/<number>/head:refs/pr-review/<number>/head
   git fetch origin +<base-ref-name>:refs/pr-review/<number>/base
   ```

4. PR の `headRefName` を専用 worktree に checkout し、worktree 内の branch が PR head branch であることを確認する。
5. Phase 3 以降のレビュー対象ソースの参照は、すべて `<worktree-path>` 配下で行う。
6. **worktree 作成に失敗した場合**: エラーをユーザーに表示して中断する（worktree なしのレビューは品質が大きく落ちるため，フォールバックは行わない）

### Phase 3: Review

Reviewは各専門観点ごとに分かれたPR Review SubAgentを並列に実行して、その結果を統合する形で行う。

#### Phase 3.1: SubAgentの実行

SubAgent ツールを使い，以下のReview SubAgentを**すべて同時に並列起動**する。
各Review SubAgentには以下の情報を渡す:

- PRのタイトル・本文
- PR全体の変更サマリ（changedFiles / additions / deletions）
- worktree のパス(絶対パス)
- base branch と head branch の最新 commit SHA
- 使用言語（検出された言語）

起動するSubAgentは以下の5つで、レビューカテゴリごとに特化した観点でレビューを行う。

- `pr-reviewer-code-quality`: 命名・可読性・設計・エラーハンドリング・型安全性
- `pr-reviewer-document`: README・コメント・docstring・型定義の文書化
- `pr-reviewer-performance`: 計算量・I/O・メモリ・N+1・キャッシュ・並列性
- `pr-reviewer-security`: 認証・認可・入力検証・秘密情報・インジェクション・依存性脆弱性（致命的なもののみ）
- `pr-reviewer-testing`: カバレッジ・テスト戦略・保守性・回帰防止・モック使用の妥当性

### Phase 3.2: Review SubAgentの結果を統合する

各 SubAgent の `[must]` / `[should]` / `[question]` を集約する。

- 同じ `filepath:line`への指摘は1項目に統合する
- 統合時の category は `[must]` > `[should]` > `[question]` の順で重い評価を優先する（例: `[must]` と `[should]` が重複する場合は `[must]` として統合する）
- SubAgent ごとの reviewer カテゴリは複数併記する（例: `[must] [code-quality / security]`）
- `理由` / `対応` はすべての指摘を統合する。
- 「PR の目的に直接関係しない好み・スタイル指摘」は除外（例: PR が docs 変更なのにコード品質の細部指摘）
- [must] / [should]への昇格・降格は行わない。レビュワーの判断を尊重する。

#### Phase 3.3: レビューレポートに記述するVerdictの判定

- `[must]` が 1 件以上 → `REQUEST_CHANGES`
- `[must]` が 0 件 → `APPROVE`

**重要**: レビューレポートに記述するVerdictは `APPROVE` / `REQUEST_CHANGES` の 2 択のみ。`COMMENT` は使用しない（self review でも同様）。self reviewでは、GitHub API への投稿は `COMMENT` とするが、レポート本文のVerdict表記は `APPROVE` / `REQUEST_CHANGES` のままにする（GitHub の仕様で自分の PR に `APPROVE` / `REQUEST_CHANGES` は投稿できないため）。

### Phase 3.4: レビューレポートを生成する

Phase 1.3 で選択したレポートテンプレートを読み込み、その先頭コメントの記述ルールに従って埋める。プレースホルダ `<reviewer-name>` は実行中のレビュワー名（Claude Code 実行時は `Claude`）、`<short-sha>` は Phase 2.3 で取得した最新 commit SHA の先頭 7 文字に置換する。

### Phase 4: レビューを投稿する

レビューをGitHubに投稿する。レビューはinline commentとレビューレポート本文の2つの要素から構成される。
inline comment, レビューレポート本文ともに、GitHub API へ直接渡すのではなく、一時ファイルに保存してから `--body-file` / `--comments-file` で渡すこと。

#### Phase 4.1: inline commentsを作成

レポートの `## Must Fix` セクション配下の項目のみをinline comment化する。`Should Fix` / `Question` セクションの項目は inline 化しない（レポート本文記載のみ）。
各項目の直後に続くインデント済みの補助項目（`理由` / `対応` または `Reason` / `Action`）も同じ inline comment 本文に含める。

各項目を以下の JSON 形式に変換し，配列としてファイルに保存する（例: `/tmp/pr-review-comments.json`）。

```json
[
  {
    "path": "src/auth.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "🔴 [must] 1: **[security]** Issue summary\n\n理由: ...\n対応: ...\n\n---\nCommented by <reviewer-name>"
  }
]
```

`N:` は **レポート本文の `N:` 番号とそのまま一致させる**（再採番しない）。

JSON フィールド:

- `path`（必須）: 対象ファイルのパス（リポジトリルートからの相対）
- `line`（必須）: 対象行番号。`side` が `RIGHT`（既定）の場合は変更後ファイルの行番号，`LEFT` の場合は変更前ファイルの行番号
- `side`（任意, 既定 `RIGHT`）: `RIGHT` = 新規追加・変更後ファイル側，`LEFT` = 削除行・変更前ファイル側。reviewer 出力で `` `path:line (side=LEFT)` `` と明示されている場合のみ `LEFT` を設定する
- `body`（必須）: inline コメント本文

#### Phase 4.2: レビューレポート本文を作成

Phase 3.4 で生成したレビューレポートを一時ファイルに保存する。

#### Phase 4.3: レビューの種類を決定する

Review の種類（`APPROVE` / `REQUEST_CHANGES` / `COMMENT`）を決定する。レビューレポートのVerdictに基づいて、以下のルールで決定する。

- self review モードでは `--event COMMENT` を渡すが，body 内の Verdict 表記は元のまま（`APPROVE` または `REQUEST_CHANGES`）にする（GitHub の仕様で自分の PR に `APPROVE` / `REQUEST_CHANGES` は投稿できないため）。
- self review 以外の通常レビューでは、レビューレポートのVerdictが `APPROVE` → `--event APPROVE`、`REQUEST_CHANGES` → `--event REQUEST_CHANGES` を渡す

#### Phase 4.4: 既存レビュー ID のスナップショット取得（Phase 5.1 で使う）

**重要**: Phase 5.1 で新規投稿したレビューを誤って dismiss しないよう、必ず **投稿前にこの時点での既存レビュー ID 一覧を取得してメモリに保持する**。

```bash
gh api graphql -f query='{ viewer { login } }' --jq '.data.viewer.login'  # = <current_user>
gh api "repos/<owner>/<repo>/pulls/<number>/reviews" \
  --jq "[.[] | select(.user.login == \"<current_user>\") | select(.state == \"APPROVED\" or .state == \"CHANGES_REQUESTED\") | .id]"
```

取得した review id 配列を `<existing-review-ids>` として保持する。配列が空（初回レビュー）でも問題ない。

#### Phase 4.5: レビューの投稿

`scripts/post_review.sh` を呼び出してInline Commentsとレビューレポート本文を投稿する。
必要な引数を渡して、GitHub API 経由でレビューを投稿する。

```bash
bash <skill-dir>/scripts/post_review.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --commit "<latest-commit-sha>" \
  --event "<APPROVE|REQUEST_CHANGES|COMMENT>" \
  --body-file /tmp/pr-review-body.md \
  --comments-file /tmp/pr-review-comments.json
```

- 成功時は PR レビューの URL が標準出力に出力される
- スクリプトは `jq --rawfile` で本文ファイルを読み込み，`gh api --input <payload-file>` で投稿する。レビュー本文・inline comment 本文をシェル引数として直接渡さないこと
- **重要**: `gh pr review --body "..."`、`gh api -f body="..."`、シェル上で組み立てた JSON 文字列の直接渡しは禁止
- Inline Coments のルール:
  - inline comments がない場合は `--comments-file` を省略
  - 行番号は，`side` が `RIGHT`（既定）の場合は変更後ファイル（diff の右側）の行に，`LEFT` の場合は変更前ファイル（diff の左側）の行に対応していなければならない
  - `post_review.sh` は投稿前に PR の files API から各ファイルの patch を取得し，`(path, line, side)` が diff に含まれているかをプリフライト検証する。invalid なエントリは無視して、残りの inline 投稿は継続される（422 エラーで全件失敗するのを防ぐため）。降格件数は標準エラーに `Warning:` として出力される

### Phase 5: 既存レビューの後始末

Phase 4 の投稿が成功した後にのみ実行する。投稿が失敗した場合は何もしない（古いレビューを残すことで「新規レビューなし」の空白状態を回避する）。初回レビュー時は対象 0 で自然にスキップされる。

#### Phase 5.1: 既存レビューの dismiss

**重要**: 必ず Phase 4.4 で取得した `<existing-review-ids>`（投稿前のスナップショット）を `--review-id` で明示的に渡す。`--review-id` を渡さないと「投稿直後の自分の最新レビュー」までマッチしてしまい、たった今投稿したレビュー自身が dismiss される事故が起きる。

```bash
bash <skill-dir>/scripts/dismiss_my_reviews.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --review-id <id1> --review-id <id2>  # Phase 4.4 で取得したスナップショットを全て指定
```

`<existing-review-ids>` が空の場合は `--review-id` を 1 つも渡さず、スクリプト呼び出し自体をスキップしてよい（または `--review-id` 無しで呼び出すと「現時点の自分の全 APPROVED/CHANGES_REQUESTED」をフォールバックで dismiss するが、これは新規レビューも巻き込むため Phase 5 では使わない）。

スクリプトは指定された review id を REST API (`PUT /pulls/<n>/reviews/<id>/dismissals`) で順次 dismiss する。

#### Phase 5.2: 自分の outdated な inline comment を resolve する

過去のレビューで残っている自分の inline comment のうち、対象行が diff から外れた（outdated）かつ未 resolve のものを resolve する。

```bash
bash <skill-dir>/scripts/resolve_outdated_threads.sh \
  --repo "<owner/repo>" \
  --pr <number>
```

スクリプトは review thread を GraphQL で走査し、`isOutdated && !isResolved` かつ thread の最初のコメント author が認証ユーザーのものを `resolveReviewThread` mutation で resolve する。

### Phase 6: worktree のクリーンアップ

worktree と一時 ref を削除する:

```bash
git worktree remove --force <worktree-path>
git update-ref -d refs/pr-review/<number>/head
git update-ref -d refs/pr-review/<number>/base
```

**重要**: Phase 3 / Phase 4 / Phase 5 が例外的に中断した場合も，このクリーンアップは必ず実行する。`trap` のようなシェル機構ではなく，オーケストレーション側の制御フローで「中断 → 直ちに Phase 6 を実行」を保証する。
