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
検査は2軸で行う。**contract軸**はspec自身の整合と検証可能性を、**design軸**は実装設計がcontractを満たしコードベースに馴染むかを見る。両軸のreviewerが出した候補をverifierが1件ずつ反証し、`confirmed` だけを出力する。厳しさは探索範囲と反証の深さに使い、指摘の証拠基準は下げない。
ファイルは読むだけで、spec・design・decisions・コードを変更しない。指摘の反映は呼び出し元 (人間、または承認前検査としてこのskillを呼んだ側) が判断する。

## Arguments

- `source` (任意): `.mjun/specs/<slug>` (配下のファイルパスでも可)、GitHub Issue番号 (`#123` / `123`)、PR番号 (`pr#45` / PRのURL)、または設計を書いたMarkdownのパス。未指定なら会話中の設計・計画を対象にする

呼び出し元skillから文脈 (sourceの原文、Human-owned decisionの一覧) を渡された場合はそれを使い、同じものを取得し直さない。

## Task

### Phase 1: sourceの解決とcontextの収集

1. repository rootを `git rev-parse --show-toplevel` で特定する。Git repositoryでなければ現在のディレクトリを使い、コードベースとの整合検査が限定的になる旨をPhase 4のSUMMARYに含める
2. sourceの形からmodeを決め、reviewerに渡す材料を集める。出力言語はsourceの言語に合わせる
   - **spec mode** (`.mjun/specs/<slug>`): `spec.md` をcontract、`design.md` を実装設計、あれば `decisions.md` を決定の経緯として渡す。`design.md` が無ければdesign軸を省略し、その旨をSUMMARYに含める。`decisions.md` の `Owner: human` のdecision (D番号とタイトル) をHuman-owned decisionの一覧にする。`spec.md` のH1直下に `Source: #N` があれば `gh issue view N --json title,body,comments` で本文とコメントを取得し、sourceの原文とする
   - **Issue番号**: `status: active` のspecの `spec.md` から `Source: #N` を検索し、無ければ `status: done` のspecも検索する。見つかればそのspecをspec modeで扱う (複数ヒットした場合は一覧を提示して選んでもらう)。見つからなければ **issue mode**: `gh issue view N --json title,body,comments` で取得し、本文のContext〜Out of Scopeをcontract、`## Design Notes` があれば実装設計 (無ければdesign軸を省略)、`## Decision Log` があれば決定の経緯、コメントをsourceの原文として扱う。Human-owned decisionの一覧は無いものとして渡す
   - **PR番号**: `gh pr view N --json body` で本文を取得し、`Closes #N` / `Fixes #N` / `Resolves #N` からIssue番号を取り出してIssue番号として解決する (複数あれば一覧を提示して選んでもらう)。無ければ中止し、PRから検査対象のspecを特定できないことを報告する。PRのコード差分は読まない
   - **doc mode** (`.mjun/specs/` 外のMarkdown): ファイル内の要求・制約・スコープの記述をcontract、実装方針の記述を実装設計として扱う。どちらかが無ければその軸を省略し、SUMMARYに含める
   - **conversation mode** (source未指定): 会話中の設計・計画を、要求・制約・スコープ (contract) と設計本文に分けて書き起こし、reviewerへの入力にする (SubAgentは会話を読めない)。素材が無ければ中止する
   - 共通: `.mjun/steering/*.md`、`.mjun/CONTEXT.md`、`.mjun/adr/*.md` があればパス一覧を集める (reviewerとverifierが自分で読む)
3. `gh` が失敗した場合は中止し、エラーを報告する。パスは常にrepository rootからの絶対パスで渡す

### Phase 2: reviewerによる候補の発見

contract軸は [templates/contract-reviewer-prompt.md](templates/contract-reviewer-prompt.md)、design軸は [templates/design-reviewer-prompt.md](templates/design-reviewer-prompt.md) にPhase 1の材料を合成し、fresh contextのSubAgentを軸ごとに1体、並列に起動する。省略した軸は起動しない。reviewerには読み取り (Read / Glob / Grep) だけを許可し、ファイルの変更、テスト、ビルド、再現コードの実行をさせない。

各出力の `## Candidates` から、テンプレートの形式 (軸・観点・深刻度・対象と引用・問題・根拠・満たすべき状態・Human-owned decisionとの矛盾) を満たす候補だけを採用する。形式を満たさない候補は捨てる。両軸の候補を1つの集合にまとめ、同じセクションの同じ根本原因の候補は、verifierの起動前に1件へまとめる (軸が違っても同じ根本原因なら1件にする)。書き手の意図や見た目の確からしさだけを理由に、verifierの前で候補を破棄しない。

### Phase 3: verifierによる反証

候補1件ごとに [templates/verifier-prompt.md](templates/verifier-prompt.md) に候補とPhase 1の材料を合成し、SubAgentを起動する。候補間に依存は無いので並列に起動してよい。verifierにはrepository内の読み取りと `git` の読み取り系コマンドだけを許可し、コードを変更させない。

verdictが `confirmed` の候補だけを確定指摘とし、`refuted` と `uncertain` は捨てる。

### Phase 4: 出力

結果をチャットへ出力する。ファイルへの保存はしない。確定指摘はcontract軸を先に観点番号順で、次にdesign軸を深刻度 `contract` → `boundary` → `structure` の順 (同じ深刻度は観点番号順) で並べる。verifierの検証過程、捨てた候補、内部の証拠は出力しない。

応答の最後に、次の構造化ブロックを必ず1つだけ出力する。呼び出し元skillは `- VERDICT:` 行だけをパースする。見出しの変更、値の同義語への置き換え、ブロック後の追記をしない。補足説明は各フィールドの中に書く。

```
## Spec Review
- SOURCE: <mode と対象 (パス、Issue番号、PR番号)。conversation modeでは「会話中の設計」>
- VERDICT: PASS | NEEDS_FIXES
- FINDINGS:
  1. [contract:<観点1〜7>] <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <contract / sourceの引用、file:line、steering / ADR / CONTEXT.mdの引用> — 満たすべき状態: <修正方針ではなく、満たすべき状態>
  2. [design:<観点1〜7>][<contract | boundary | structure>] <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <同上> — 満たすべき状態: <同上>
- HUMAN_DECISION_CONFLICTS: <D-NNN と矛盾の内容。無ければ none>
- SUMMARY: <1文の要約>
```

FINDINGSが0件かつHUMAN_DECISION_CONFLICTSがnoneのときだけPASSとする。HUMAN_DECISION_CONFLICTSに挙げた矛盾はFINDINGSにも含める。省略した軸や検査できなかった観点 (sourceの原文が無い、Git repositoryでない) があれば、SUMMARYにその旨を含める。
