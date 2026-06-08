---
name: github-issue-update
description: open issueを横断的に点検して、closeすべきもの・内容を追記すべきもの・ラベルを追加/削除すべきものを自動判定し、確認なしで一括反映するSkill。「open issueを整理して」「stale issueを片付けて」「ラベルを整理して」のような依頼で使う。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(date:*), Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(rg:*), Read, Glob, Grep
---

# GitHub Issue Update

open issueを点検し、次の3種類の更新を **確認なしで自動反映** する。

1. **close**: 解決済み・重複・長期放置で閉じるべきもの
2. **コメント追記**: 内容に追加すべき情報がある、本文と現状にズレがある（参照ファイルが消えた等）
3. **ラベル変更**: 内容と乖離したラベルの追加/削除

## Arguments

- `language`: コメント本文の言語。デフォルト: `ja`
- `--max <N>`: 1回の実行で反映する候補の上限。デフォルト: `15`
- `--dry-run`: 候補抽出までで停止し、書き込みを行わない（点検目的）

## 常時適用するセーフガード

破壊的なcloseを誤発火させないため、以下の格下げを **常に** 行う:

- 弱いシグナルのみのclose候補 → **コメント追記にdowngrade**（「解決済みの可能性があります。確認の上closeしてください」と促す）
- 議論履歴のあるstale → **`stale` ラベル追加にdowngrade**（リポジトリに `stale` ラベルがある場合のみ）

強いシグナルのclose（完了条件全チェック、参照ファイルの消失、本文/evidenceまで一致する重複）はそのまま実行する。

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

各open issueに対して以下を判定する。**迷ったら候補から外す**（ノイズより安全側を優先）。

#### close候補

- **重複**: open issue同士でタイトル正規化一致、または主要キーワード3つ以上一致、または本文の主要トークン一致。古い方を残し新しい方をclose
- **解決済み（強）**: 完了条件のチェックボックスが全て埋まっている、または本文で参照しているファイルが消失
- **解決済み（弱）**: 参照箇所の周辺が大きく変わっている／コメント無反応など。セーフガードによりコメント追記にdowngrade
- **stale**: `updatedAt` が90日より古く、かつコメント0件 or 完了条件が抽象的（議論履歴のあるstaleはセーフガードにより `stale` ラベル付与にdowngrade）

#### コメント追記候補

- issue本文が参照するファイルが直近で大きく変わったがcloseまでは判定できない
- 本文と最新状況に齟齬がある（仕様が決まった、技術選択が確定した等が他のopen issueで判明している）
- 関連性の高い別のopen issueがある → 「関連: #N」コメント（既にリンクされていれば除外）

#### ラベル変更候補

Phase 0 で取得した既存ラベル一覧に存在するもののみ対象。

- **追加**: 内容に合致するラベルが既存ラベル一覧にあるのに付与されていない（例: 本文に「ドキュメント」とあるのに `documentation` 未付与）
- **削除**: 内容と明らかに乖離するラベル（例: `bug` ラベルだが本文がfeature request）
- **stale label**: `stale` ラベルが既存ラベル一覧にあり、stale判定された場合に追加

各候補は次の形で保持する:

```
{
  issue_number, issue_title, issue_url,
  actions: [
    { type: "close" | "comment" | "label_add" | "label_remove", payload: "...", reason: "...", strength: "strong" | "weak" }
  ],
  evidence: ["<ファイルパス/関連issue番号 など>"]
}
```

同一issueに対する複数actionは束ねる（close + コメント、コメント + ラベル変更など）。close優先で本文に複数の理由を含める。

### Phase 2: 優先度付けと打ち切り

優先度（高い順）:

1. 解決済みclose（完了条件達成や参照ファイル消失など確実なもの）
2. 重複close
3. stale close / stale label追加
4. ラベル追加/削除
5. コメント追記

`--max` を超える分は優先度の低い側から打ち切り、最終レポートに件数を含める。

セーフガードによるdowngradeはこの段階で確定させる（弱いclose → コメント追記、議論履歴あるstale → stale label追加）。

`--dry-run` 指定時はここで停止し、Phase 4 と同じ形式で「これから反映する内容」を出力して終了する。

### Phase 3: 一括反映

候補をactionごとに `gh` で処理する。**同一issueに対する複数actionはシリアル**、**異なるissueは5〜10件単位で並列**。

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

# stale label + 注意コメント
gh issue edit <N> --add-label stale
gh issue comment <N> --body "<staleコメント本文>"
```

`gh issue close --comment` は使わない（バージョン差異がある）。コメント本文に複数行を含める場合は `--body-file <tmpfile>` を使い、エスケープ問題を避ける。

並列実行の上限はGitHub secondary rate limit（content作成系で約80/分）を意識し、20件超のバッチは続けて投げない。1件失敗しても他の並列呼び出しは継続し、失敗した候補は最終レポートで集計する。

### Phase 4: 最終レポート

```
## 完了

Close: N件
- #42 ログ出力フォーマット統一 — closed (resolved)
- #67 README typo — closed (duplicate of #45)

コメント追記: M件
- #103 パーサ周りのリファクタ — 関連issue #110 を追記

ラベル変更: K件
- #110 +documentation
- #120 -bug

打ち切り: Q件（--max 超過）
Downgrade: R件（セーフガードでcloseからコメント追記等へ格下げ）
失敗: S件（gh コマンドエラー）

総候補数: N+M+K+Q+R+S 件
```

Downgradeの内訳（どのissueがどのactionに格下げされたか）を必ず明示する。closeしたissueの再openコマンド（`gh issue reopen <N>`）も末尾に控えとして付ける。

## Failure modes

- **gh認証なし / read-only token**: Phase 0で停止して案内
- **`stale` ラベルが存在しない**: 勝手に作らず、staleカテゴリ自体をskipする
- **大量のopen issue**: 300件超えるリポジトリでは `--max` で反映件数を絞る案内をする
- **誤close**: `gh issue reopen` で戻せるが発見が遅れるほど痛い。弱いシグナルだけのcloseはセーフガードで自動的にコメント追記へ格下げされる
