---
name: github-pr-fix
description: PRの全問題（コンフリクト、CI失敗、レビューコメント）を自動検出して修正するSkill。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*), Bash(bash:*)
---

# PR の全問題を修正

## 引数

- `PR number`: 修正するPR番号（任意、デフォルトは現在のブランチのPR）

レビューコメントへの対応後は**常に**GitHubへリプライを投稿する。

## コンテキスト

以下を取得してから作業を開始してください。

- 現在のブランチ: `git branch --show-current`
- 現在のPR: `gh pr view --json number,url,mergeable,mergeStateStatus 2>/dev/null || echo "No PR found"`
- PRタイトル: `gh pr view --json title --jq '.title' 2>/dev/null`
- PR本文: `gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- CIステータス: `gh pr checks 2>/dev/null || echo "No checks"`
- リポジトリ: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`

## タスク

このSkillは3つのサブSkillを正しい順序でオーケストレーションし、PRの全問題を修正する。

### Phase 0: 事前チェック

1. 引数の解析:
   - PR番号が指定されている場合はそのPRを使用
   - そうでなければ、現在のブランチに紐づくPRを使用
   - PRが存在しない場合はエラーメッセージを表示して中止
2. `owner/repo` を取得: `gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'`
3. PRの初期ステータスサマリーを表示

### Phase 1: PR言語の検出

- PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
- **重要**: すべての報告とサマリーは検出された言語で記述すること
- 各サブSkillも同じ言語を独立して検出する
- 言語が曖昧な場合は英語をデフォルトとする

### Phase 2: 問題の検出

3種類の問題を**並列に**検出する。検出結果に応じて Phase 3 で必要なサブSkillだけ呼び出す。

1. **コンフリクトの検出**:

   ```bash
   gh pr view <number> --json mergeable --jq '.mergeable'
   ```

   - `CONFLICTING` → 要対応
   - `MERGEABLE` / `UNKNOWN` → スキップ

2. **CI失敗の検出**:

   ```bash
   gh pr checks <number> --json name,state,conclusion 2>/dev/null \
     | jq '[ .[] | select(.conclusion == "FAILURE" or .conclusion == "CANCELLED" or .conclusion == "TIMED_OUT") ] | length'
   ```

   - 失敗チェック数 > 0 → 要対応
   - すべて成功 → スキップ
   - 全てまだ実行中の場合はステータスを報告し、後続の Phase 3 ステップ2 はスキップ

3. **未対応レビューコメントの検出**:

   inline review thread の未解決スレッド数を [github-pr-respond-comment の fetch_review_threads.sh](../github-pr-respond-comment/scripts/fetch_review_threads.sh) で取得する。
   `gh pr view --json reviews` の state だけで判定すると、`COMMENTED` 状態に紛れる未解決スレッドを取りこぼすので使わない。

   ```bash
   bash <respond-skill-dir>/scripts/fetch_review_threads.sh \
     --repo "<owner/repo>" \
     --pr <number> \
     --only-unresolved \
     | jq 'length'
   ```

   - 未解決スレッド数 > 0 → 要対応
   - 0 → スキップ

### Phase 3: 検出した問題への対応

検出された問題に対して、以下の順序でサブSkillを呼び出す。**前のステップが失敗しても後続のステップは試みる**。

#### Step 1: コンフリクトの解消

Phase 2-1 で `CONFLICTING` の場合のみ:

- `github-pr-fix-conflicts` Skill を実行
- 完了を待ってから、再度 `gh pr view --json mergeable --jq '.mergeable'` でコンフリクトが解消されたことを確認する
- 検出された言語でステータスを報告する

#### Step 2: CI失敗の修正

Phase 2-2 で失敗チェックがある場合のみ:

- `github-fix-ci` Skill を実行
- 完了を待つ。プッシュ後にCIが再実行されることに注意する
- 検出された言語でステータスを報告する

#### Step 3: レビューコメントへの対応

Phase 2-3 で未解決スレッドがある場合のみ:

- `github-pr-respond-comment` Skill を実行（同Skillはレビューコメントへのリプライを常に投稿する）
- 完了後、再度 `fetch_review_threads.sh --only-unresolved` で未解決スレッド数の差分を取って報告する
- 検出された言語でステータスを報告する

### Phase 4: 最終サマリー

検出された言語で次のフォーマットで表示する。

#### 英語フォーマット

```markdown
## PR Fix Summary

### Status

| Check     | Before | After |
| --------- | ------ | ----- |
| Conflicts | ❌/✅    | ✅     |
| CI        | ❌/✅    | ✅/⏳   |
| Reviews   | ❌/✅    | ✅     |

### Actions Taken

- [ ] Resolved X merge conflicts
- [ ] Fixed X CI failures
- [ ] Addressed X review threads (replied to Y)

### Commits Created

- `abc1234` - merge: resolve conflicts with main
- `def5678` - fix: resolve CI failures
- `ghi9012` - fix: address review comments
```

#### 日本語フォーマット

```markdown
## PR修正サマリー

### ステータス

| チェック     | 修正前 | 修正後 |
| ------------ | ------ | ------ |
| コンフリクト | ❌/✅    | ✅      |
| CI           | ❌/✅    | ✅/⏳    |
| レビュー     | ❌/✅    | ✅      |

### 実行したアクション

- [ ] X件のマージコンフリクトを解消
- [ ] X件のCI失敗を修正
- [ ] X件のレビュースレッドに対応 (うち Y件にリプライ投稿)

### 作成したコミット

- `abc1234` - merge: mainとのコンフリクトを解消
- `def5678` - fix: CI失敗を修正
- `ghi9012` - fix: レビューコメントに対応
```

## 注意事項

- 各ステップは Phase 2 で問題が検出された場合のみ実行される
- あるステップが失敗しても、後続のステップは実行を試みる
- 大きな変更の前にはユーザーに確認を求める
- 各ステップの完了後に検出された言語で進捗を報告する
- レビューコメントへの対応時は、`github-pr-respond-comment` に常にリプライを投稿させる（Phase 3 Step 3）
- レビューコメントの未解決判定は `fetch_review_threads.sh --only-unresolved` を使う。`gh pr view --json reviews` の state ベースの判定は `COMMENTED` 状態に紛れる未解決スレッドを取りこぼすので使わない
