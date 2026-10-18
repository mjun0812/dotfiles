---
name: mjun-spec-review
description: >-
  spec (`.mjun/specs/<slug>`、GitHub Issue / PR番号、設計Markdown、または会話中の設計) を、source・steering・ADR・用語集・他のactiveなspec・既存のコードと照らし合わせ、fresh contextのreviewerとverifierで敵対的にレビューし、confirmedの指摘だけをチャットへ返すSkill。ファイルは編集しない。
  ユーザーが「このspecをレビューして」「#Nの仕様を検査して」「specがコードやADRと食い違っていないか見て」と依頼したときや、呼び出し元skillから承認前のspec reviewを渡されたときに使うこと。
  人間との対話で仕様の分岐を決める用途や、コード差分のレビュー (PR番号を渡されてもコードは見ない) には使わない。
allowed-tools: Task, Read, Glob, Grep, AskUserQuestion, Bash(git rev-parse:*), Bash(gh issue view:*), Bash(gh pr view:*), Bash(zsh:*)
---

# mjun-spec-review

specを、それを書いた会話とは別のfresh contextで敵対的にレビューするSkill。書き手の判断と根拠を未検証の仮説として扱い、specの外に実在するもの (sourceの原文、steering・ADR・用語集、他のactiveなspec、既存のコード) と照らし合わせて、承認・実装の前に解消すべき食い違いを探す。reviewerが候補を出し、verifierが反証し、`confirmed` だけを返す。厳しさは探索範囲と反証の深さに使い、指摘の証拠基準は下げない。

指摘として残すかは、観点の種類ではなく根拠の場所で決める。根拠は、specの外に実在するもの (実コードの `file:line`、sourceの原文、steering・ADR・用語集・既存の文書、他のspec) か、人間が決めたdecisionでなければならない。spec内の記述どうしの読み比べや一般論だけを根拠にした懸念 (起こると決まっていない失敗、将来に備えるだけの構造) は扱わない。コードで確かめていない懸念を文書だけから論じると、起こりもしない懸念が増え、その対応に承認前の時間を使うことになる。こうした懸念は、実装のreviewerがdiffに対して原則 (`mjun-implement/principles/`) を当てて見る。設計が成り立つか不安なら、mjun-specifyが最小実装を作って確かめる。逆に、根拠がspecの外にあれば、設計の欠落 (既存の仕組みとの関わりが決まっていない、Acceptance Criterionを満たせない) も指摘する。過去のspec reviewでは、こうしたコードを根拠にした欠落が確定指摘の多くを占め、実装前に直す価値があった。例外は永続データの形式を変える設計で、既存データの扱いは根拠が設計の記述だけでも承認前に見る。実装後に気付いても、データは元に戻せないからである。task分解はレビューしない。taskの切り方の誤りは、実装中に再分解の要求として現れ、そこで直せる。

ファイルは読むだけで、spec・design・decisions・コードを変更しない。指摘をどう反映するかは呼び出し元 (人間、または承認前のspec reviewとしてこのskillを呼んだ側) が決めるからである。

## Arguments

- `source` (任意): `.mjun/specs/<slug>` (配下のファイルパスでも可)、GitHub Issue番号 (`#123` / `123`)、PR番号 (`pr#45` / PRのURL)、または設計を書いたMarkdownのパス。未指定なら会話中の設計・計画を対象にする

## Task

### Phase 1: sourceの解決とcontextの収集

reviewerとverifierはこの会話を読めないので、レビューに要る材料をここで揃える。材料は、contract (要求・制約・スコープ)、実装設計、決定の経緯、sourceの原文、Human-owned decisionの一覧、参照文書のパス一覧である。呼び出し元から渡されたもの (sourceの原文、Human-owned decisionの一覧) は取得し直さない。出力言語はsourceの言語に合わせる。

repository rootは `git rev-parse --show-toplevel` で決める。Git repositoryでなければ現在のディレクトリを使う。SubAgentの作業ディレクトリが親と同じとは限らないので、パスはrepository rootからの絶対パスで渡す。

sourceの形ごとに、材料を次のように取る。

- **spec mode** (`.mjun/specs/<slug>`): `spec.md` がcontract、`design.md` (あれば骨組みの `skeleton.patch` も) が実装設計、その `## Decisions` が決定の経緯、そのうち `Owner: human` のdecisionの見出しがHuman-owned decisionの一覧になる。`spec.md` のH1直下に `Source: #N` があれば、`gh issue view N --json title,body,comments` の本文とコメントをsourceの原文にする。あわせて `zsh <skill-dir>/../mjun-to-tasks/scripts/check_spec_format.sh <spec-dir>` を実行し、出力の各行を形式の指摘としてPhase 4へ回す。形式の崩れと、Evidence・Change Outline・依存先specのパスの実在は、scriptが確実に見つける。reviewerにはscriptで見つからない食い違いだけを探させる
- **Issue番号**: 取り込み済みのIssueは作業中のLocal specが正しいので、`spec.md` に `Source: #N` を持つ `status: active` のspecを探し、見つかればspec modeで扱う (複数あれば一覧から選んでもらう。`status: done` のspecは作業を終えた使い捨ての文書なので探さない)。無ければ **issue mode** とし、`gh issue view N --json title,body,comments` で読む。本文に区切り行 `<!-- projected-spec -->` があれば、その下は投影された判断シートとAcceptance Criteriaなので、判断シートの目的・やること・やらないこと・動作の例とACをcontract、「人間が決めたこと」「agentが決めたこと」を決定の経緯 (前者の見出しがHuman-owned decisionの一覧) にし、区切り行より上の元の本文とコメントをsourceの原文にする。区切り行が無ければ、本文の要求・制約・スコープの記述をcontract、実装方針の記述を実装設計、コメントをsourceの原文にし、Human-owned decisionの一覧は無い
- **PR番号**: `gh pr view N --json body` の `Closes #N` / `Fixes #N` / `Resolves #N` からIssue番号を取り出し、Issue番号として解決する (複数あれば一覧から選んでもらう)。無ければレビュー対象のspecを特定できないと報告して中止する。PRのコード差分は読まない
- **doc mode** (`.mjun/specs/` 外のMarkdown): 要求・制約・スコープの記述がcontract、実装方針の記述が実装設計になる
- **conversation mode** (source未指定): 会話中の設計・計画を、contractと設計本文に分けて書き起こす。素材が無ければ中止する

どのmodeでも、steering (`.mjun/steering/*.md`)、用語集 `CONTEXT.md` (repo直下、無ければ `.mjun/CONTEXT.md`)、ADR (置き場所は [共通記録規則](../mjun-steering/references/glossary_and_adr.md#置き場所の決め方) で決まる `docs/adr/` か `.mjun/steering/adr/`)、対象以外の `status: active` のspecの `spec.md` と `design.md` のパス一覧を集める。中身は、レビューに関係するものをSubAgentが自分で読む。

`gh` が失敗したら中止してエラーを報告する。

### Phase 2: reviewerによる候補の発見

書き手のcontextを持たない目で、問題の候補を広く集める。採否はPhase 3で決めるので、ここでは取りこぼさないことを優先する。

[templates/reviewer-prompt.md](templates/reviewer-prompt.md) にPhase 1の材料を合成し、fresh contextのSubAgentを1体起動する。reviewerには読み取り (Read / Glob / Grep) だけを許可する。

候補として採るのは、`## Candidates` のうちテンプレートの全フィールドを持つものだけである。欠けた候補は、verifierが反証できない。

書き手の意図や見た目の確からしさを理由に、ここで候補を捨てない。承認前のspec reviewでは親が書き手と同じcontextを持つので、親の判断で捨てるとfresh contextでレビューする意味がなくなる。

### Phase 3: verifierによる反証

候補のうち、反証に耐えたものだけを残す。

候補の全件を [templates/verifier-prompt.md](templates/verifier-prompt.md) にPhase 1の材料と合わせて合成し、verifierのSubAgentを1体だけ起動する。1体にすると、文書を読むのが1回で済み、起動と完了待ちも1回で終わる。候補が0件なら起動しない。verifierにはrepository内の読み取りと `git` の読み取り系コマンドだけを許可する。

候補が多くても、親が自分で検証してverifierの代わりにしない。Phase 2と同じ理由で、親による検証は書き手の判断の追認になる。

出力の各 `## Verdict` を `CANDIDATE` で候補に対応づけ、`confirmed` だけを確定指摘にする (`refuted` と `uncertain` は捨てる)。`## Verdict` の無い候補があれば、同じverifierを継続して1回だけ求め、それでも無ければ `uncertain` として捨てる。確定指摘の根拠に `file:line` があれば、親がその行をReadし、引用が実在して主張と一致するものだけを残す。存在しない行を根拠にした指摘は呼び出し元の修正を誤らせるので、verifierの報告だけで実在を認めない。

### Phase 4: 出力

結果をチャットへ出力し、ファイルには保存しない。確定指摘は、形式の指摘を先に、次にreviewerの観点番号順に並べる。呼び出し元が使うのは確定指摘だけなので、verifierの検証過程、捨てた候補、内部の証拠は出力しない。

応答の最後に、次の構造化ブロックを1つだけ出力する。呼び出し元skillは合否を `- VERDICT:` で、修正対象を `FINDINGS` で、人間への再確認が必要なdecisionを `HUMAN_DECISION_CONFLICTS` で読み取る。パースできるように、見出しと値の語彙は変えず、ブロックの後に何も書かない。補足は各フィールドの中に書く。

```
## Spec Review
- SOURCE: <mode と対象 (パス、Issue番号、PR番号)。conversation modeでは「会話中の設計」>
- VERDICT: PASS | NEEDS_FIXES
- FINDINGS:
  1. [形式] <scriptの出力の1行 (<file>:<line>: <内容>)>
  2. [<観点1〜6>] <contract | 実装設計> の <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <sourceの引用、steering / ADR / CONTEXT.md・既存の文書の引用、他specのパスと引用、file:line、Human-owned decisionの引用> — 満たすべき状態: <修正方針ではなく、満たすべき状態>
- HUMAN_DECISION_CONFLICTS: <decisionの見出しと矛盾の内容。無ければ none>
- SUMMARY: <1文の要約>
```

FINDINGSが0件で、HUMAN_DECISION_CONFLICTSもnoneのときだけPASSとする。HUMAN_DECISION_CONFLICTSに挙げた矛盾はFINDINGSにも含める。見られなかった範囲はSUMMARYに書く (材料が無く飛ばした観点、spec mode以外で形式を確かめていないこと、Git repositoryでないためにコードと照らし合わせられなかったこと)。PASSを「問題が無い」と読み違えないようにするためである。
