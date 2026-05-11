---
name: github-pr-review
description: GitHubのpull request(PR)のコードレビューを行うSkill。worktreeを作成してソースコード全体を読みながら5つの専門レビュアーagentを並列実行し、統合レビューレポートとMust Fixのインラインコメントを生成する。self reviewにも対応する。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(mkdir:*), Bash(rm:*), Bash(test:*), Bash(basename:*), Bash(bash:*), Read
---

# Pull Request Review

PRのhead commitを worktree にチェックアウトし，5つの専門レビュアー agent を並列実行する．各 agent はworktree内の実際のソースコードを参照しながらレビューを行う．結果を統合してレビューレポートを生成し，ユーザーが投稿を承認した場合のみ Must Fix の項目を inline comment として投稿する．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)

## Task

### Phase 1: 事前チェック + PR情報収集 + worktree 作成

1. **事前チェック**:
   - **引数にPR番号が指定されている場合**: `gh pr view <number>` で対象PRを取得する
   - **引数なしで，現在のブランチに紐づく open PR が存在する場合**: そのPRをそのまま使用する（確認なし）
     - 判定方法: `gh pr view --json number,state 2>/dev/null` の終了コードと `state == "OPEN"` で判断する
   - **引数なしで，現在のブランチに紐づく open PR が存在しない場合**: AskUserQuestion でユーザーに対象PRを確認する
     - `gh pr list --state open --json number,title,headRefName,author --limit 20 --jq 'sort_by(.number) | reverse'` で最新の open PR 一覧を取得する
     - 取得した上位 PR を AskUserQuestion の選択肢として提示する（label例: `#123 Fix auth bug (feature/auth-fix)`）
       - 1件のみの場合: そのPRと「キャンセル」の2択
       - 2-3件: そのまま選択肢に並べる
       - 4件以上: 最新3件を提示し，4つ目は「キャンセル」（ユーザーは "Other" で任意のPR番号を直接入力できる）
     - open PR が0件の場合はエラーメッセージを表示して中断する
     - ユーザーが「キャンセル」を選択した場合は中断する

2. **PR情報を収集する**（worktree 作成前にこの順序で実行する）:
   - PRメタデータの取得: `gh pr view <number> --json title,body,baseRefName,headRefName,author,additions,deletions,changedFiles`
   - 変更ファイルメタデータの取得: `gh pr view <number> --json files --jq '.files[] | {path, additions, deletions}'`
   - **重要**: diff 全文はこの段階で取得しない。大きな PR で reviewer agent のコンテキストを圧迫するため，Phase 2 では変更サマリと worktree を渡し，各 agent が必要なファイル・差分だけを読む
   - 最新の commit SHA の取得: `gh pr view <number> --json commits --jq '.commits[-1].oid'`
   - PR head ref 名の取得: `gh pr view <number> --json headRefName --jq '.headRefName'`（後の `git fetch` で SHA fetch が失敗した場合の fallback として使用）
   - PR author の取得: `gh pr view <number> --json author --jq '.author.login'`
   - リポジトリの owner/repo の取得: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`

3. **言語検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語、中国語）
   - **重要**: すべてのレビューコメントとレポートは、検出された言語で記述すること
   - 言語が曖昧な場合は、英語をデフォルトとする

4. **既存レビューの確認**:
   - 現在の GitHub ユーザー名を取得: `gh api user --jq '.login'`
   - PRの既存レビュー一覧を取得: `gh api repos/{owner}/{repo}/pulls/{pull_number}/reviews --jq '.[] | select(.user.login == "<current_user>") | {id, state, submitted_at}'`
   - 自分の既存レビューがある場合は，その情報（レビューID，state，投稿日時）を Phase 3 で使用するために保持する

5. **self review 判定**:
   - PR author と現在の GitHub ユーザー名を比較する
   - 一致する場合は `is_self_review = true` を**メインオーケストレーション側で保持する**（reviewer agent には渡さない。Phase 3.5 の API event 変換でのみ使用）
   - GitHubの仕様上，自分のPRに対して `APPROVE` / `REQUEST_CHANGES` は投稿できないため，self review では API event を `COMMENT` に変換する必要がある（ただしレポート上の Verdict は 2択のまま）

6. **worktree の作成**:
   - レビュアー agent が実際のソースコードを参照できるよう，PRの head commit を worktree にチェックアウトする
   - リポジトリ名を取得: `gh repo view --json name --jq '.name'`
   - worktree のパス: `/tmp/claude-pr-review/<repo-name>-<pr-number>`（`/tmp` は再起動で消えるので一時用途専用）
   - 既存の worktree がある場合は事前に削除する: `git worktree remove --force <path> 2>/dev/null; rm -rf <path>`
   - head commit を fetch する:
     1. まず `git fetch origin <head-sha>` を試す
     2. 失敗した場合（サーバが `uploadpack.allowReachableSHA1InWant` を許可していないことがある）は `git fetch origin +<head-ref-name>:refs/claude-pr-review/<pr-number>` で ref 名 fetch する
   - base branch を fetch する: `git fetch origin +<base-ref-name>:refs/claude-pr-review/base-<pr-number>`（Phase 2 でファイル単位の差分を確認するため）
   - detached HEAD で worktree を作成する: `git worktree add --detach <path> <head-sha>`
     - detached を使う理由: ローカルブランチを作らず，後続のクリーンアップを単純化するため
   - worktree のパスを以降の Phase 2 / Phase 3 で使用するために保持する
   - **worktree 作成に失敗した場合**: エラーをユーザーに表示して中断する（worktree なしのレビューは品質が大きく落ちるため，フォールバックは行わない）
   - **重要**: worktree は Phase 4 (cleanup) で必ず削除する。Phase 2/3 で例外的に処理が中断した場合も Phase 4 を必ず実行する（trap などのシェル機構ではなく，オーケストレーション側で「Phase 2/3 のいずれかが中断したら直ちに Phase 4 を実行する」という制御フローにする）

### Phase 2: 5つのレビュアー agent を並列実行

Agent ツールを使い，以下の5つのagentを**すべて同時に並列起動**すること（複数の Agent ツール呼び出しを 1 つのアシスタントターンに含める）．

各 agent には以下の情報を渡す:

- PRの目的（タイトル・本文から1-2文で要約）
- PR全体の変更サマリ（changedFiles / additions / deletions）
- 変更ファイルメタデータ（path / additions / deletions）
- base 比較 ref（`refs/claude-pr-review/base-<pr-number>`）と head commit SHA
- **worktree のパス（絶対パス）**: agent はこのディレクトリ内のファイルを Read/Grep/Glob で参照し，必要に応じて `git -C <worktree-path> diff refs/claude-pr-review/base-<pr-number>...HEAD -- <path>` などで担当観点に関係する差分だけ確認する
- 使用言語（検出された言語）

各 agent への指示には [reviewer 共通指示テンプレート](#reviewer-共通指示テンプレート) を必ず含める．diff 全文を agent に渡してはいけない。重複防止のため，各 agent には「自分の専門観点（コード品質 / ドキュメント / パフォーマンス / セキュリティ / テスト）に直接関わる指摘のみ」を出すよう明示すること．

#### Agent 1: code-quality-reviewer (subagent_type: code-quality-reviewer)

コード品質の観点（命名・可読性・設計・エラーハンドリング・型安全性など）に限定してレビューしてください．パフォーマンスやセキュリティ・テストはそれぞれ専門 agent が担当するため重複指摘は避けてください．

#### Agent 2: documentation-accuracy-reviewer (subagent_type: documentation-accuracy-reviewer)

ドキュメントの正確性・完全性（README，コメント，docstring，型定義の文書化など）の観点に限定してレビューしてください．コード品質そのものには触れません．

#### Agent 3: performance-reviewer (subagent_type: performance-reviewer)

パフォーマンス（計算量，I/O，メモリ，N+1，キャッシュ，並列性など）の観点に限定してレビューしてください．

#### Agent 4: security-reviewer (subagent_type: security-reviewer)

セキュリティ（認証・認可，入力検証，秘密情報の扱い，インジェクション，依存性脆弱性など）の観点に限定してレビューしてください．致命的なもののみを上げるようにしてください。

#### Agent 5: testing-reviewer (subagent_type: testing-reviewer)

テスト（カバレッジ，テスト戦略，テストの保守性，回帰防止，モック使用の妥当性など）の観点に限定してレビューしてください．

### Phase 3: 結果統合 + レビューレポート生成

1. **5つの agent の結果を統合する**:
   - 各 agent の Must Fix / Should Fix / Question を集約する
   - **重複統合ルール**:
     - 同じ `filepath:line`（または同じファイル内の隣接行 ±2 行）への指摘は 1 項目に統合する
     - 統合時の重みは Must Fix > Should Fix > Question（より重い側に寄せる）
     - カテゴリは複数併記する（例: `[code-quality / security]`）
     - 文面は短い方を残しつつ，もう一方の固有情報があれば `Evidence`（日本語では `根拠`）または `Suggested fix`（日本語では `推奨対応`）に統合する
     - `Confidence`（日本語では `確信度`）は統合前の最も低い値に寄せる（例: High と Medium が混在する場合は Medium，日本語では高と中が混在する場合は中）
     - `Blocking reason`（日本語では `ブロック理由`）は Must Fix の場合のみ保持し，複数ある場合は `bug / security / data loss / regression / public API break / requirement gap`（日本語では `バグ / セキュリティ / データ破壊 / 回帰 / 公開APIの破壊的変更 / 要件未達`）の中から最も直接的な理由を1つ選ぶ
   - **ノイズ削減ルール**:
     - 「PR の目的に直接関係しない好み・スタイル指摘」は除外（例: PR が docs 変更なのにコード品質の細部指摘）
     - 同じ観点で 3 件以上のほぼ同種の指摘がある場合は，最も重要な 1 件に集約し残りは「他に類似 N 件」と一行でまとめる
     - `Evidence` が具体的なコード挙動・制御フロー・未検証入力・不足しているテストなどを説明できない指摘は Must Fix にしない
     - `Confidence: Low` の指摘は，レビュー判断に必要な確認事項として明確に書ける場合のみ Question に回す。実害が説明できない場合や任意提案に過ぎない場合は除外する

2. **Must Fix / Should Fix / Question の判定基準**:
   - **Must Fix**（=`REQUEST_CHANGES` をブロックする理由になるもの）: `Confidence: High`（日本語では `確信度: 高`）かつ `Evidence`（日本語では `根拠`）と `Blocking reason`（日本語では `ブロック理由`）が明確で，以下のいずれかに該当する場合のみ
     - バグで動作しない / クラッシュする / データを破壊する
     - セキュリティ上の脆弱性（秘密情報漏洩，認証回避，インジェクションなど）
     - 既存機能の明確な regression
     - 公開 API の破壊的変更が未告知
     - PR の目的を達成できていない（要件未充足）
     - `Blocking reason` は `bug` / `security` / `data loss` / `regression` / `public API break` / `requirement gap` のいずれかにする。日本語では `ブロック理由` を `バグ` / `セキュリティ` / `データ破壊` / `回帰` / `公開APIの破壊的変更` / `要件未達` のいずれかにする
     - `Confidence: Medium` 以下（日本語では `確信度: 中` 以下），または `Evidence` / `根拠` が曖昧な指摘は Must Fix にしない
   - **Should Fix**: 上記には当たらないが修正が望ましいもの（保守性・テスト不足・パフォーマンス改善余地・ドキュメント不足など）。**好み・スタイル・「より良い書き方」程度のものはここに含めず，確認が必要なものだけ Question へ**
     - `Confidence` は `High` または `Medium` にする。日本語では `確信度` を `高` または `中` にする
     - `Impact` / `Evidence` / `Suggested fix` を必ず記述する。日本語では `影響` / `根拠` / `推奨対応` を必ず記述する。修正価値が説明できないがレビュー判断に必要な不明点がある場合のみ Question に回し，そうでなければ出力しない
   - **Question**: レビュー判断に必要な確認事項のみ。任意提案・好みの改善案・実害が説明できない低確信度の指摘は含めない。日本語では `質問` として記述する
   - **判断に迷ったら Should Fix へ降ろす**（Must Fix は厳しめに絞る）

3. **Verdict の判定（2択）**:
   - Must Fix が1件以上 → `REQUEST_CHANGES`
   - Must Fix が0件 → `APPROVE`
   - **重要**: Verdict は `APPROVE` / `REQUEST_CHANGES` の2択のみ。`COMMENT` は使用しない（self review でも同様）。
     Should Fix のみが存在する場合でも `APPROVE` とする（指摘は本文に残るが、ブロックはしない）

4. **レビューレポートを生成する**:
   - 検出された言語に応じて [`references/templates/report-en.md`](references/templates/report-en.md) または [`references/templates/report-ja.md`](references/templates/report-ja.md) をテンプレートとして使用する
   - **重要**: "Must Fix" / "Should Fix" 項目は inline comment 抽出のため `` `filepath:line` - [category] description `` の形式を厳密に守ること（[Inline comments 抽出パターン](#ステップ-1-レポートから-inline-comments-を抽出する) と一致させる）
   - **重要**: 各 "Must Fix" / "Should Fix" 項目は先頭行の直下に `Impact` / `Evidence` / `Suggested fix` / `Confidence` を必ず記述すること。日本語テンプレートでは `影響` / `根拠` / `推奨対応` / `確信度` を使うこと。Must Fix にはさらに `Blocking reason`（日本語では `ブロック理由`）を記述すること
   - `Confidence` は `High` / `Medium` / `Low` のいずれかにする。日本語テンプレートでは `確信度` を `高` / `中` / `低` のいずれかにする。ただし Must Fix は `High` / `高` のみ，Should Fix は `High` / `高` または `Medium` / `中` のみにする
   - **重要**: "Must Fix" および "Should Fix" の全項目をレビューレポート本文に記載すること。「inline comments を参照」等の省略は禁止
   - **プレースホルダ置換**（[プレースホルダ一覧](#テンプレート内プレースホルダ) を参照）:
     - `<reviewer-name>` → 実行中のレビュワー名（Claude / Codex / GPT-5 など）
     - `<short-sha>` → Phase 1.2 で取得した最新 commit SHA の先頭 7 文字

5. **レビューレポートを表示する**:
   - 検出された言語でレビューレポートを表示する

6. **GitHub への投稿を確認する**:
   - Phase 1 で取得した既存レビュー情報に基づき，AskUserQuestion ツールでユーザーに確認する
   - **既存レビューがない場合**: 新規投稿するか／投稿しないかを確認する
   - **既存レビューがある場合**: 既存レビューの state と投稿日時を提示し，以下の選択肢を提供する:
     - 既存レビューを dismiss して新規レビューを投稿する（推奨: 既存が `REQUEST_CHANGES` で，内容が古い場合）
     - 既存レビューはそのままで新規レビューを追加する（既存レビューの指摘がまだ有効な場合）
     - 投稿しない
   - ユーザーが投稿を選択した場合は [scripts/post_review.sh](scripts/post_review.sh) を呼び出す。詳細は [Inline comments 付きレビューの投稿](#inline-comments-付きレビューの投稿) を参照。
     - dismiss 失敗時は **新規レビュー投稿を中止する**（既存レビューが残ったまま新レビューが追加されると混乱するため）。失敗を表示し，ユーザーに「dismiss せず追加投稿に切り替えるか中止するか」を AskUserQuestion で確認する
   - ユーザーが投稿しないを選択した場合: そのまま Phase 4 に進む

### Phase 4: worktree のクリーンアップ

1. **worktree を必ず削除する**:
   - `git worktree remove --force <worktree-path>` で worktree を削除する
   - `git update-ref -d refs/claude-pr-review/<pr-number> 2>/dev/null || true` と `git update-ref -d refs/claude-pr-review/base-<pr-number> 2>/dev/null || true` で一時 ref を削除する
   - **重要**: Phase 2 / Phase 3 が例外的に中断した場合も，このクリーンアップは必ず実行する。`trap` のようなシェル機構ではなく，オーケストレーション側の制御フローで「中断 → 直ちに Phase 4 を実行」を保証する

## リファレンス

### Reviewer 共通指示テンプレート

各 reviewer agent への指示文には以下を必ず含めること:

> diff 全文は渡されません。変更サマリと変更ファイルメタデータから担当観点に関係するファイルを優先し，worktree (`<worktree-path>`) 内の実際のソースコードを参照してレビューしてください．必要に応じて `git -C <worktree-path> diff refs/claude-pr-review/base-<pr-number>...HEAD -- <path>` でファイル単位の差分を確認してください．関連する周辺コード，呼び出し元，型定義，テストなども必要に応じて読み，変更の妥当性を判断してください．
>
> **出力形式**: Must Fix / Should Fix / Question の3セクションで結果を出力してください．Must Fix / Should Fix の各項目は先頭行を `` `filepath:line` - [category] description `` の形式で記述し，直下に `Impact` / `Evidence` / `Suggested fix` / `Confidence` を箇条書きで記述してください．Must Fix にはさらに `Blocking reason` を記述してください．Question にはレビュー判断に必要な確認事項のみを記述し，任意提案は含めないでください．日本語で出力する場合は，セクション名を `要修正` / `修正推奨` / `質問`，補助項目を `影響` / `根拠` / `推奨対応` / `確信度` / `ブロック理由`，確信度を `高` / `中` / `低` にしてください．
>
> Must Fix の例:
>
> - `src/auth.ts:42` - [security] Empty audience can bypass token validation.
>   - Impact: Unauthorized requests may be accepted.
>   - Evidence: `validateToken()` returns success before checking `aud`.
>   - Suggested fix: Reject empty or missing `aud` before accepting the token.
>   - Confidence: High
>   - Blocking reason: security
>
> Should Fix の例:
>
> - `src/user.ts:88` - [testing] The new inactive-user branch is not covered by tests.
>   - Impact: A future change could break inactive-user handling without a regression signal.
>   - Evidence: The PR adds `isInactive` handling, but no test covers that branch.
>   - Suggested fix: Add a focused test for inactive users.
>   - Confidence: Medium
>
> **判定基準**:
>
> - **Must Fix**: `Confidence: High` かつ `Evidence` と `Blocking reason` が明確で，バグで動かない / セキュリティ脆弱性 / データ破壊 / regression / 公開 API の破壊的変更 / PR の目的未達成 のいずれかに該当する場合のみ。`Blocking reason` は `bug` / `security` / `data loss` / `regression` / `public API break` / `requirement gap` のいずれかにする。判断に迷ったら Should Fix に降ろすこと
> - **Should Fix**: 修正が望ましいが Must Fix の基準には該当しないもの。`Confidence` は `High` または `Medium` にし，`Impact` / `Evidence` / `Suggested fix` を必ず記述する。好み・スタイル・「より良い書き方」程度のものは含めず，確認が必要なものだけ Question へ回す
> - **Question**: レビュー判断に必要な確認事項のみ。任意提案・好みの改善案・実害が説明できない低確信度の指摘は含めない
>
> **重複防止**: あなたの専門観点に直接関わる指摘のみを出してください。他観点（自分の担当外）の指摘は他 agent が担当します．

### レビューレポートテンプレート

- 英語: [`references/templates/report-en.md`](references/templates/report-en.md)
- 日本語: [`references/templates/report-ja.md`](references/templates/report-ja.md)

### テンプレート内プレースホルダ

レビュワー（Claude / Codex / GPT-5 など）に依存する箇所はプレースホルダにしている。レポート生成時に**必ず置換すること**。

| プレースホルダ    | 置換内容                              | デフォルト値（Claude Code 実行時）     |
| ----------------- | ------------------------------------- | -------------------------------------- |
| `<reviewer-name>` | レビュワーの表示名                    | `Claude`                               |
| `<short-sha>`     | レビュー対象 commit SHA の先頭 7 文字 | Phase 1.2 で取得した SHA の先頭 7 文字 |

**他のレビュワーで使う場合**: 環境変数や設定で `<reviewer-name>` を上書きする。例:

- Codex: name = `Codex`
- GPT-5: name = `GPT-5`

inline comments の `Commented by <reviewer-name>` フッターも同じ値で置換すること。

### カテゴリ表記

| Agent                           | 英語表記      | 日本語表記     |
| ------------------------------- | ------------- | -------------- |
| code-quality-reviewer           | code-quality  | コード品質     |
| documentation-accuracy-reviewer | documentation | ドキュメント   |
| performance-reviewer            | performance   | パフォーマンス |
| security-reviewer               | security      | セキュリティ   |
| testing-reviewer                | testing       | テスト         |

### Inline comments 付きレビューの投稿

レビュー投稿は [`scripts/post_review.sh`](scripts/post_review.sh) に集約されている。手順:

#### ステップ 1: レポートから inline comments を抽出する

**"Must Fix" / "要修正" セクションのみ**から項目を抽出する。Should Fix は inline 化しない。

抽出パターン（正規表現の例）: ``^- `(?<path>[^:]+):(?<line>\d+)` - \[(?<category>[^\]]+)\] (?<comment>.+)$``

各 Must Fix / 要修正 項目の直後に続くインデント済みの `Impact` / `Evidence` / `Suggested fix` / `Confidence` / `Blocking reason`（日本語では `影響` / `根拠` / `推奨対応` / `確信度` / `ブロック理由`）も同じ inline comment の本文に含める。次のトップレベル項目または次のセクション見出しに到達したら、その Must Fix 項目の本文は終了とみなす。

各項目を以下のJSON形式に変換し，配列としてファイルに保存する（例: `/tmp/pr-review-comments.json`）:

```json
[
  {
    "path": "src/auth.ts",
    "line": 42,
    "body": "🔴 **Must Fix**: [security] Empty audience can bypass token validation.\n\nImpact: Unauthorized requests may be accepted.\nEvidence: `validateToken()` returns success before checking `aud`.\nSuggested fix: Reject empty or missing `aud` before accepting the token.\nConfidence: High\nBlocking reason: security\n\n---\nCommented by <reviewer-name>"
  }
]
```

行番号の規則とファイルあたりの上限など，詳細は [注意事項](#注意事項) を参照。

#### ステップ 2: レビュー本文をファイルに保存する

レビューレポート本文を一時ファイルに保存する（例: `/tmp/pr-review-body.md`）。

#### ステップ 3: post_review.sh を呼び出す

```bash
bash <skill-dir>/scripts/post_review.sh \
  --repo "<owner/repo>" \
  --pr <number> \
  --commit "<latest-commit-sha>" \
  --event "<APPROVE|REQUEST_CHANGES|COMMENT>" \
  --body-file /tmp/pr-review-body.md \
  --comments-file /tmp/pr-review-comments.json
```

既存レビューを dismiss する場合は `--dismiss-review-id <id>` を追加する。
inline comments がない場合は `--comments-file` を省略する。

成功時は PR レビューの URL が標準出力に出力される。

#### API event の決定

| Verdict         | 通常モードの API event | self review モードの API event |
| --------------- | ---------------------- | ------------------------------ |
| APPROVE         | `APPROVE`              | `COMMENT`                      |
| REQUEST_CHANGES | `REQUEST_CHANGES`      | `COMMENT`                      |

self review モードでは `--event COMMENT` を渡すが，body 内の Verdict 表記は元のまま（`APPROVE` または `REQUEST_CHANGES`）にすること。

### セクション別コメント prefix

| セクション | 英語 Prefix      | 日本語 Prefix  |
| ---------- | ---------------- | -------------- |
| Must Fix   | 🔴 **Must Fix**: | 🔴 **要修正**: |

Should Fix は inline 化しないため prefix は不要（本文記載のみ）。

### 注意事項

- 行番号は新しいファイル（diff の右側）に対応するものでなければならない
- inline として投稿できないコメント（例: diff に含まれない行）は、body に含める
- 1回のレビューにつき inline comments は最大50件まで
