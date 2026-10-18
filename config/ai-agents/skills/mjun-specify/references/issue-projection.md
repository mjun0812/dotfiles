# Issue Projection

承認した判断シートとAcceptance CriteriaをGitHub Issueへ投影する。Local specは作業を終えると使い捨てになるので、Issueは「何を、なぜ、どの範囲で作ったか」を後から辿れる場所として残す。作業中はLocal specの内容が正しい。

投影するのは、人間が承認した判断シートと、完了条件のAcceptance Criteriaだけである。contractの全文やdesign.mdは載せない。人間が読まない文書を外へ写しても辿る役に立たず、実装済みの振る舞いを定めるのはコードとテストだからである。Acceptance Criteriaを載せるのは、PRのレビューが紐づいたIssueから完了条件を読めるようにするためである。

## 投影先Issueの作成

`Source:` の無いspecで投影先Issueを作る場合は、リポジトリ内 `.github/ISSUE_TEMPLATE/` (無ければ [ISSUE_TEMPLATE](ISSUE_TEMPLATE)、日本語は [ISSUE_TEMPLATE_JA](ISSUE_TEMPLATE_JA)) から種別を選んでタイトルとラベル (既存ラベルのみ) を決め、`gh issue create` で作成して `spec.md` に `Source:` を記録する。本文は次の投影手順で書く。

## 投影手順

1. `gh issue view` で最新のIssueを取得する。取り込み後に付いたコメントや、Local specに反映されていない本文の記述があれば示し、specへ取り込むかを確認する (取り込むなら承認からやり直す。SKILL.mdのPhase 7)
2. Issue本文を一時ファイル経由で一括更新する (`gh issue edit <number> --body-file <tmpfile>`)。試作の画像があれば `--attach` で添付する
3. 変更サマリのコメントを1件足す

## 本文の構成

- 元の本文 → 区切り行 `<!-- projected-spec -->` → 投影範囲の順に置く。区切り行が無ければ本文全体を元の本文として残し、あれば区切り行より下だけを置き換える。投影時に作成したIssueは区切り行から始める。Issueのタイトルは変えない
- 投影範囲: Phase 5で承認した判断シート (`## 判断シート` 以下の各項目) + `## Acceptance Criteria` (`spec.md` のACを `- [ ]` で列挙)
- 外部の読み手は `.mjun/` を開けないので、判断シートの「文書」の行と `(review)` の印は除き、`.mjun/` 配下のパス (試作の画像など) は添付した画像に置き換える。task一覧は件数だけを残す
- 区切り行より下が外部で編集されていても、承認済みの内容で上書きする。手順1の確認で取り込む機会はすでに設けている
- ACのチェックボックスは投影時点のままにする。完了はPRの `Closes #N` で示し、実装側はIssueへ書き込まない
