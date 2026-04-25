---
name: github-pr-respond-comment
description: PRのレビューコメントを確認し、対応・返信するSkill。
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
---

# レビューコメントへの対応

## 引数

- `PR number`: 対応するPR番号（任意、デフォルトは現在のブランチのPR）
- `--reply`: 対応後にGitHubにリプライコメントを投稿（任意）

## コンテキスト

以下を取得してから作業を開始してください。

- 現在のブランチ: `git branch --show-current`
- 現在のPR: `gh pr view --json number,url,reviewDecision 2>/dev/null || echo "No PR found"`
- PRタイトル: `gh pr view --json title --jq '.title' 2>/dev/null`
- PR本文: `gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- 保留中のレビュー: `gh pr view --json reviews --jq '.reviews | map(select(.state != "APPROVED")) | length' 2>/dev/null || echo "0"`

## タスク

0. **事前チェック**:
   - 引数にPR番号が指定されている場合はそのPRを使用
   - そうでなければ、現在のブランチに紐づくPRを使用
   - PRが存在しない場合はエラーメッセージを表示して中止

1. **PR言語の検出**:
   - PRのタイトルと本文を分析して言語を検出する（例: 日本語、英語）
   - **重要**: すべてのコミットメッセージとリプライコメントは検出された言語で記述すること
   - 言語が曖昧な場合は英語をデフォルトとする

2. **レビューコメントの取得**:
   - すべてのレビューを取得: `gh pr view <number> --json reviews`
   - レビューコメントを取得: `gh api repos/{owner}/{repo}/pulls/<number>/comments`
   - 一般的なPRコメントを取得: `gh pr view <number> --comments`

3. **解決済みコメントの除外**:
   - GitHubで既に「RESOLVED」とマークされたコメントをスキップ
   - `gh api` を使用してレビュースレッドの `isResolved` ステータスを確認
   - まだ保留中/未解決のコメントのみを処理

4. **コメントの分類**:
   - **コード修正が必要**: 変更を要求するコメント
   - **質問**: 明確化を求めるコメント
   - **提案**: 任意の改善案
   - **情報共有**: 対応不要のコメント

5. **コメントサマリーの表示**（検出された言語で）:

## 英語フォーマット

```markdown
## Review Comments Summary

### ✅ Requires Code Change (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Proposed action: ...

### 💬 Requires Discussion (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Concern: [why this needs discussion]
   > → Your position: [your perspective with reasoning]

### Questions (X items)

1. **[filename:line]** by @reviewer
   > Question content
   > → Proposed answer: ...

### Suggestions (X items)

1. **[filename:line]** by @reviewer
   > Suggestion content
   > → Accept / Decline with reason: ...
```

## 日本語フォーマット

```markdown
## レビューコメント一覧

### ✅ 要修正 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 対応方針: ...

### 💬 要議論 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 懸念点: [議論が必要な理由]
   > → 見解: [技術的な根拠を含めた自分の立場]

### 質問 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 質問内容
   > → 回答案: ...

### 提案 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 提案内容
   > → 採用/不採用の理由: ...
```

6. **コメントの妥当性を評価**:
   - コメントを受け入れる前に、正確性と関連性を批判的に評価する
   - 考慮すべき点:
     - レビュアーの理解は正しいか？
     - 提案は実際にコードを改善するか？
     - レビュアーが考慮していないトレードオフはないか？
     - 個人の好みの問題か、客観的な改善か？
   - **不正確または議論の余地があるコメント**の場合:
     - 変更をすぐに実装しない
     - 代わりに、自分の見解を説明する丁寧なリプライを準備する
     - 技術的な根拠、参考資料、または例を提示して立場を裏付ける
     - レビュアーの意図が不明確な場合は明確化の質問をする
     - 議論が解決するまで変更を待つ
   - コメントを以下のようにマーク:
     - ✅ **採用**: コメントは妥当であり実装すべき
     - 💬 **議論**: アクション前に議論が必要
     - ❌ **不採用**: コメントが不正確（明確な理由を提示）

7. **採用したコメントへの対応**:
   - コード変更の場合:
     - 対象ファイルと行に移動
     - 要求された変更を適用
     - 変更内容を説明
   - 質問の場合:
     - 明確な回答を準備（検出された言語で）
   - 提案の場合:
     - 有益であれば適用、そうでなければ理由を説明

8. **コミットとプッシュ**（検出された言語でコミットメッセージを記述）:
   - すべての変更をステージング: `git add -A`
   - 検出された言語でコミットメッセージを記述:
     - 英語: `fix: address review comments`
     - 日本語: `fix: レビューコメントに対応`
   - リモートにプッシュ: `git push`

9. **リプライの投稿**（`--reply` フラグが指定されている場合）:
   - 検出された言語でリプライを記述
   - 各コメントに対して以下でリプライを投稿:
     `gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment-id>/replies -f body="<reply>"`
   - リプライの内容はアクションに応じて変わる:
     - **採用・実装済み**: 変更内容 + コミット参照
     - **議論が必要**: 自分の見解 + 根拠 + 質問
     - **不採用**: 提案を採用しなかった理由の明確な説明
   - 採用した変更のリプライ例:
     - 英語: "Fixed in abc1234. Changed X to Y as suggested."
     - 日本語: "abc1234 で修正しました。ご指摘の通り X を Y に変更しました。"
   - 議論のリプライ例:
     - 英語: "Thanks for the suggestion! I chose X because [reason]. However, I see your point about Y. Could you clarify [question]?"
     - 日本語: "ご提案ありがとうございます。[理由] のため X を選択しましたが、Y についてのご指摘も理解できます。[質問] について教えていただけますか？"

10. **結果を返す**（検出された言語で）:
   - 実行したアクションのサマリー
   - 議論待ちのコメント一覧（レビュアーの返答待ち）
   - 手動対応が必要なコメント一覧（ある場合）
   - すべてのブロッキングコメントに対応済みの場合、再レビューの依頼を提案
   - **注意**: 議論待ちのコメントがある場合は、再レビュー依頼前にレビュアーの返答を待つことを推奨

## 注意事項

- コメントの意図が不明確な場合は、変更前にユーザーに確認を求める
- 大きな設計変更の場合は、実装前にユーザーと相談する
- 関連する変更は論理的なコミットにグループ化する
- **批判的思考が不可欠**: すべてのレビューコメントが正しいとは限らない。レビュアーも間違えることがある。常に客観的にコメントを評価すること
- レビュアーと意見が異なる場合は、敬意を持って具体的な技術的根拠を提示する
- 解決済みのコメントは完全にスキップする — 再対応の必要なし
