---
name: github-issue-update
description: 現在のリポジトリのopen issueを横断的に見直して、重複/解決済み/長期放置/状況変化のあるissueを検出し、ユーザー承認の上でclose・コメント追記・関連リンク追加を一括で行うSkill。closeする際は理由をコメントとして残す。ユーザーが「issueの状態を更新して」「open issueを整理して」「解決済みのissueをcloseして」「stale issueを片付けて」「重複issueを整理して」のように依頼したら必ずこのSkillを使うこと。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(rg:*), Bash(grep:*), Bash(wc:*), Bash(head:*), Bash(tail:*), Bash(date:*), Read, Glob, Grep, AskUserQuestion
---

# GitHub Issue Update

現在のリポジトリのopen issueを点検し、closeすべきもの・コメント追記すべきもの・相互リンクすべきものを検出してユーザー承認の上で一括反映するskill。

## Arguments

- `language`: コメント本文の言語。デフォルト: `ja`
- `--scope <list>`: 点検対象を絞る。カンマ区切りで `duplicates,resolved,stale,update,link` から選ぶ。未指定なら全範囲
  - `duplicates`: open同士・open vs closed/PRで重複しているissue
  - `resolved`: 関連PRがマージ済み・参照コードが消えている等で解決済みのissue
  - `stale`: 最終更新から長期間経過しているissue
  - `update`: 状況変化（参照ファイルの大幅変更、関連PRが進行中など）でコメント追記すべきissue
  - `link`: 関連性の高いissue同士の相互リンク追加
- `--issue <N>`: 特定のissue番号だけを対象にする。複数指定可（`--issue 12 --issue 34`）
- `--max <N>`: 一度に提示する候補の最大数。デフォルト: `15`
- `--stale-days <N>`: stale判定の日数。デフォルト: `90`
- `--dry-run`: 候補抽出と提示までで停止し、close/コメントは行わない

## Why this skill exists

issueは作成された瞬間から劣化する。close忘れ、重複、別のPRで暗黙に直されたまま放置、「あとで考える」と書かれたまま半年経過、といった状態が積み重なる。これは新しく入った人がissue一覧を見たときの認知負荷を上げ、「どれが本当に生きているissueか」が見えなくなる原因になる。

このskillの責務は **既存issueの状態を現実に追従させる** こと。新しいissueを起票するのは `github-issue-discover` の役目。close/追記はリスクを伴う操作なので、自動で全件処理せず、必ずユーザー承認を挟む。

## Phases

### Phase 0: 前提情報の収集

並列で以下を取得する。

- リポジトリ: `gh repo view --json name,owner --jq '.owner.login + "/" + .name'`
- デフォルトブランチ: `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's@^origin/@@'`
- gh認証: `gh auth status`（未認証なら停止して案内）
- 現在日: `date -u +%Y-%m-%d`（stale判定の基準）

**open issueの取得**:

```bash
gh issue list --state open --limit 300 \
  --json number,title,body,labels,assignees,createdAt,updatedAt,comments,url
```

**closed issue（最近1年）の取得**（重複検出に使う）:

```bash
gh issue list --state closed --limit 300 \
  --json number,title,body,labels,closedAt,url \
  --search "closed:>$(date -u -v-1y +%Y-%m-%d 2>/dev/null || date -u -d '1 year ago' +%Y-%m-%d)"
```

**最近のPR（state問わず）の取得**:

```bash
gh pr list --state all --limit 200 \
  --json number,title,body,state,mergedAt,closedAt,url
```

**最近のコミット履歴**（解決済み判定で参照ファイルの状態確認に使う）:

```bash
git log --since="$(date -u -v-6m +%Y-%m-%d 2>/dev/null || date -u -d '6 months ago' +%Y-%m-%d)" \
  --pretty=format:'%h %s' --name-only | head -500
```

`--issue <N>` が指定されていれば、対象を該当issueのみに絞り込む。それ以外のissueはPhase以降の判定対象から外す。

### Phase 1: 候補の抽出

各 `--scope` に対応する判定を順に実行する。各候補は以下の構造で内部リストに蓄積する。

```
{
  issue_number, issue_title, issue_url,
  action: "close" | "comment" | "link",
  category: "duplicate" | "resolved" | "stale" | "update" | "link",
  reason: "<何故この判定をしたかの根拠（人間が読める文）>",
  evidence: ["<ファイルパス:行 / PR番号 / 既存issue番号 など客観的な手がかり>"],
  proposed_comment: "<closeコメント or 追記コメント or リンクコメントの下書き>",
  related_refs: ["#42", "#PR123", ...]
}
```

「迷ったら候補から外す」が基本方針。誤って生きているissueを閉じる方が、未対応を残すより負債が大きい。判定が弱いものはスキップしてPhase 5の最終レポートで「保留」として件数だけ報告する。

### Phase 1A: 重複の検出（duplicates）

各open issueについて、他のopen issue・closed issue・PRと突き合わせる。

**重複と判定するルール**（OR条件）:

- タイトルの正規化文字列が一致（小文字化・記号除去・空白正規化後）
- タイトルの主要キーワード3つ以上が一致（ストップワード除外後）
- 本文の最初の段落・コードブロック・エラーメッセージの主要トークンが一致

判定対象の優先順:

1. open ↔ open: 古い方を残し、新しい方をclose候補とする（履歴が長い側に集約）
2. open ↔ closed: closeされたissueと内容が一致する場合、再発でない限りclose候補
3. open ↔ merged PR: PR本文にissueへの言及（`Closes #N`, `Fixes #N`, `#N`）があるのに該当issueがopenのままなら「resolved」カテゴリに振り分ける（duplicatesではなく）

**closeコメントの下書き**:

```
重複として close します。

#<残す側のissue番号> に集約してください。
（このissueと同じ内容のため）
```

### Phase 1B: 解決済みの検出（resolved）

以下のシグナルをAND/ORで組み合わせて「解決済み」を推定する。

**強いシグナル（単独でも候補化）**:

- 関連PRがマージされている: PR本文/タイトルが `Closes #N`, `Fixes #N`, `Resolves #N` を含み、そのPRが `merged` 状態
- issue本文の `Acceptance Criteria` / `完了条件` セクションのチェックボックスが全てチェック済み（コメントから判定）
- issue本文で参照しているファイルパスが現在のリポジトリから消失している（リネーム/削除された）

**弱いシグナル（複数組み合わせて候補化）**:

- issue本文中のTODO/FIXMEコメントの位置（ファイル + 周辺キーワード）が現在のソースから消失
- issue作成日以降に該当ファイルが大きく改変されている（>50%の行が変わっている）かつissueに反応がない
- 関連PRがmergeでなくclosedでも、その後同等の修正コミットが存在する（コミットメッセージから推定）

**closeコメントの下書き**（強いシグナルのケース）:

```
解決済みのため close します。

理由: <PR #123 がマージされ、本issueの完了条件を満たしています / 参照していた `src/foo.py` が #PR45 で削除されています>
証拠: <該当PRやコミットへのリンク>

もし未解決の論点が残っていれば、新しいissueとして再起票してください。
```

弱いシグナルのみで候補化したものは、closeコメント下書きに「未解決の論点が残っているか確認した上でcloseしてください」と明示し、ユーザー承認時に判断材料を増やす。

### Phase 1C: Stale issueの検出（stale）

`updatedAt` が `--stale-days`（デフォルト90日）より古いopen issueを抽出する。

判定はそれだけでは不十分なので、以下で **closeすべきstale** と **labelだけ付ければよいstale** に分ける:

- **close候補**: コメントが0件 or 作成者以外の反応がない、かつ `Acceptance Criteria` が空 or 抽象的
- **stale label候補**: 議論はあったが最近動きがない。close前にユーザー注意喚起したい

**closeコメントの下書き**:

```
長期間動きがないため一旦 close します（最終更新: <YYYY-MM-DD>、<N>日経過）。

引き続き対応が必要であれば再open または新しいissueとして起票してください。
```

**stale label追加コメントの下書き**:

```
最終更新から <N> 日経過したため `stale` ラベルを付与しました。
今後 <30> 日以内に動きがなければ自動 close 対象になります。
```

リポジトリに `stale` ラベルが存在しなければこのカテゴリはskipする（勝手にラベルを作らない）。Phase 0で取得したラベル一覧に含まれているかを必ず確認する。

### Phase 1D: 状況変化に応じた追記（update）

closeまではしないが、コメントで現状を補足すべきissue。

**コメント追記の対象**:

- 関連PRが現在open状態（draft含む）: 「PR #X が進行中です」と現状を共有
- issue本文で言及しているファイルが直近Nコミットで大きく変わったが、closeまでは判定できない
- issueに付いているラベルと現在のkindに乖離がある（例: `bug` ラベルだが本文がfeature request）→ ラベル変更の提案コメント

**追記コメントの下書き例**:

```
進行状況のメモ:

- 関連PR #123 が現在 open です（<2026-05-01> 作成、最新コミット <2026-05-07>）
- このissueの本文で言及している `src/parser.py` は #PR98 でリファクタされています
```

このフェーズはcloseではないので、判定が弱くても「情報追加」として比較的気軽に候補化してよい。ただし1issueにつき1コメント以内に収める（連投はノイズ）。

### Phase 1E: 関連issueのリンク追加（link）

重複ではないが関連性の高いissue同士に相互リンクのコメントを追加する。

**関連と判定するルール**:

- 同じファイル/モジュールに言及している
- 同じラベルかつタイトルのキーワードが2つ以上一致
- 一方のissue本文がもう一方を `関連:` `cf.` 等で言及している（既にリンクがあるケースは除外）

**リンクコメントの下書き**:

```
関連issue: #<N>（<タイトル>）
<関連性の説明: 同じモジュールに対する別観点の改善 など>
```

両方のissueに対称にコメントを書く。既に一方がもう一方を参照している場合はそのissueへのコメントは省略する。

### Phase 2: 重複候補の除外と優先度付け

抽出したaction候補を以下の優先度で並べる。

1. **resolved**（最も確実、close漏れの解消）
2. **duplicates**（一覧の認知負荷を下げる）
3. **stale**（古いノイズの除去）
4. **update**（情報の鮮度更新、closeしない）
5. **link**（メタ情報の充実、closeしない）

`--max` を超える分は優先度の低い側から打ち切る。打ち切った件数は最終レポートに含める。

同一issueに対して複数のactionが立った場合（例: resolved + stale）は、より強い側（close > comment > link）を採用し、もう一方はマージする。closeする場合はコメント下書きにも両方の理由を入れる。

### Phase 3: ユーザーへの一覧提示と承認

整形済み候補を **Markdown一覧** で提示する。actionごとにグループ化し、各候補に番号、issue番号、タイトル、理由の1行サマリを付ける。

```
## issue更新候補 (N件)

### Close候補 (X件)

1. [resolved] #42 ログ出力フォーマットの統一
   理由: PR #58 がマージ済み。本文の完了条件を満たす
2. [duplicate] #67 README typo
   理由: #45 と内容が一致（古い方の #45 を残す）
3. [stale] #89 将来的に検討したい設定オプション
   理由: 最終更新から 178 日経過、コメント0件

### コメント追記候補 (Y件)

4. [update] #103 パーサ周りのリファクタ
   追記内容: 関連PR #150 が進行中
5. [link] #110 ↔ #112
   追記内容: 同じモジュールに対する別観点

### Stale label追加候補 (Z件)

...
```

承認の取得方法は `github-issue-discover` と同じ多段方式:

1. AskUserQuestion で「全件実行 / 個別選択 / 全件キャンセル / 詳細を見たい候補がある」を聞く
2. 「個別選択」が選ばれた場合、4件以下なら AskUserQuestion の multiSelect で選択、5件以上なら「除外したい番号をカンマ区切りで」とテキスト（"Other" 入力）で返してもらう
3. 「詳細を見たい候補がある」が選ばれたら番号を聞き、close/コメントの下書き本文を提示してから再度採否を聞く
4. close候補は特に注意。本文を見ずに「全件実行」を選ぼうとした場合、closeはreversibleとはいえ手戻りコストがあるため一度「close候補のコメント下書きを確認しますか？」と確認を入れる

`--dry-run` 指定時はPhase 3の一覧提示で停止する。「ドライランです。実際に反映するには `--dry-run` を外して再実行してください」と伝えて終了。

### Phase 4: 一括反映

承認された候補を action 種別ごとに `gh` コマンドで処理する。同一メッセージ内で **5〜10件のバッチで並列発行** する。

**close + 理由コメント**:

```bash
# まずコメントを投稿
gh issue comment <N> --body "<closeコメント本文>"
# その後close
gh issue close <N>
```

`gh issue close --comment` ではなく `gh issue comment` → `gh issue close` の2段にする。`gh issue close --comment` はバージョンによって挙動が異なるため、確実な2段方式を採用する。

**コメント追記のみ**:

```bash
gh issue comment <N> --body "<コメント本文>"
```

**stale label追加 + コメント**:

```bash
gh issue edit <N> --add-label stale
gh issue comment <N> --body "<staleコメント本文>"
```

**関連リンク追加**:

両issueにそれぞれ `gh issue comment` でリンクコメントを投稿する。

#### 並列実行のガイドライン

- **バッチサイズ**: 5〜10件を1メッセージで並列発行
- **件数が多い場合**: バッチ単位で順に処理（バッチ内は並列、バッチ間はシリアル）
- **rate limit**: GitHubのコンテンツ作成系 secondary rate limitは1分80件目安。20件程度なら問題ない
- **エラーハンドリング**: 1件失敗しても他に影響しない。失敗した候補は最終レポートで集計する
- **closeとコメントの順序**: 同じissueに対する2コマンドは **シリアル**（並列にするとコメントがcloseに間に合わないリスクがある）

### Phase 5: 最終レポート

```
## 完了

Close: N件
- #42 ログ出力フォーマットの統一 — closed (resolved)
- #67 README typo — closed (duplicate of #45)
- #89 将来的に検討したい設定オプション — closed (stale, 178日経過)

コメント追記: M件
- #103 パーサ周りのリファクタ — 関連PR #150 を追記
- #110 ↔ #112 — 相互リンク追加

Stale label追加: K件
- #200 ...

スキップ: P件（ユーザー却下）
打ち切り: Q件（--max 超過）
保留: R件（判定が弱く候補化見送り）

総候補数: N+M+K+P+Q+R 件
```

URLは素のURLで提示する。closeしたissueの再openコマンド（`gh issue reopen <N>`）も最終レポートの末尾に控えとして記載しておくと、誤closeに気づいたときの戻し作業が早い。

## Failure modes に注意

- **gh認証なし**: Phase 0で停止して案内する
- **read-only token**: closeやコメント権限がない場合、Phase 4で初めて失敗する。事前に `gh auth status` で `repo` スコープがあるか確認する
- **public repoでのclose**: closeコメントに引用するPR/コミットに機密が含まれていないかを軽く確認する
- **大量のopen issue**: 300件超のリポジトリでは `--scope` で対象を絞ることをユーザーに案内する
- **誤close**: closeは `gh issue reopen` で戻せるが、間違いに気づくのに時間が経つほど発見しづらくなる。判定が弱いものはPhase 1の段階で候補から落とすことを徹底する

## 既存skillとの関係

- `github-issue-discover`: 新規issueを **発見・起票** するskill。本skillは既存issueの **更新・close** が責務で、対象が補完的
- `github-issue-create`: 単発のissue作成。本skillはこれを呼ばない（新規起票しないため）
- `github-pr-review` / `github-pr-respond-comment`: PR側の対応。本skillはPRの状態を読むだけで書き込まない
