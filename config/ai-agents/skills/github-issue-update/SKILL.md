---
name: github-issue-update
description: open issueを横断的に点検して、closeすべきもの・内容を追記すべきもの・ラベルを追加/削除すべきものを自動判定し、最後にsummaryを提示してユーザー承認の上で一括反映するSkill。「issueを整理して」「issueのラベルを整理して」のような依頼で使う。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(date:*), Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(rg:*), Read, Glob, Grep, AskUserQuestion
---

# GitHub Issue Update

open issueを点検し、次の3種類の更新を行うSkill。ユーザーから「open issueを整理して」「stale issueを片付けて」「ラベルを整理して」のような依頼があったらこのSkillを使うこと。

1. **close**: 解決済み・重複・長期放置で閉じるべきもの
2. **コメント追記**: 内容に追加すべき情報がある、本文と現状にズレがある（参照ファイルが消えた等）
3. **ラベル変更**: 内容に合わせたラベルの追加/削除

最終的にsummaryを提示し、ユーザーの承認を得てから反映する。

## Arguments

- `language`: コメント本文の言語。デフォルト: `ja`
- `--max <N>`: 1回の実行で反映する候補の上限。デフォルト: `100`

## Task

### Phase 0: 前提情報の取得

並列で以下を取得:

- リポジトリ: `gh repo view --json nameWithOwner`
- gh認証確認: `gh auth status`（未認証なら停止）
- 既存ラベル: `gh label list --limit 100 --json name`
- open issue一覧: `gh issue list --state open --limit 300 --json number,title,body,labels,createdAt,updatedAt,comments,url`
- 現在日: `date -u +%Y-%m-%d`

closed issueやPRは判定対象に含めない（点検範囲はopen issueのみ）。

### Phase 1: 候補抽出

各open issueに対して以下を判定する。

#### close候補

- **重複**: open issue同士でタイトル正規化一致、または主要キーワード3つ以上一致、または本文の主要トークン一致。古い方を残し新しい方をclose
- **解決済み**: 完了条件のチェックボックスが全て埋まっている、または本文で参照しているファイル/コードが消失
- **stale**: `updatedAt` が90日より古く、かつコメント0件 or 完了条件が抽象的

#### コメント追記候補

- issue本文が参照するファイルが直近で大きく変わったがcloseまでは判定できない
- 本文と最新状況に齟齬がある（仕様が決まった、技術選択が確定した等が他のopen issueで判明している）
- 関連性の高い別のopen issueがある → 「関連: #N」コメント（既にリンクされていれば除外）

#### ラベル変更候補

Phase 0 で取得した既存ラベル一覧に存在するもののみ対象（存在しないラベルは勝手に作らない）。

- **追加**: 内容に合致するラベルが既存ラベル一覧にあるのに付与されていない（例: 本文に「ドキュメント」とあるのに `documentation` 未付与）
- **削除**: 内容と明らかに乖離するラベル（例: `bug` ラベルだが本文がfeature request）

各候補は次の形で保持する:

```
{
  issue_number, issue_title, issue_url,
  actions: [
    { type: "close" | "comment" | "label_add" | "label_remove", payload: "...", reason: "..." }
  ],
  evidence: ["<ファイルパス/関連issue番号 など>"]
}
```

同一issueに対する複数actionは束ねる（close + コメント、コメント + ラベル変更など）。close優先で本文に複数の理由を含める。

### Phase 2: 優先度付けと打ち切り

優先度（高い順）:

1. 解決済みclose（完了条件達成や参照ファイル消失など確実なもの）
2. 重複close
3. stale close
4. ラベル追加/削除
5. コメント追記

`--max` を超える分は優先度の低い側から打ち切り、最終レポートに件数を含める。

### Phase 3: Summary提示とユーザー承認

候補を **summary形式** で提示し、AskUserQuestion で承認を取る。close含めすべての書き込みは承認後にしか行わない（誤反映を承認ゲートで防ぐ）。

Summary例:

```
## 点検結果 (候補 N件)

### Close (X件)
- #42 ログ出力フォーマット統一 — 完了条件すべて達成
- #67 README typo — #45 と重複（古い #45 を残す）
- #89 将来検討したい設定オプション — 最終更新178日、コメント0件 (stale)

### コメント追記 (Y件)
- #103 パーサ周りのリファクタ — 関連issue #110 を追記
- #110 ↔ #112 — 関連リンクを相互追加

### ラベル変更 (Z件)
- #120 +documentation
- #125 -bug
```

承認は AskUserQuestion で多段に取る:

1. 「すべて反映 / 個別選択 / すべてキャンセル / 詳細を見たい候補がある」
2. 「個別選択」: 4件以下は multiSelect、5件以上は除外番号をテキスト入力（"Other"）
3. 「詳細を見たい」: 番号を聞き、コメント本文ドラフトや該当issue本文を提示してから再度採否

承認されなかった候補は最終レポートで「スキップ」として件数のみ報告する。

### Phase 4: 一括反映

承認された候補をactionごとに `gh` で処理する。**同一issueに対する複数actionはシリアル**、**異なるissueは5〜10件単位で並列**。

```bash
# close + 理由コメント（必ずcomment → close の順）
gh issue comment <N> --body "<closeコメント本文>"
gh issue close <N>

# コメント追記のみ
gh issue comment <N> --body "<本文>"

# ラベル追加
gh issue edit <N> --add-label <name> [--add-label <name>]

# ラベル削除
gh issue edit <N> --remove-label <name>
```

`gh issue close --comment` は使わない（バージョン差異がある）。コメント本文に複数行を含める場合は `--body-file <tmpfile>` を使い、エスケープ問題を避ける。

並列実行の上限はGitHub secondary rate limit（content作成系で約80/分）を意識し、20件超のバッチは続けて投げない。1件失敗しても他の並列呼び出しは継続し、失敗した候補は最終レポートで集計する。

### Phase 5: 最終レポート

```
## 完了

Close: N件
- #42 ログ出力フォーマット統一 — closed (resolved)
- #67 README typo — closed (duplicate of #45)

コメント追記: M件
- #103 パーサ周りのリファクタ — 関連issue #110 を追記

ラベル変更: K件
- #120 +documentation
- #125 -bug

スキップ: P件（ユーザー却下）
打ち切り: Q件（--max 超過）
失敗: R件（gh コマンドエラー）

総候補数: N+M+K+P+Q+R 件
```
