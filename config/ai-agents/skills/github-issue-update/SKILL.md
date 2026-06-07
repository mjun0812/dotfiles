---
name: github-issue-update
description: open issueを横断的に点検して、closeすべきもの・内容を追記すべきもの・ラベルを追加/削除すべきものを自動判定し、ユーザー承認の上で一括反映するSkill。「open issueを整理して」「stale issueを片付けて」「ラベルを整理して」のような依頼で使う。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(date:*), Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(rg:*), Read, Glob, Grep, AskUserQuestion
---

# GitHub Issue Update

open issueを点検し、次の3種類の更新を提案・反映する。

1. **close**: 解決済み・重複・長期放置で閉じるべきもの
2. **コメント追記**: 内容に追加すべき情報がある、本文と現状にズレがある（参照ファイルが消えた等）
3. **ラベル変更**: 内容と乖離したラベルの追加/削除

新規issueは作らない。それは `github-issue-discover` の役目。

## Arguments

- `language`: コメント本文の言語。デフォルト: `ja`
- `--issue <N>`: 対象を特定のissue番号に絞る（複数指定可）
- `--max <N>`: 提示候補の上限。デフォルト: `15`
- `--stale-days <N>`: stale判定の日数。デフォルト: `90`
- `--dry-run`: 提示までで停止、書き込みはしない
- `--auto`: ユーザー承認をスキップして反映する。**ただし弱い判定はdowngradeする**（後述）

## 自動モードのセーフガード

`--auto` でも、close判定が弱いものは破壊的反映を避けるため格下げする:

- 弱いシグナルのみのclose候補 → **コメント追記にdowngrade**（「解決済みの可能性があります。確認の上closeしてください」と促す）
- 議論履歴のあるstale → **`stale` ラベル追加にdowngrade**（リポジトリに `stale` ラベルがある場合のみ）

強いシグナルのclose（関連PRマージ済み、完了条件全チェック、本文/evidenceまで一致する重複）はそのまま実行する。
`--dry-run` と `--auto` が両方指定された場合は `--dry-run` を優先する。

## Task

### Phase 0: 前提情報の取得

並列で以下を取得:

- リポジトリ: `gh repo view --json nameWithOwner`
- gh認証確認: `gh auth status`（未認証なら停止）
- 既存ラベル: `gh label list --limit 100 --json name`
- open issue一覧: `gh issue list --state open --limit 300 --json number,title,body,labels,createdAt,updatedAt,comments,url`
- 直近1年のclosed issue: `gh issue list --state closed --limit 300 --json number,title,body,labels,closedAt,url --search "closed:>$(date -u -v-1y +%Y-%m-%d 2>/dev/null || date -u -d '1 year ago' +%Y-%m-%d)"`
- 直近のPR: `gh pr list --state all --limit 200 --json number,title,body,state,mergedAt,closedAt,url`
- 現在日: `date -u +%Y-%m-%d`

`--issue <N>` 指定時は対象を該当issueのみに絞る。

### Phase 1: 候補抽出

各open issueに対して以下を判定する。**迷ったら候補から外す**（誤closeより未対応のほうがコストが小さい場合もあるが、ノイズより安全側を優先する判断は人間に委ねる）。

#### close候補

- **重複**: タイトル正規化一致、または主要キーワード3つ以上一致、または本文の主要トークン一致。古い方を残し新しい方をclose
- **解決済み（強）**: 関連PRに `Closes #N` / `Fixes #N` / `Resolves #N` が含まれそのPRがmerged、または完了条件のチェックボックスが全て埋まっている、または本文で参照しているファイルが消失
- **解決済み（弱）**: 参照箇所の周辺が大きく変わっている／コメント無反応など。`--auto` ではコメント追記にdowngradeする
- **stale**: `updatedAt` が `--stale-days` より古く、かつコメント0件 or 完了条件が抽象的

#### コメント追記候補

- 関連PRがopen/draft状態 → 「PR #X が進行中です」と現状共有
- issue本文が参照するファイルが直近で大きく変わったがcloseまでは判定できない
- 本文と最新状況に齟齬がある（仕様が決まった、技術選択が確定した等が他issueで判明している）
- 関連性の高い別issueがある → 「関連: #N」コメント（既にリンクされていれば除外）

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
  evidence: ["<PR番号/ファイルパス/関連issue番号 など>"]
}
```

同一issueに対する複数actionは束ねる（close + コメント、コメント + ラベル変更など）。close優先で本文に複数の理由を含める。

### Phase 2: 優先度付けと打ち切り

優先度（高い順）:

1. 解決済みclose（PRマージなど確実なもの）
2. 重複close
3. stale close / stale label追加
4. ラベル追加/削除
5. コメント追記

`--max` を超える分は優先度の低い側から打ち切り、最終レポートに件数を含める。

### Phase 3: 一覧提示と承認

`--auto` 指定時はセーフガードに従ってdowngradeした上で Phase 4 に直行する。

未指定時は Markdown 一覧で提示する:

```
## issue更新候補 (N件)

### Close候補
1. [resolved] #42 ログ出力フォーマット統一
   理由: PR #58 マージ済み、完了条件達成
2. [duplicate] #67 README typo
   理由: #45 と内容一致（古い #45 を残す）

### コメント追記候補
3. [update] #103 パーサ周りのリファクタ
   追記: 関連PR #150 が進行中

### ラベル変更候補
4. [label] #110 add: documentation
   理由: 本文がドキュメント整備の依頼
5. [label] #120 remove: bug
   理由: 本文がfeature request
```

承認は多段:

1. AskUserQuestion で「全件実行 / 個別選択 / 全件キャンセル / 詳細を見たい候補がある」
2. 「個別選択」: 4件以下は multiSelect、5件以上は除外番号をテキスト入力
3. 「詳細を見たい」: 番号を聞き、コメント下書きや該当本文を提示してから再度採否

closeを含む「全件実行」を選びそうな時は、close候補のコメント下書きを確認するか1回だけ問う。

`--dry-run` 時はここで停止し「ドライランです」と案内して終了。

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

# stale label + 注意コメント
gh issue edit <N> --add-label stale
gh issue comment <N> --body "<staleコメント本文>"
```

`gh issue close --comment` は使わない（バージョン差異がある）。コメント本文に複数行を含める場合は `--body-file <tmpfile>` を使い、エスケープ問題を避ける。

並列実行の上限はGitHub secondary rate limit（content作成系で約80/分）を意識し、20件超のバッチは続けて投げない。

### Phase 5: 最終レポート

```
## 完了

Close: N件
- #42 ログ出力フォーマット統一 — closed (resolved)
- #67 README typo — closed (duplicate of #45)

コメント追記: M件
- #103 パーサ周りのリファクタ — 関連PR #150 を追記

ラベル変更: K件
- #110 +documentation
- #120 -bug

スキップ: P件（ユーザー却下）
打ち切り: Q件（--max 超過）
Downgrade: R件（--auto セーフガードで格下げ）

総候補数: N+M+K+P+Q+R 件
```

`--auto` 実行時は Downgrade の内訳（どのissueがどのactionに格下げされたか）を明示する。closeしたissueの再openコマンド（`gh issue reopen <N>`）も末尾に控えとして付ける。

## Failure modes

- **gh認証なし / read-only token**: Phase 0で停止して案内
- **`stale` ラベルが存在しない**: 勝手に作らず、staleカテゴリ自体をskipする
- **大量のopen issue**: 300件超えるリポジトリでは `--issue` や `--max` で対象を絞る案内をする
- **誤close**: `gh issue reopen` で戻せるが発見が遅れるほど痛い。弱いシグナルだけのcloseは Phase 1 で候補化を控える

## 既存skillとの関係

- `github-issue-discover`: 新規issueの発見・起票。本skillは既存issueの更新が責務（補完的）
- `github-issue-create`: 単発issue作成。本skillはこれを呼ばない
