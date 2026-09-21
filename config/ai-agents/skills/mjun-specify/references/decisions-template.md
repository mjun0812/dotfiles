# decisions.md Template

その変更における判断履歴。1決定 = 1エントリで追記していく。現在有効なcontractはspec.mdが持ち、ここには経緯 (採用理由・却下案) を残す。

新しい依存、抽象、設定項目を採用するdecisionでは、より単純な候補 (既存実装や標準機能など) を `Alternatives` に、その候補では満たせない具体的な要求や設計制約を `Rationale` に、確認したコードや仕様を `Evidence` に記録する。既存の実装方針と信頼性も判断に含める。候補間で優劣が決まらず人間が選んだ場合は、そのtrade-offと選択理由を記録し、候補の不足を捏造しない。候補の網羅や別の比較表の作成は求めない。

- `Status: accepted` — 確定した決定
- `Status: tentative` — 確信度lowの暫定決定 (「要確認」)。承認前にmjun-specifyが証拠または人間の確認で解消し、承認後の残留はmjun-implementの起動時検査が検出する
- 決定を覆した場合は、旧エントリを `Status: superseded by D-NNN` に変え、新エントリを追加する

```markdown
## D-001: <論点を表すタイトル>

- Owner: human | agent
- Status: accepted | tentative
- Decision: <決定内容>
- Alternatives:
  - <却下した代替案>
- Rationale: <採用理由と、代替案の却下理由>
- Evidence:
  - <根拠: file:line、research/<topic>.md、prototype結果など>
```

`Source:` を持つspecの投影では、採用decisionの要約表 (論点 / 決定 / 根拠) だけをIssue本文の `## Decision Log` に置き、上記の詳細エントリはIssueコメントへ記録する。
