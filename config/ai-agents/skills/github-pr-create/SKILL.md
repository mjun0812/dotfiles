---
name: github-pr-create
description: >-
  Pull Requestを作成するSkill。現在のbranchからpull requestを作成する。言語指定可能。
  ユーザーが「PR作って」「pull request作成して」のように依頼したら使うこと。
allowed-tools: Read, Write, Task, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(mktemp:*)
---

# Create Pull Request

現在のbranchからpull requestを作成するSkill。PRのタイトルと説明文は、変更内容に基づいて自動生成する。PRの説明文は、コードを参照しなくてもPRの内容が理解できるように、概要・背景、関連Issue、実装方針、変更内容、影響範囲、検証結果を説明する。

## Arguments

- `language`: PRのタイトルと説明文の言語（例: "ja", "en"）。デフォルト: "English"
- `spec`: 解決するGitHub Issue番号 (任意。mjun-implementなどの呼び出し元から渡される)。関連Issue (`Closes`) の最優先候補として扱う
- `--dry-run`: 生成したPRタイトル・本文・base/head branchのみを提示し、pushや `gh pr create` を実行せず終了する

base branchは引数ではなく自動推定で決定する（事前チェック2を参照）。ユーザーが会話で明示した場合（「developに向けてPRを作って」等）はそれを最優先する。

## 0. 事前チェック

1. **default branch上での実行を防止**:
   - 現在のbranchがdefault branch（`main`, `master` 等）の場合、PRを作成せずエラーメッセージを出して中止
2. **base branchの自動推定**:
   - ユーザーが会話でbase branchを明示した場合は、それを推定より優先して使用する
   - 明示が無い場合は、HEADの分岐元をmerge-baseの距離で推定する:
     1. base候補を列挙する: repositoryのdefault branch（`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`）、open PRのhead branch（`gh pr list --json headRefName`）、リポジトリに存在する長命branch（`develop`, `release/*` など）。現在のbranch自身は除く
     2. 各候補Bについて `git merge-base HEAD origin/B` を取り、`<merge-base>..HEAD` のcommit数（= PRに入るcommit数）を数える
     3. commit数が最小（かつ1以上）の候補をbaseに選ぶ。同数の場合は「open PRを持つbranch > default branch」の優先順位で決める
   - 以下のいずれかに該当する場合は推定を打ち切り、AskUserQuestionで候補branchを選択肢として提示してユーザーに確認する:
     - 最小commit数の候補が複数残り、優先順位でも1つに決まらない
     - base候補が1つも見つからない
     - 選定したbaseの `origin/<base>..HEAD` に、今回の作業と無関係なcommitが混ざっている
   - 決定後、選定したbaseとその理由、`git log --oneline origin/<base>..HEAD` の一覧を必ず報告する（推定が誤っていればユーザーがここで気付ける）
   - tracking branch（`@{upstream}`）はpush先の判定にだけ使い、PRのbase branchとして扱わない。feature branchのupstreamは通常 `origin/<current-branch>` であり、baseに使うと `origin/<base>..HEAD` が空になるため
3. **既存PRの確認**:
   - `gh pr view --json url,state` で既存のPRを確認
   - PRが既に存在する場合は、そのURLと状態を表示して中止
4. **base branchの最新化**:
   - 比較基準を最新化するため、base branch決定後に `git fetch origin <base-branch>` を実行する
   - 以降のcommit確認と差分取得では、最新化した `origin/<base-branch>` を基準にする
5. **commitの存在確認**:
   - `git log origin/<base-branch>..HEAD` が空でないことを確認
   - 未commitの変更は無視してcommit済みの変更のみを対象とする
   - commitがない場合は中止
6. **PR templateの確認**:
   - 以下のパスを順に確認し、最初に見つかったものを使用:
     - `.github/pull_request_template.md`
     - `.github/PULL_REQUEST_TEMPLATE.md`
     - `.github/PULL_REQUEST_TEMPLATE/` ディレクトリ内のファイル
     - `docs/pull_request_template.md`
   - repositoryにPR templateが存在しない場合、指定言語に応じて以下を使用:
     - English: [`references/pr_template.md`](references/pr_template.md)
     - Japanese: [`references/pr_template_ja.md`](references/pr_template_ja.md)
   - repositoryのtemplateに「4. 説明文の生成」で定める6項目と同義の見出しがある場合は、その見出しを原文のまま使用する
   - 同義の見出しがない項目は指定言語の見出しを補い、6項目を所定の順序で記載する。repository固有の追加項目は削除しない
7. Conventional Commits規約 [`references/conventional_commits.md`](references/conventional_commits.md)

## 1. リモートへのpush

- `--dry-run` が指定された場合はpushを行わず、以降の差分取得はローカルのcommitと `origin/<base-branch>` の比較のみで行う
- `git push` または `git push -u origin <current-branch>` で現在のbranchをpushする
- 通常のpushが失敗し、履歴書き換えが必要な場合のみ、ユーザーに確認して `git push --force-with-lease` を実行する

## 2. 変更内容の取得

- 差分の概要: `git diff --stat origin/<base-branch>..HEAD`
- commitの一覧: `git log --oneline origin/<base-branch>..HEAD`
- 詳細な差分: `git log -p origin/<base-branch>..HEAD`
- **注意**: 差分が大きい場合（目安: 500行超）は `git diff --stat` の結果を中心に使い、個別ファイルの差分は必要に応じて `git diff origin/<base-branch>..HEAD -- <file>` で確認する

## 3. PRタイトル、関連Issue、Labelの生成

`2. 変更内容の取得` で得た差分とcommitを根拠に、以下を順に決定する。

### タイトル

- Conventional Commits規約に従い、commitとブランチの差分の内容を要約した簡潔なタイトルにする
- 1つのcommitのみの場合、そのcommitメッセージをベースにする

### 関連Issue

- `spec` としてIssue番号が渡された場合は、それを解決するIssue (`Closes`) の最優先候補にする
- branch名からIssue番号を抽出する（例: `feature/123-add-something` → `#123`）
- commitメッセージから `fix #456`, `closes #789`, `refs #101` 等のキーワードを検出する
- `gh issue list --state open --json number,title` のタイトルを変更内容と突き合わせ、関連するIssueを探す
- 検出したIssueはタイトルだけで判断せず、本文を読んで問題、背景、受け入れ条件を確認する
- open issueが大量にある場合は、検索条件を絞るか、この突き合わせのみSubAgentに委譲してよい

### Label

- リポジトリのlabelを取得し、その中から選定する: `gh label list --json name,description`
- 存在しないlabelは付与しない。合うlabelが無い場合は付与しない

## 4. 説明文の生成

- **PR template**: 事前チェックで選択したtemplateの言語とrepository固有の追加項目に従う（repositoryのtemplateは指定言語では翻訳しない）
- `2. 変更内容の取得` で取得した差分概要、commit一覧、詳細差分を根拠にして本文を生成する
- 本文には、以下の6項目を必ずこの順序で記載する。小さいPRでも項目を省略せず、内容を簡潔にする
  1. **概要・背景 / Overview and Background**: 最初にこのPRで実現する結果を述べ、続けて変更前の挙動、発生条件、原因、利用者や運用への影響を説明する。同じ内容を概要と背景として繰り返さない
  2. **関連Issue / Related Issues**: 解決するIssueには `Closes #xxx`、参照のみのIssueには `Related to #xxx` を使う。関連Issueがない場合は、指定言語で該当なしと明記する
  3. **実装方針 / Implementation Approach**: 解決方法を概念的に説明し、その方法を選んだ理由を記載する。非自明な設計判断がある場合は、制約や採用しなかった案の理由も記載する
  4. **変更内容 / Changes**: diffをファイル単位で言い換えるだけではなく、変わる挙動や責務ごとに主な変更をまとめる
  5. **影響範囲 / Impact**: user-facing change、互換性、performance、security、deployment、既知の制約から該当するものを記載し、影響しない範囲も明確にする
  6. **検証結果 / Validation Results**: 何をどの方法で検証し、どの結果になったかを記載する。bug修正やperformance変更では、可能な限り変更前後を比較できる再現結果、log、数値を示す
- 検証で実行したコマンドと結果は、コピペ可能な形式で記載する
- CIで自動実行されるlint・format・型チェックは記載しない（そのチェック設定自体を変更したPRを除く）。記載するのはCIが検証しない動作確認の手順と結果
- テストを実行していない場合は、未実行であることと理由を明記する
- PRタイトル・本文に `.mjun/` 配下のパスやgit管理外の内部文書 (Local specなど) を言及しない。これらは内部文書であり、外部へ見せる参照にはGitHub Issueだけを使う
- diff、commit、関連Issueから確認できない事実を推測で補わない。本文の理解に必要な情報が不足する場合はユーザーに確認する
- PR作成前に、6項目が所定の順序で存在し、templateの説明コメントや未記入のplaceholderが残っていないことを確認する

## 5. Pull Requestの作成

`--dry-run` が指定された場合は、生成したPRタイトル・本文・base/head branchのみを提示し、`gh pr create` を実行せずに終了する。

1. 生成したPR説明文は、先にMarkdownファイルへ書き出す:
   - 例: `/tmp/YYYYMMDD-HHMMSS-pr-body.md`
   - `--body "<PR Description>"` のように本文を直接コマンド引数へ埋め込むことは禁止
   - 複数行本文、Markdown、引用符、バッククォート、絵文字を安全に渡すため、必ず `--body-file` を使う
2. PRを作成する:
   `--assignee @me` を**必ず**付与し、PRの担当者を自分（PR作成者）に設定する

   ```bash
   gh pr create \
     --base <base-branch> \
     --title "<PR Title>" \
     --body-file /tmp/YYYYMMDD-HHMMSS-pr-body.md \
     --assignee @me \
     [--label <name> ...]
   ```

   labelはステップ3で決定した自動判定の結果を付与する（該当labelが無い場合は付与しない）

## 6. 結果の表示

以下の情報をまとめて表示する:

- 作成したPRのURL
- タイトル
- base branch → head branch（baseを推定で決めた場合はその理由）
- 関連Issue（検出された場合）
- assignee（`@me`）
- label（自動付与された場合）
- 変更の概要（ファイル数、追加行数、削除行数）
