---
name: github-pr-review
description: >-
  GitHubのPull Requestを敵対的にコードレビューし、検証を通過した指摘だけをレビューレポートとinline commentで投稿するSkill。`--spec` またはPRに紐づくIssueからspecを解決できる場合は、specとの整合も検査する。self reviewにも対応する。
  ユーザーが「このPRをレビューして」のように依頼したら使うこと。
allowed-tools: Task, Read, Write, AskUserQuestion, Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(mkdir:*), Bash(mktemp:*), Bash(rm:*), Bash(bash:*)
---

# Pull Request Review

PRのhead commitを worktree にチェックアウトし，Finder SubAgentが指摘候補を探す．
Finder SubAgentが出した指摘候補は，1件ずつ Verifier SubAgent が反証を試み，
検証を通過したものだけを要修正事項としてレビューレポートとinline commentに投稿する．
並行して Standards SubAgent がmergeをブロックすべき規約違反・コードスメルの指摘候補を探し，1件ずつ Verifier の検証を経たものだけを同じレビューに含める．
spec sourceを解決できる場合は，Contract SubAgent がspecとの不整合の指摘候補を第3の軸として探し，同じくVerifierの検証を経たものだけをレビューに含める．

## Arguments

- `PR number`: レビューするPR番号 (optional, defaults to PR for current branch)
- `--spec <source>`: Contract reviewに使うspec source (GitHub Issue番号または `.mjun/specs/<slug>` のパス)。指定時は関連Issueより優先する
- `--dry-run`: レビューレポートをチャットに提示するのみで、`post_review.sh` 等の投稿スクリプト・dismiss・resolve操作を一切呼ばない(worktreeの後片付けは通常どおり行う)

## Task

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

さらに、Contract review用のspec contractを次の順で解決する。

1. `--spec` が指定されていればそれを使う。Issue番号なら `gh issue view` で本文のcontractセクション群 (Context〜Out of Scope、Decision Log) を、`.mjun/specs/<slug>` のパスなら**メインworking tree**の同パスから `spec.md` を読む (レビュー用worktreeに `.mjun/` は存在しない)
2. PR本文に `Closes #N` があれば `gh issue view N` で本文を取得し、contractセクション群を使う

Issueが投影形式 (Context〜Out of Scopeのcontractセクション群) でない普通のIssueの場合は、本文全体をcontract相当として扱う。明文に無い期待を検査しない原則は変わらないため、記述の薄いIssueではContract指摘は自然に少なくなる。

どちらでも解決できない場合はContract軸をスキップし、レポートの概要にその旨を1行記載する。解決したcontractは `<spec-contract>` として保持する。なお、Issue本文のcontractは承認時点の投影であり、最新の正本はLocal specにある。`.mjun/` を持つマシンでレビューするときは `--spec` でLocal specを渡すことを推奨する。

**Local spec由来のContract指摘は投稿しない**: `--spec` でLocal spec (`.mjun/specs/` のパス) を解決した場合、Contract軸の確定指摘はverdictへ通常どおり計上するが、レポート本文へは個別項目として記載せず (Phase 2.5 step 5の概要1行のみ)、inline commentも生成せず、全文はPhase 4のチャット報告にのみ含める (specは内部文書のため、その引用をGitHubへ投稿しない)。`Closes #N` 経由で解決した場合のContract指摘は、投影済みIssueの引用であり通常どおり投稿する。specは内部文書のため、レビューレポートやinline commentへ `.mjun/` 配下のパスを書かない (specの記述は「spec」とだけ呼んで引用する)。

他のレビュワーのレビューやthreadは参照しない。初回レビューではどちらのID一覧も空になる。

#### Phase 1.3: worktreeとレビュー環境の準備

1. `<repo-root>/.tmp/<repo-name>-worktrees/pr-<number>-review` を専用 worktree path とする。
2. 同じ path の worktree が存在し、未commit変更がある場合は中止する。clean な場合のみ作り直してよい。
3. PRの最新head commitとbase branchを取得し、head commitをdetached状態で専用worktreeにcheckoutする。
4. worktreeの `HEAD` が `<latest-commit-sha>` と一致することを確認する。一致しない場合はレビューを中止する。
5. 専用worktreeをレビュー対象のsnapshotとし、Phase 2以降では対象ファイルをすべてこのsnapshot内から参照する。
6. worktreeの準備に失敗した場合は、エラーを報告して中止する。

### Phase 2: レビュー

Finder SubAgentが変更全体から候補を収集し、Verifier SubAgentがfalse positiveを落とす。並行してStandards SubAgentが規約・品質の指摘候補を、spec解決時はContract SubAgentがspecとの不整合の指摘候補を収集し、確定指摘・確定規約指摘・確定契約指摘からレビューレポートを作成する。

#### Phase 2.1: FinderとStandardsとContract SubAgentの実行

`code-reviewer-finder` と `code-reviewer-standards` を1つずつ並列に起動する。`<spec-contract>` を解決できた場合は `code-reviewer-contract` も並列に起動する。
Finderはmergeを止める問題の指摘候補を、Standardsはmergeをブロックすべき規約違反・コードスメルの指摘候補を、Contractはspec contractとの不整合 (逸脱・未充足・boundary違反・scope creep) の指摘候補を収集する。
レビュー方法と出力形式はそれぞれのagent定義に従う。
次のprompt templateを使用する。

```text
以下の対象変更を、agent定義の責務・判定基準・出力形式に従ってレビューする。
あなたの役割: <role>

対象変更:
- 対象種別: GitHub PR
- PR番号: <pr-number>
- 変更目的・説明: <pr-title-and-body>
- 変更ファイル一覧: <changed-files>
- diff: <diff>
- 変更履歴: <commits>
- 変更サマリ: <change-summary>
- snapshotの絶対パス: <snapshot-path>
- baseline識別子: <base-sha>
- snapshot識別子: <head-sha>
- 追加証拠: <ci-evidence>
- spec contract: <spec-contract>
```

`<role>` には `Finder`、`Standards`、`Contract` のいずれかを指定する。`<spec-contract>` にはContract起動時のみ解決済みspec contract全文を指定し、FinderとStandardsでは `なし` とする。
`<change-summary>` にはchangedFiles / additions / deletionsを、`<ci-evidence>` には失敗したCI結果のサマリとcheckの名前・URL・関連ログを指定する。
該当するCI結果がなければ `なし` とする。

どちらのSubAgentにも、Gitの差分と履歴の参照、ファイルの検索と読み取りだけを許可する。
worktree内のコード、テスト、ビルド、lint、型チェック、package script、再現コードは実行させない。

#### Phase 2.2: Finder候補の選別と敵対的検証

Finderが発見した指摘から候補を確定する。

- Finderが出力したカテゴリラベル付きの指摘をすべて候補とする
- 候補は以下をすべて満たすこと: PRのdiffが導入・露出した問題である / `問題` に発生条件・原因・具体的な実害がある / `完了条件` が実装方法ではなく満たすべき状態を示している / `証拠` の実行パスがある
- verifier の起動前に、同じ `filepath:line` または同じ根本原因の候補を1件にまとめる
- カテゴリは表示用情報として扱い、候補の重複統合やverifierの判定に使用しない
- 各候補と自分の既存未resolve threadを照合し、同じ根本原因の会話だけをVerifierの反証材料とする

**敵対的検証**: 候補1件ごとに `code-reviewer-verifier` を1つずつ起動して反証を試みる。

- 選別の結果、候補が0件ならこのステップをスキップする
- verifierには、worktree内で検証に必要なコマンドと、関連する最小のテストや再現コードの実行を許可する
- verifierがコードを実行した場合は、コマンドと結果を内部の根拠に残す

次のprompt templateを使用する。

```text
次のコードレビュー候補1件を、支持せずに反証を優先して独立検証する。
候補種別: <candidate-type>
検証対象の指摘:
<candidate>

対象変更:
- 対象種別: GitHub PR
- PR番号: <pr-number>
- 変更目的・説明: <pr-title-and-body>
- 変更ファイル一覧: <changed-files>
- diff: <diff>
- snapshotの絶対パス: <snapshot-path>
- baseline識別子: <base-sha>
- snapshot識別子: <head-sha>
- 追加証拠:
  - CI: <ci-evidence>
  - 同じ根本原因の既存thread: <related-thread>
  - spec contract: <spec-contract>
```

Finder候補では `<candidate-type>` を `Finder`、`<candidate>` を候補1件の全文、`<related-thread>` を同じ根本原因の既存threadと会話にする。
該当するthreadがなければ `なし` とする。FinderとStandardsの検証では `<spec-contract>` を `なし` とする。
その他のplaceholderにはPhase 2.1と同じ値を指定する。

最終verdictが`confirmed`の候補のみ通過させる。`refuted` / `uncertain`は破棄する。

**確定指摘の正規化**: verifier が `confirmed` と判定した候補だけを、以下の内部レコードへ正規化する。

- `path` / `line` / `side`
- `カテゴリ`
- `要約`
- `問題`
- `完了条件`
- `証拠` (問題へ実際に到達する実行パス)
- `検証結果` (verifierの根拠と実行結果)

`証拠`は、Phase 2.5で`発生経路`へ校正するための入力として保持する。
`検証結果`は内部確認用として保持し、レビュー本文とinline commentには含めない。
verifierの「完了条件の評価」を反映し、実装方法を指定せず、問題が解消されたと判断できる状態を`完了条件`に残す。
候補の重複統合はverifier前の1回だけとする。

#### Phase 2.3: Standards指摘の選別と検証

Standardsが出力した指摘について以下を行う。確定指摘との重複破棄があるため、Phase 2.2の完了後に実行する。

- agent定義の出力形式(`問題` / `根拠` / `完了条件`)を満たす指摘だけを採用する
- 確定指摘と同じ行または同じ根本原因の指摘は破棄する(要修正事項を優先する)

**事実検証**: 採用した指摘は、1件ごとに `code-reviewer-verifier` を起動して検証する。

- Phase 2.2のprompt templateを使用し、`<candidate-type>` を `Standards`、`<candidate>` を指摘1件の全文、`<related-thread>` を `なし` とする。その他の入力と実行許可はPhase 2.2の敵対的検証と同じとする
- verdictが`confirmed`の指摘は、`path` / `line` / `side`、`カテゴリ`、`要約`、`問題`、`根拠`、`完了条件`、`検証結果`(verifierの根拠と実行結果)の内部レコードへ正規化し、確定規約指摘一覧とする
- verdictが`refuted` / `uncertain`の指摘は破棄する

Phase 2.5では、確定指摘一覧・確定規約指摘一覧・確定契約指摘一覧だけを指摘内容の入力として扱う。

#### Phase 2.4: Contract指摘の選別と検証

Contract SubAgentを起動した場合のみ実行する。確定指摘・確定規約指摘との重複破棄があるため、Phase 2.3の完了後に実行する。

- agent定義の出力形式(`問題` / `根拠` / `完了条件`)を満たす指摘だけを採用する
- 確定指摘・確定規約指摘と同じ行または同じ根本原因の指摘は破棄する
- 採用した指摘は1件ごとに `code-reviewer-verifier` で検証する。Phase 2.2のprompt templateを使用し、`<candidate-type>` を `Contract`、`<candidate>` を指摘1件の全文、`<related-thread>` を `なし`、`<spec-contract>` を解決済みspec contract全文とする
- verdictが`confirmed`の指摘は、`path` / `line` / `side`、`カテゴリ`、`要約`、`問題`、`根拠`(specの該当記述の引用)、`完了条件`、`検証結果`の内部レコードへ正規化し、確定契約指摘一覧とする。`refuted` / `uncertain`は破棄する

#### Phase 2.5: 指摘の校正とレビューレポートの作成

Phase 2.2の確定指摘一覧、Phase 2.3の確定規約指摘一覧、Phase 2.4の確定契約指摘一覧から、次の順でレビューレポートを作成する。

1. PRのタイトルと本文から出力言語を決める。
   - 主に日本語の場合は日本語
   - それ以外または判定が曖昧な場合は英語
2. 各一覧を、件数、順序、採否、技術的な意味、対象範囲、`path`、`line`、`side`を変えずに校正する。
   - 人間が一読で問題を理解できる平易で自然な表現にし、必要な技術概念だけを一般的な言葉で説明する
   - `カテゴリ`は出力言語に合わせ、問題の主な実害を表す1〜3語にする。処理状態、広すぎる観点、原因や仕組み、重要度、確度は使わない
   - `要約`は問題の中心を表す短い文にし、`完了条件`は実装方法ではなく、解消を判断できる状態を簡潔に示す
   - 推測、修正案、実装方法を追加せず、検証過程は出力しない
   - 確定指摘一覧では、`問題`を発生条件、原因、具体的な実害の順に整え、必要な前提とコード上の名称を残して、検証過程、証拠の列挙、重複を除く。`証拠`は起点を`path:line`、終点を実害が現れる場所とする最大3ホップの`発生経路`へ変換し、各`file:line`に短い説明を添える
   - 確定規約指摘一覧では、`問題`をdiffで観察できる事実、merge後への先送りが安全でない理由の順に整え、事実にない不利益を補わない。`根拠`は規約違反なら規約文書の`file:line`と該当記述を、コードスメルなら該当コードの`file:line`を残し、スメル名・原則名・設計用語を観察できる事実に置き換える
   - 確定契約指摘一覧では、`問題`を実装の現状、contractの約束との食い違いの順に整え、`根拠`にspecの該当記述の引用と実装の`file:line`を残す
   - 校正済み指摘一覧は`path` / `line` / `side`、`カテゴリ`、`要約`、`問題`、`発生経路`、`完了条件`だけを、校正済み規約指摘一覧と校正済み契約指摘一覧は`発生経路`の代わりに`根拠`を含める
3. Verdictを決める。
   - 校正済み指摘、校正済み規約指摘、校正済み契約指摘のいずれかが1件以上の場合は`REQUEST_CHANGES`
   - すべて0件の場合は`APPROVE`
   - Local spec由来のContract指摘もverdictへ計上する。レポート・inline comment・チャット報告での扱いはstep 5とPhase 3.2、Phase 4の分岐に従う
   - self reviewを含め、レポート内では`COMMENT`を使用しない。GitHub APIへ渡すeventはPhase 3.1で決める
4. 出力言語に対応するテンプレートを読み込む。
   - 日本語の場合は`references/report-ja.md`
   - 英語の場合は`references/report-en.md`
5. テンプレートを埋めてレポート本文を生成する。
   - `<reviewer-name>`: 実行中のレビュワー名。Claude Codeでは`Claude`
   - `<short-sha>`: `<latest-commit-sha>`の先頭7文字
   - CIが失敗している場合は概要に1行記載する
   - 校正済み指摘、校正済み規約指摘、校正済み契約指摘の順に同じ`指摘事項`または`Findings`セクションへ記載し、全体を1から連番にする
   - ただしLocal spec由来のContract指摘は個別項目として記載せず、概要に「Contract軸でN件の指摘があるが、内部specに基づくため詳細はチャット報告にのみ含める」と1行記載する。連番はセクションへ記載する指摘だけで振る

確定指摘一覧、`証拠`、`検証結果`は、校正後も内部確認用として保持する。
レポート本文とinline commentの指摘部分は、校正済み指摘一覧・校正済み規約指摘一覧・校正済み契約指摘一覧だけから生成する。

### Phase 3: レビューの投稿と置き換え

`--dry-run` が指定されていない場合のみ実行する。
最初にPRの現在のhead commit SHAを再取得し、Phase 1で保持した`<latest-commit-sha>`と比較する。一致しない場合は投稿、dismiss、resolveをすべてスキップしてPhase 4に進む。

#### Phase 3.1: event種別の決定

- self review モードでは `--event COMMENT` を渡すが，body 内の Verdict 表記は元のまま(`APPROVE` または `REQUEST_CHANGES`)にする(GitHub の仕様で自分の PR に `APPROVE` / `REQUEST_CHANGES` は投稿できないため)。
- self review 以外の通常レビューでは、レビューレポートのVerdictが `APPROVE` → `--event APPROVE`、`REQUEST_CHANGES` → `--event REQUEST_CHANGES` を渡す

#### Phase 3.2: inline commentの作成と投稿

Phase 2.5の校正済み各一覧について、`(path, line, side)`がPRのdiffに含まれるか検証し、diff内の指摘からinline comments JSONを生成する。
Local spec由来のContract指摘からはinline commentを生成しない。
レポート本文を解析してinline commentsを作らず、レポートと同じ校正済み一覧から生成する。
Finder由来の指摘の番号と、`カテゴリ` / `要約` / `問題` / `発生経路` / `完了条件` はレポート本文に一致させる。
Standards由来とContract由来の指摘の番号と、`カテゴリ` / `要約` / `問題` / `根拠` / `完了条件` もレポート本文に一致させる。
項目名は、Phase 2.5で決めた出力言語に合わせる。

inline comments JSONは以下の形式とし、由来にかかわらず`🔴 N:`で始める。

```json
[
  {
    "path": "src/auth.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "🔴 1: **[Category] <Issue summary>**\n\n**問題**: ...\n**発生経路**: `file:line` (説明) -> `file:line` (説明)\n**完了条件**: ...\n\n---\nCommented by <reviewer-name>"
  },
  {
    "path": "src/auth.ts",
    "line": 55,
    "side": "RIGHT",
    "body": "🔴 2: **[Category] <Issue summary>**\n\n**問題**: ...\n**根拠**: ...\n**完了条件**: ...\n\n---\nCommented by <reviewer-name>"
  }
]
```

`path` / `line` / `body` は必須。`side` は既定 `RIGHT` とし、削除行など変更前ファイル側にコメントする場合のみ `LEFT` を明示する。
`N:` はレポート本文の番号と一致させ、inline対象外の指摘があっても再採番しない。

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

開始時の`<latest-commit-sha>`に対するレビューとして、以下をまとめてユーザーに提示して終了する。

- Verdict、Finder由来・Standards由来・Contract由来の指摘件数 (Contract軸をスキップした場合はその旨)、レポート本文
- Local spec由来のため未投稿としたContract指摘の全文 (該当がある場合)
- レビューURL(`post_review.sh` の標準出力)。`--dry-run`、head commit更新、投稿失敗のいずれかで未投稿の場合は、その理由を明記する
- dismissした既存レビューとresolveした以前のthreadの件数(Phase 3.3を実行した場合のみ)
