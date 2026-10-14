# Issue Projection

承認済みcontractをGitHub Issueへ投影する手順と規則。

## 投影先Issueの作成

`Source:` の無いspecで投影先Issueを作る場合は、リポジトリ内 `.github/ISSUE_TEMPLATE/` (無ければ [ISSUE_TEMPLATE](ISSUE_TEMPLATE)、日本語は [ISSUE_TEMPLATE_JA](ISSUE_TEMPLATE_JA)) から種別を自動判定してタイトルとラベル (既存ラベルのみ) を決め、`gh issue create` で作成して `spec.md` に `Source:` を記録する。本文は次の投影手順で書く。

## 投影手順

1. `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントや、Local specに反映されていない本文の記述があれば提示し、specへ取り込むかを確認する
2. Issue本文を一時ファイル経由で一括更新する (`gh issue edit <number> --body-file <tmpfile>`)
3. 却下案と検討経緯を `gh issue comment` で記録し、変更サマリのコメントを1件追記する

## 本文の構成

- 元の本文 → 区切り行 `<!-- projected-spec -->` → 投影範囲の順に置く。区切り行が無ければ本文全体を元の本文として残し、あれば区切り行より下だけを置き換える。投影時に作成したIssueは区切り行から始める。Issueのタイトルは変更しない
- 投影範囲: contract (Context〜Out of Scope) + `## Decision Log` (`design.md` の `## Decisions` の要約表: 論点 / 決定 / 根拠) + 必要なら `## Design Notes` + `tasks.md` があれば `## Tasks` (taskタイトルを `- [ ]` で列挙)
- Dependenciesの `spec: <slug>` 行は、そのspecに `Source: #M` があれば `#M` に置き換え、無ければ除く
- 区切り行より下が外部で編集されていても、承認済みのLocal contractで上書きする
- task進捗は投影しない。`## Tasks` は承認時点のスナップショットとし、実装側はIssueへ書き込まない
