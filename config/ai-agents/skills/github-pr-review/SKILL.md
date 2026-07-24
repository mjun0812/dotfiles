---
name: github-pr-review
description: >-
  GitHubのPull Request(PR)のコードレビューを行うSkill。worktreeを作成してソースコード全体を読みながらFinder SubAgentで指摘候補を発見し、Verifier SubAgentで検証する。レビューをレポートとインラインコメントで投稿する。self reviewにも対応する。
  ユーザーが「このPRをレビューして」のように依頼したら使うこと。
allowed-tools: Task, Read, Write, AskUserQuestion, Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(mkdir:*), Bash(mktemp:*), Bash(rm:*), Bash(bash:*)
---

# Pull Request Review

PRのhead commitを worktree にチェックアウトし，Finder SubAgentが指摘候補を探す．
Finder SubAgentが出した指摘候補は，1件ずつ Verifier SubAgent が反証を試み，
検証を通過したものだけを要修正事項としてレビューレポートとinline commentに投稿する．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)
- `--dry-run`: レビューレポートをチャットに提示するのみで、`post_review.sh` 等の投稿スクリプト・dismiss・resolve操作を一切呼ばない(worktreeの後片付けは通常どおり行う)
- `--run-tests`: verifier に worktree 内でのテスト実行を許可する。PR が fork からのもの(head repo が別 owner)の場合は無効化して警告する。既定では worktree 内のコードを一切実行しない

## Task

GitHub操作は必ず`gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

### Phase 1: 準備

#### Phase 1.1: 対象PRの特定

- **引数にPR番号が指定されている場合**: 指定されたPRを対象にする
- **引数なし**
  - **現在のブランチに紐づくopen PRが存在する場合**: そのPRをそのまま使用する(確認なし)
  - **現在のブランチに紐づくopen PRが存在しない場合**: RemoteのOpen PR一覧を取得し、`AskUserQuestion`でユーザーに対象PRを確認する。Open PRが1件もなければその旨を報告して終了する

#### Phase 1.2: PR情報とGitHub上の状態の収集

以下を取得する。

- PR情報: repository名、タイトル、本文、base・head branch、最新head commit SHA
- 変更内容: 変更ファイル一覧、diff、コミットメッセージ
- CI: checkの結果、失敗したcheckの名前・URL・取得可能な関連ログ
- 自分の既存レビュー: 未resolve threadと会話、`APPROVED` / `CHANGES_REQUESTED` レビューID

最新head commit SHAは `<latest-commit-sha>` として保持する。
CIの失敗はレポートの概要に記載し、Finderの内部証拠として使用する。
自分の既存threadと会話はVerifierの反証材料として使用し、投稿前のthread IDを `<existing-thread-ids>`、レビューIDを `<existing-review-ids>` として保持する。

他のレビュワーのレビューやthreadは参照しない。初回レビューではどちらのID一覧も空になる。

#### Phase 1.3: worktreeとレビュー環境の準備

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-review` を専用 worktree path とする。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PRの最新head commitとbase branchを取得し、head commitをdetached状態で専用worktreeにcheckoutする。
4. worktreeの `HEAD` が `<latest-commit-sha>` と一致することを確認する。一致しない場合はレビューを中止する。
5. Phase 2以降では、レビュー対象のファイルをすべて専用worktree内から参照する。
6. worktreeの準備に失敗した場合は、エラーを報告して中止する。

### Phase 2: レビュー

Finder SubAgentが変更全体から候補を収集し、Verifier SubAgentがfalse positiveを落とし、確定指摘からレビューレポートを作成する。

#### Phase 2.1: Finder SubAgentの実行

`pr-reviewer-finder` を1つ起動し、PRの変更全体から `[finding]` 形式の指摘候補を収集する。
レビュー方法と出力形式はFinderのagent定義に従う。

Finder には以下の情報を渡す:

- PRのタイトル・本文
- PR全体の変更サマリ(changedFiles / additions / deletions)
- worktree のパス(絶対パス)
- base branch と head branch の最新 commit SHA
- 失敗したCI結果のサマリと、checkの名前・URL・関連ログ

#### Phase 2.2: 候補選別と敵対的検証

Finderが発見した指摘から候補を確定する。

- Finder の `[finding]` をすべて候補とする
- 候補は以下をすべて満たすこと: PRのdiffが導入・露出した問題である / `問題` に発生条件・原因・具体的な実害がある / `完了条件` が実装方法ではなく満たすべき状態を示している / `証拠` の実行パスがある
- verifier の起動前に、同じ `filepath:line` または同じ根本原因の候補を1件にまとめる
- 各候補と自分の既存未resolve threadを照合し、同じ根本原因の会話だけをVerifierの反証材料とする

**敵対的検証**: 候補1件ごとに `pr-reviewer-verifier` を並列起動して反証を試みる。

- 選別の結果、候補が0件ならこのステップをスキップする
- 各 verifier には、候補1件の全文(証拠チェーンと関連するCI情報を含む)、同じ根本原因の既存threadと会話(ある場合)、worktree のパス、PRのタイトル・本文、base / head の commit SHA、テスト実行の許可有無を渡す
- テスト実行は `--run-tests` が指定され、かつ fork PR でない場合のみ許可する。それ以外は「worktree 内のコードを一切実行しない」と明示して渡す
- verdict が `confirmed` の候補のみ通過させる。`refuted` / `uncertain` は破棄する

**確定指摘の正規化**: verifier が `confirmed` と判定した候補だけを、以下の内部レコードへ正規化する。

- `path` / `line` / `side`
- `要約`
- `問題`
- `完了条件`
- `証拠` (問題へ実際に到達する実行パス。内部確認専用)

verifierの「完了条件の評価」を反映し、実装方法を指定せず、問題が解消されたと判断できる状態を`完了条件`に残す。
候補の重複統合はverifier前の1回だけとする。
Phase 2.3では、この確定指摘一覧だけを指摘内容の入力として扱う。

#### Phase 2.3: 指摘の校正とレビューレポートの作成

Phase 2.2の確定指摘一覧から、次の順でレビューレポートを作成する。

1. PRのタイトルと本文から出力言語を決める。
   - 主に日本語の場合は日本語
   - それ以外または判定が曖昧な場合は英語
2. 確定指摘一覧を、同じ件数と順序の校正済み指摘一覧へ変換する。
   - 人間が一読で問題と実害を理解できる、平易で自然な表現にする
   - `要約`は、問題の中心を一読で理解できる短い表現にする
   - `問題`は、発生条件、原因、具体的な実害が自然に伝わる順序で記述する
   - 専門用語、略語、造語を使用せず、必要な技術概念は一般的な言葉で説明する
   - 検証過程、証拠の列挙、重複した説明を取り除く
   - 問題を理解するために必要な前提やコード上の名称は残す
   - `完了条件`は、問題が解消されたと判断できる状態を簡潔に記述する
   - 指摘の採否、技術的な意味、対象範囲、`完了条件`の意味を変更しない
   - 推測による情報、修正案、実装方法を追加しない
   - `path`、`line`、`side`は変更しない
3. Verdictを決める。
   - 校正済み指摘が1件以上の場合は`REQUEST_CHANGES`
   - 校正済み指摘が0件の場合は`APPROVE`
   - self reviewを含め、レポート内では`COMMENT`を使用しない。GitHub APIへ渡すeventはPhase 3.1で決める
4. 出力言語に対応するテンプレートを読み込む。
   - 日本語の場合は`references/report-ja.md`
   - 英語の場合は`references/report-en.md`
5. テンプレートを埋めてレポート本文を生成する。
   - `<reviewer-name>`: 実行中のレビュワー名。Claude Codeでは`Claude`
   - `<short-sha>`: `<latest-commit-sha>`の先頭7文字
   - CIが失敗している場合は概要に1行記載する

校正済み指摘一覧には、次の項目だけを含める。

- `path` / `line` / `side`
- `要約`
- `問題`
- `完了条件`

確定指摘一覧と`証拠`は、校正後も内部確認用として保持する。
レポート本文とinline commentの指摘部分は、校正済み指摘一覧だけから生成する。

#### Phase 2.4: 出力対象commitの確認

PRの現在のhead commit SHAを再取得し、Phase 1で保持した `<latest-commit-sha>` と一致することを確認する。

- 一致しない場合はレビュー結果を無効とし、Phase 3をスキップしてPhase 4に進む
- 一致し、`--dry-run` が指定されている場合はPhase 3をスキップしてPhase 4に進む
- 一致し、`--dry-run` が指定されていない場合はPhase 3に進む

### Phase 3: レビューの投稿と置き換え

`--dry-run` が指定されていない場合のみ実行する。

#### Phase 3.1: event種別の決定

- self review モードでは `--event COMMENT` を渡すが，body 内の Verdict 表記は元のまま(`APPROVE` または `REQUEST_CHANGES`)にする(GitHub の仕様で自分の PR に `APPROVE` / `REQUEST_CHANGES` は投稿できないため)。
- self review 以外の通常レビューでは、レビューレポートのVerdictが `APPROVE` → `--event APPROVE`、`REQUEST_CHANGES` → `--event REQUEST_CHANGES` を渡す

#### Phase 3.2: inline commentの作成と投稿

Phase 2.3の校正済み指摘一覧について、`(path, line, side)`がPRのdiffに含まれるか検証し、diff内の指摘からinline comments JSONを生成する。
レポート本文を解析してinline commentsを作らず、レポートと同じ校正済み指摘一覧から生成する。
番号と内容はレポート本文に一致させ、内部確認用の`証拠`は含めない。

inline comments JSONは以下の形式とする。

```json
[
  {
    "path": "src/auth.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "🔴 1: **Issue summary**\n\n問題: ...\n完了条件: ...\n\n---\nCommented by <reviewer-name>"
  }
]
```

`path` / `line` / `body` は必須。`side` は既定 `RIGHT` とし、削除行など変更前ファイル側にコメントする場合のみ `LEFT` を明示する。
`N:` はレポート本文の `N:` 番号と一致させ、inline対象外の指摘があっても再採番しない。

レビュー実行ごとに `mktemp -d` で一意な `<review-temp-dir>` を作成する。
レポート本文を `<review-temp-dir>/body.md`、inline comments JSONを `<review-temp-dir>/comments.json` に保存し、`scripts/post_review.sh` に渡してGitHub API経由でレビューを投稿する。
inline commentsがない場合は `--comments-file` を省略する。

```bash
bash "<skill-dir>/scripts/post_review.sh" \
  --repo "<owner/repo>" \
  --pr "<number>" \
  --commit "<latest-commit-sha>" \
  --event "<APPROVE|REQUEST_CHANGES|COMMENT>" \
  --body-file "<review-temp-dir>/body.md" \
  --comments-file "<review-temp-dir>/comments.json"
```

- 成功時は PR レビューの URL が標準出力に出力される
- レビュー本文とinline commentはファイルで渡し、シェル引数にしない
- **重要**: `gh pr review --body ...`、`gh api -f body=...`、シェル上で組み立てた JSON 文字列の直接渡しは禁止
- Inline Coments のルール:
  - 行番号は，`side` が `RIGHT`(既定)の場合は変更後ファイル(diff の右側)の行に，`LEFT` の場合は変更前ファイル(diff の左側)の行に対応していなければならない
  - `post_review.sh` は防御的な再確認として、投稿前に PR の files API から各ファイルの patch を取得し，`(path, line, side)` が diff に含まれているかを検証する。invalid なエントリはinline対象から除外し、レポート本文は変更しない。残りのinline投稿は継続し、除外件数を標準エラーに `Warning:` として出力する

#### Phase 3.3: 以前のレビューの後始末

Phase 3.2の投稿が成功した後にのみ実行し、最新レビューだけを現在有効なレビューとして残す。投稿が失敗した場合は何もしない(古いレビューを残すことで「新規レビューなし」の空白状態を回避する)。初回レビュー時は対象0で自然にスキップされる。

**既存レビューのdismiss**

**重要**: 必ず Phase 1.2 で取得した `<existing-review-ids>`(投稿前のスナップショット)を `--review-id` で明示的に渡す。スクリプトはIDの自動検索を行わず、`--review-id` がない場合は失敗する。

```bash
bash "<skill-dir>/scripts/dismiss_my_reviews.sh" \
  --repo "<owner/repo>" \
  --pr "<number>" \
  --review-id "<id1>" --review-id "<id2>"  # Phase 1.2 で取得したスナップショットを全て指定
```

`<existing-review-ids>` が空の場合は dismiss スクリプトを呼び出さない。

**以前のinline commentのresolve**

Phase 1.2 で取得した `<existing-thread-ids>` のthreadを、outdatedかどうかに関係なくすべてresolveする。最新headへの新しいレビューが投稿済みのため、以後は新しいレビューだけを対応対象とする。

```bash
bash "<skill-dir>/scripts/resolve_review_threads.sh" \
  --thread-id "<id1>" --thread-id "<id2>"
```

`<existing-thread-ids>` が空の場合はresolveスクリプトを呼び出さない。
スクリプトは指定されたthread IDだけをresolveする。

### Phase 4: 終了処理

まず、レビュー用に作成したworktreeと一時Git refを削除する。投稿用の `<review-temp-dir>` を作成している場合は、それも削除する。
処理が中断した場合も、作成済みのworktreeと一時Git ref、`<review-temp-dir>` を必ず削除する。

クリーンアップの成否にかかわらず、続けて結果を報告する。失敗した場合は、その内容も含める。

Phase 2.4でhead commit SHAが一致しなかった場合は、レビュー内容を提示せず、PR更新後の再レビューが必要なことを報告する。
一致した場合は、以下をまとめてユーザーに提示して終了する。

- Verdict、要修正事項の件数、レポート本文
- レビューURL(`post_review.sh` の標準出力)。`--dry-run` または投稿失敗時は、投稿されていない旨を明記する
- dismissした既存レビューとresolveした以前のthreadの件数(Phase 3.3を実行した場合のみ)
