# Issue Projection

承認した判断シートとAcceptance CriteriaをGitHub Issueへ投影する。Local specは作業を終えると使い捨てになるので、Issueは「何を、なぜ、どの範囲で作ったか」を後から辿れる場所として残す。作業中はLocal specの内容が正しい。

投影するのは、人間が承認した判断シートと、完了条件のAcceptance Criteriaだけである。contractの全文やdesign.mdは載せない。人間が読まない文書を外へ写しても辿る役に立たず、実装済みの振る舞いを定めるのはコードとテストだからである。Acceptance Criteriaを載せるのは、PRのレビューが紐づいたIssueから完了条件を読めるようにするためである。

## 投影先Issueの作成

`Source:` の無いspecで投影先Issueを作る場合は、Skill toolで `github-issue-create` を呼び、起票を任せる。templateの選択、ラベル、関連Issueの検索、作成前の確認は、そのskillが持つ。下書きの素材には、判断シートの目的・やること・やらないことを渡す。作られたIssueの番号を `spec.md` に `Source:` として記録し、そのIssueへ次の投影手順で投影する。`github-issue-create` が書いた本文は、元の本文として区切り行の上に残る。

## 投影先の決め方

投影先は、Issueの作成者で決まる。`gh issue view <number> --json author --jq .author.login` が認証ユーザー (`gh api user --jq .login`) と一致すれば本文、一致しなければ (他のユーザーやbot) 投影コメントにする。他人が書いた本文を書き換えると、作成者の言葉を改変したことになるからである。他人のIssueの本文を書き換える `gh issue edit --body` / `--body-file` は、PreToolUse hookも拒否する。

- 本文: 元の本文の下に、区切り行 `<!-- projected-spec -->` と投影範囲を置く
- 投影コメント: 先頭行が区切り行 `<!-- projected-spec -->` の、認証ユーザーのコメント。1つのIssueに1件だけ置き、投影し直すときは同じコメントを更新する

## 投影手順

1. `gh issue view` で最新のIssueを取得する。取り込み後に付いたコメントや、Local specに反映されていない本文の記述があれば示し、specへ取り込むかを確認する (取り込むなら承認からやり直す。SKILL.mdのPhase 7)。本文の区切り行より下と投影コメントは前回の投影なので、取り込み後の変化に数えない
2. 投影内容を一時ファイルに書き、投影先へ反映する。試作の画像があれば `--attach` で添付する
   - 本文: `gh issue edit <number> --body-file <tmpfile>`
   - 投影コメント (まだ無い): `gh issue comment <number> --body-file <tmpfile>`
   - 投影コメント (既にある): `gh api repos/{owner}/{repo}/issues/<number>/comments --paginate --jq '.[] | select(.user.login == "<認証ユーザー>" and (.body | startswith("<!-- projected-spec -->"))) | .id'` で探したコメントを、`gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -F body=@<tmpfile>` で更新する
3. 変更サマリのコメントを1件足す。本文や既存の投影コメントの更新はwatcherに通知されないためである。投影コメントを新しく投稿したときは、その投稿が通知になるので足さない

## 投影の構成

- 本文: 元の本文 → 区切り行 `<!-- projected-spec -->` → 投影範囲の順に置く。区切り行が無ければ本文全体を元の本文として残し、あれば区切り行より下だけを置き換える。投影時に作成したIssueは区切り行から始める。Issueのタイトルは変えない
- 投影コメント: 区切り行 `<!-- projected-spec -->` → 投影範囲の順に置く。Issueの本文とタイトルは変えない
- 投影範囲: Phase 5で承認した判断シート (`## 判断シート` 以下の各項目) + `## Acceptance Criteria` (`spec.md` のACを `- [ ]` で列挙)
- 外部の読み手は `.mjun/` を開けないので、判断シートの「文書」の行と `(review)` の印は除き、`.mjun/` 配下のパス (試作の画像など) は添付した画像に置き換える。task一覧は件数だけを残す
- 区切り行より下 (投影コメントでは全体) が外部で編集されていても、承認済みの内容で上書きする。手順1の確認で取り込む機会はすでに設けている
- ACのチェックボックスは投影時点のままにする。完了はPRの `Closes #N` で示し、実装側はIssueへ書き込まない
