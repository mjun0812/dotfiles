# decisions.md Template

プロジェクト共通の判断履歴 `.mjun/steering/decisions.md` に、1決定 = 1エントリで追記する。存在しなければ親ディレクトリとともに作る。現在有効なcontractはspec.mdが持ち、ここには経緯 (採用理由・却下案) を残す。保存先・更新規則は [用語集と決定記録](../../mjun-steering/references/glossary_and_adr.md) に従う。

- D番号はプロジェクト全体の最大値 + 1とし、specごとにリセットしない。追記直前に最新ファイルを読み、他の書き手が追記中なら直列化する。読み取り時の全文で上書きせず、自分のentryだけを追記する。
- 対象specのH1直下に `Decisions: D-001, D-002` の形式で関連するD番号を記録する。判断本文はspecへ複製しない。共通の決定を再利用する場合もIDをここへ加える。
- Evidenceのパスはrepository root基準とする。specの調査結果なら `.mjun/specs/<slug>/research/<topic>.md` のように書き、specを移動・削除しても判断の要点が残るようRationaleとEvidenceへ根拠の要約も記録する。

新しい依存、抽象、設定項目を採用するdecisionでは、より単純な候補 (既存実装や標準機能など) を `Alternatives` に、その候補では満たせない具体的な要求や設計制約を `Rationale` に、確認したコードや仕様を `Evidence` に記録する。既存の実装方針と信頼性も判断に含める。候補間で優劣が決まらず人間が選んだ場合は、そのtrade-offと選択理由を記録し、候補の不足を捏造しない。候補の網羅や別の比較表の作成は求めない。

- `Status: accepted` — 確定した決定
- `Status: tentative` — 確信度lowの暫定決定 (「要確認」)。承認前にmjun-specifyが証拠または人間の確認で解消し、承認後の残留はmjun-implementの起動時検査が検出する
- 決定を覆した場合は、旧エントリを `Status: superseded by D-NNN` に変え、新エントリを追加する

```markdown
## D-001: <論点を表すタイトル>

- Date: YYYY-MM-DD
- Scope: project | spec:<slug>
- Kind: decision | adr
- Source: <specのslug / PR #N / Issue #N / 文書パス / 会話の日付>
- Owner: human | agent
- Status: accepted | tentative
- Decision: <決定内容>
- Alternatives:
  - <却下した代替案>
- Rationale: <採用理由と、代替案の却下理由>
- Evidence:
  - <根拠: file:line、.mjun/specs/<slug>/research/<topic>.md、prototype結果など>
```

`Source:` を持つspecの投影では、対象specの `Decisions:` が参照するacceptedのdecisionの要約表 (論点 / 決定 / 根拠) だけをIssue本文の `## Decision Log` に置き、上記の詳細エントリはIssueコメントへ記録する。
