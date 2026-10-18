---
name: mjun-spec-review
description: >-
  spec (`.mjun/specs/<slug>`、GitHub Issue / PR番号、設計Markdown、または会話中の設計) のcontractと実装設計を、fresh contextのreviewerとverifierで敵対的にレビューし、confirmedの指摘だけをチャットへ返すSkill。ファイルは編集しない。
  ユーザーが「このspecをレビューして」「#Nの仕様を検査して」「設計の穴を探して」と依頼したときや、呼び出し元skillから承認前のspec検査を渡されたときに使うこと。
  人間との対話で仕様の分岐を決める用途や、コード差分のレビュー (PR番号を渡されてもコードは見ない) には使わない。
allowed-tools: Task, Read, Glob, Grep, AskUserQuestion, Bash(git rev-parse:*), Bash(gh issue view:*), Bash(gh pr view:*)
---

# mjun-spec-review

specを、それを書いた会話とは別のfresh contextで敵対的に検査するSkill。書き手の判断と根拠を未検証の仮説として扱い、contractの明文・sourceの原文・実コード・steeringだけを根拠に、承認・実装の前に解消すべき問題を探す。

検査は3つの軸で行う。**contract軸**はspec自身の整合と検証可能性を、**design軸**は実装設計がcontractを満たしコードベースに馴染むかを、**tasks軸** (呼び出し元からtask planのdraftを渡されたときだけ) はtask分解がcontractと実装設計を正しく実現しているかを見る。各軸のreviewerが候補を出し、verifierが反証し、`confirmed` だけを返す。厳しさは探索範囲と反証の深さに使い、指摘の証拠基準は下げない。

ファイルは読むだけで、spec・design・decisions・コードを変更しない。指摘をどう反映するかは呼び出し元 (人間、または承認前検査としてこのskillを呼んだ側) が決めるからである。

## Arguments

- `source` (任意): `.mjun/specs/<slug>` (配下のファイルパスでも可)、GitHub Issue番号 (`#123` / `123`)、PR番号 (`pr#45` / PRのURL)、または設計を書いたMarkdownのパス。未指定なら会話中の設計・計画を対象にする

## Task

### Phase 1: sourceの解決とcontextの収集

reviewerとverifierはこの会話を読めないので、検査に要る材料をここで揃える。材料は、contract (要求・制約・スコープ)、実装設計、決定の経緯、sourceの原文、Human-owned decisionの一覧、参照文書のパス一覧である。呼び出し元から渡されたもの (sourceの原文、Human-owned decisionの一覧、task planのdraft) は取得し直さない。出力言語はsourceの言語に合わせる。

repository rootは `git rev-parse --show-toplevel` で決める。Git repositoryでなければ現在のディレクトリを使う。SubAgentの作業ディレクトリが親と同じとは限らないので、パスはrepository rootからの絶対パスで渡す。

sourceの形ごとに、材料を次のように取る。

- **spec mode** (`.mjun/specs/<slug>`): `spec.md` がcontract、`design.md` が実装設計、その `## Decisions` が決定の経緯、そのうち `Owner: human` のdecisionの見出しがHuman-owned decisionの一覧になる。`spec.md` のH1直下に `Source: #N` があれば、`gh issue view N --json title,body,comments` の本文とコメントをsourceの原文にする
- **Issue番号**: 取り込み済みのIssueは作業中のLocal specが正しいので、`spec.md` に `Source: #N` を持つ `status: active` のspecを探し、見つかればspec modeで扱う (複数あれば一覧から選んでもらう。`status: done` のspecは作業を終えた使い捨ての文書なので探さない)。無ければ **issue mode** とし、`gh issue view N --json title,body,comments` で読む。本文に区切り行 `<!-- projected-spec -->` があれば、その下は投影された判断シートとAcceptance Criteriaなので、判断シートの目的・やること・やらないこと・動作の例とACをcontract、「人間が決めたこと」「agentが決めたこと」を決定の経緯 (前者の見出しがHuman-owned decisionの一覧) にし、区切り行より上の元の本文とコメントをsourceの原文にする。区切り行が無ければ、本文の要求・制約・スコープの記述をcontract、実装方針の記述を実装設計、コメントをsourceの原文にし、Human-owned decisionの一覧は無い。issue modeに `design.md` に当たる実装設計は無いので、design軸は本文に実装方針があるときだけ起動する
- **PR番号**: `gh pr view N --json body` の `Closes #N` / `Fixes #N` / `Resolves #N` からIssue番号を取り出し、Issue番号として解決する (複数あれば一覧から選んでもらう)。無ければ検査対象のspecを特定できないと報告して中止する。PRのコード差分は読まない
- **doc mode** (`.mjun/specs/` 外のMarkdown): 要求・制約・スコープの記述がcontract、実装方針の記述が実装設計になる
- **conversation mode** (source未指定): 会話中の設計・計画を、contractと設計本文に分けて書き起こす。素材が無ければ中止する

どのmodeでも、steering (`.mjun/steering/*.md`)、用語集 `CONTEXT.md` (repo直下、無ければ `.mjun/CONTEXT.md`)、ADR (置き場所は [共通記録規則](../mjun-steering/references/glossary_and_adr.md#置き場所の決め方) で決まる `docs/adr/` か `.mjun/steering/adr/`)、対象以外の `status: active` のspecの `spec.md` と `design.md` のパス一覧を集める。中身は、検査に関係するものをSubAgentが自分で読む。

`gh` が失敗したら中止してエラーを報告する。

### Phase 2: reviewerによる候補の発見

書き手のcontextを持たない目で、問題の候補を広く集める。採否はPhase 3で決めるので、ここでは取りこぼさないことを優先する。

軸ごとにfresh contextのSubAgentを1体ずつ、並列に起動する。contract軸は [templates/contract-reviewer-prompt.md](templates/contract-reviewer-prompt.md)、design軸は [templates/design-reviewer-prompt.md](templates/design-reviewer-prompt.md) にPhase 1の材料を合成する。材料が無い軸は起動しない (実装設計が無ければdesign軸)。task planのdraftが渡され、2 task以上を含むときは、[mjun-to-tasksのtask-plan reviewer](../mjun-to-tasks/templates/reviewer-prompt.md) にcontract、実装設計、draftを合成し、tasks軸として同時に起動する。reviewerには読み取り (Read / Glob / Grep) だけを許可する。

候補として採るのは、verifierが反証できる形のものだけである。contract軸とdesign軸は、`## Candidates` のうちテンプレートの全フィールドを持つものを採る。tasks軸は `## Task Plan Review` の `FINDINGS` の各項目を `軸: tasks` の候補として扱う (深刻度とHuman-owned decisionとの矛盾は持たない)。同じセクションで同じ根本原因の候補は、軸が違っても1件にまとめる。まとめた後、候補のIDを `C-1` から通し番号で振り直す。軸ごとのreviewerは別々に番号を振るので、そのままではverifierの `CANDIDATE` と対応づけられない。

書き手の意図や見た目の確からしさを理由に、ここで候補を捨てない。承認前検査では親が書き手と同じcontextを持つので、親の判断で捨てるとfresh contextで検査する意味がなくなる。

### Phase 3: verifierによる反証

候補のうち、反証に耐えたものだけを残す。

候補の全件を [templates/verifier-prompt.md](templates/verifier-prompt.md) にPhase 1の材料 (tasks軸の候補があればdraftも) と合わせて合成し、verifierのSubAgentを1体だけ起動する。1体にすると、文書を読むのが1回で済み、起動と完了待ちも1回で終わる。候補が0件なら起動しない。verifierにはrepository内の読み取りと `git` の読み取り系コマンドだけを許可する。

候補が多くても、親が自分で検証してverifierの代わりにしない。Phase 2と同じ理由で、親による検証は書き手の判断の追認になる。

出力の各 `## Verdict` を `CANDIDATE` で候補に対応づけ、`confirmed` だけを確定指摘にする (`refuted` と `uncertain` は捨てる)。`## Verdict` の無い候補があれば、同じverifierを継続して1回だけ求め、それでも無ければ `uncertain` として捨てる。確定指摘の根拠に `file:line` があれば、親がその行をReadし、引用が実在して主張と一致するものだけを残す。存在しない行を根拠にした指摘は呼び出し元の修正を誤らせるので、verifierの報告だけで実在を認めない。

### Phase 4: 出力

結果をチャットへ出力し、ファイルには保存しない。確定指摘は、contract軸を観点番号順に、次にdesign軸を深刻度 `contract` → `boundary` → `structure` の順 (同じ深刻度は観点番号順) に、最後にtasks軸を観点番号順に並べる。呼び出し元が使うのは確定指摘だけなので、verifierの検証過程、捨てた候補、内部の証拠は出力しない。

応答の最後に、次の構造化ブロックを1つだけ出力する。呼び出し元skillは合否を `- VERDICT:` で、修正対象を `FINDINGS` で、人間への再確認が必要なdecisionを `HUMAN_DECISION_CONFLICTS` で読み取る。パースできるように、見出しと値の語彙は変えず、ブロックの後に何も書かない。補足は各フィールドの中に書く。

```
## Spec Review
- SOURCE: <mode と対象 (パス、Issue番号、PR番号)。conversation modeでは「会話中の設計」>
- VERDICT: PASS | NEEDS_FIXES
- FINDINGS:
  1. [contract:<観点1〜8>] <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <contract / sourceの引用、file:line、steering / ADR / CONTEXT.mdの引用> — 満たすべき状態: <修正方針ではなく、満たすべき状態>
  2. [design:<観点1〜7>][<contract | boundary | structure>] <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <同上> — 満たすべき状態: <同上>
  3. [tasks:<観点1〜6>] <対象task ID> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <同上> — 満たすべき状態: <同上>
- HUMAN_DECISION_CONFLICTS: <decisionの見出しと矛盾の内容。無ければ none>
- SUMMARY: <1文の要約>
```

FINDINGSが0件で、HUMAN_DECISION_CONFLICTSもnoneのときだけPASSとする。HUMAN_DECISION_CONFLICTSに挙げた矛盾はFINDINGSにも含める。検査しきれなかった範囲はSUMMARYに書く (省略した軸、材料が無く見られなかった観点、Git repositoryでないためにコードと照合できなかったこと)。PASSを「問題が無い」と読み違えないようにするためである。
