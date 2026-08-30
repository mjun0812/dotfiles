---
name: mjun-design-review
description: >-
  実装設計 (`.mjun/specs/<slug>` のdesign.md、任意の設計Markdown、または会話中の設計) を敵対的にレビューするSkill。
  fresh contextのreviewer SubAgentがcontractの充足・Boundaries・コードベースとの整合・失敗経路・Test Seam・構造の過不足を検査して候補を出し、
  候補1件ごとにverifier SubAgentが実コードとcontractの明文で反証を試み、confirmedの指摘だけを深刻度順にチャットへ返す。ファイルは編集しない。
  ユーザーが「この設計をレビューして」「design.mdを検査して」「設計の穴を探して」と依頼したときや、呼び出し元skillから承認前の設計検査を渡されたときに使うこと。
  人間との対話で設計の分岐を決める用途や、コード差分のレビューには使わない。
allowed-tools: Task, Read, Glob, Grep, Bash(git rev-parse:*)
---

# mjun-design-review

実装設計を、設計を書いた会話とは別のfresh contextで敵対的に検査するSkill。設計者の判断と根拠を未検証の仮説として扱い、contractの明文・実コード・steeringだけを根拠に、実装前に解消すべき問題を探す。
reviewerが出した候補をverifierが1件ずつ反証し、`confirmed` だけを出力する。厳しさは探索範囲と反証の深さに使い、指摘の証拠基準は下げない。
ファイルは読むだけで、design・spec・decisions・コードを変更しない。指摘の反映は呼び出し元 (人間、または承認前検査としてこのskillを呼んだ側) が判断する。

## Arguments

- `source` (任意): `.mjun/specs/<slug>` (配下のファイルパスでも可)、または設計を書いたMarkdownのパス。未指定なら会話中の設計・計画を対象にする

## Task

### Phase 1: sourceの解決とcontextの収集

1. repository rootを `git rev-parse --show-toplevel` で特定する。Git repositoryでなければ現在のディレクトリを使い、コードベースとの整合検査が限定的になる旨をPhase 4のSUMMARYに含める
2. sourceの形からmodeを決め、reviewerに渡す材料を集める。出力言語はsourceの言語に合わせる
   - **spec mode** (`.mjun/specs/<slug>`): `design.md` をレビュー対象とする。無ければ中止し、design.mdが未作成であることを報告する。`spec.md` をcontract、あれば `decisions.md` を決定の経緯として渡す。`decisions.md` から `Owner: human` のdecision (D番号とタイトル) を抜き出してHuman-owned decisionの一覧にする
   - **doc mode** (`.mjun/specs/` 外のMarkdown): ファイル全文をレビュー対象とする。contractはファイル内に書かれた要求・制約・スコープの記述を使う。無ければcontractの充足 (観点1) は検査できないため、その旨をPhase 4のSUMMARYに含める
   - **conversation mode** (source未指定): 会話中の設計・計画を、設計本文と要求・制約・スコープに分けて書き起こし、reviewerへの入力にする (SubAgentは会話を読めない)。素材が無ければ中止する
   - 共通: `.mjun/steering/*.md` があればパス一覧を集める (reviewerとverifierが自分で読む)
3. パスは常にrepository rootからの絶対パスで渡す

### Phase 2: reviewerによる候補の発見

[templates/reviewer-prompt.md](templates/reviewer-prompt.md) にPhase 1の材料を合成し、fresh contextのSubAgentを1体起動する。reviewerには読み取り (Read / Glob / Grep) だけを許可し、ファイルの変更、テスト、ビルド、再現コードの実行をさせない。

出力の `## Candidates` から、テンプレートの形式 (観点・深刻度・対象と引用・問題・根拠・満たすべき状態・Human-owned decisionとの矛盾) を満たす候補だけを採用する。形式を満たさない候補は捨てる。同じセクションの同じ根本原因の候補は、verifierの起動前に1件へまとめる。設計者の意図や見た目の確からしさだけを理由に、verifierの前で候補を破棄しない。

### Phase 3: verifierによる反証

候補1件ごとに [templates/verifier-prompt.md](templates/verifier-prompt.md) に候補とPhase 1の材料を合成し、SubAgentを起動する。候補間に依存は無いので並列に起動してよい。verifierにはrepository内の読み取りと `git` の読み取り系コマンドだけを許可し、コードを変更させない。

verdictが `confirmed` の候補だけを確定指摘とし、`refuted` と `uncertain` は捨てる。

### Phase 4: 出力

結果をチャットへ出力する。ファイルへの保存はしない。確定指摘は深刻度 `contract` → `boundary` → `structure` の順に並べ、同じ深刻度の中では観点番号順にする。verifierの検証過程、捨てた候補、内部の証拠は出力しない。

応答の最後に、次の構造化ブロックを必ず1つだけ出力する。呼び出し元skillは `- VERDICT:` 行だけをパースする。見出しの変更、値の同義語への置き換え、ブロック後の追記をしない。補足説明は各フィールドの中に書く。

```
## Design Review
- SOURCE: <mode と対象パス。conversation modeでは「会話中の設計」>
- VERDICT: PASS | NEEDS_FIXES
- FINDINGS:
  1. [<観点1〜7>][<contract | boundary | structure>] <セクション名> — 引用: "<該当箇所>" — 問題: <何が問題か> — 根拠: <contractの引用 / file:line / steeringの引用> — 満たすべき状態: <修正方針ではなく、満たすべき状態>
- HUMAN_DECISION_CONFLICTS: <D-NNN と矛盾の内容。無ければ none>
- SUMMARY: <1文の要約>
```

FINDINGSが0件かつHUMAN_DECISION_CONFLICTSがnoneのときだけPASSとする。HUMAN_DECISION_CONFLICTSに挙げた矛盾は、観点7の指摘としてFINDINGSにも含める。検査できなかった観点 (doc modeでcontractが無い、Git repositoryでない) があれば、SUMMARYにその旨を含める。

SubAgentが使えない環境では、reviewerのチェックリストとverifierの反証をメイン会話で順に実施し、その旨をSUMMARYに含める。
