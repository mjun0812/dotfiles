# decisions.md Template

その変更における判断履歴。1決定 = 1エントリで追記していく。現在有効なcontractはspec.mdが持ち、ここには経緯 (採用理由・却下案) を残す。

- `Status: accepted` — 確定した決定
- `Status: tentative` — 確信度lowの暫定決定 (「要確認」)。mjun-implementの起動時検査が検出する
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
  - <根拠: file:line、Research R-NNN、prototype結果など>
```

GitHub modeでは、採用decisionの要約表 (論点 / 決定 / 根拠) だけをIssue本文の `## Decision Log` に置き、上記の詳細エントリはIssueコメントへ記録する。
