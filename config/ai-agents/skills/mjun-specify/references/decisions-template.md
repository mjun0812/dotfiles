# Decision Record Template

プロジェクト共通の決定記録ディレクトリ (Git管理へ移行済みなら `docs/adr/`、それ以外は `.mjun/steering/adr/`) に、1決定 = 1ファイル (`NNNN-<slug>.md`) で追加する。存在しなければ親ディレクトリとともに作る。現在有効なcontractはspec.mdが持ち、ここには経緯 (採用理由・却下案) を残す。保存先・更新規則は [用語集と決定記録](../../mjun-steering/references/glossary_and_adr.md) に従う。

- D番号はディレクトリ内のファイル番号 (他の形式の既存ADRを含む) の最大値 + 1とし、specごとにリセットしない。ファイル名は4桁ゼロ埋めの番号と、タイトルを英小文字・数字・ハイフンで要約したslugにする (例: `0007-use-event-sourcing.md`)。H1のD番号はファイル名の番号と一致させる。作成直前にディレクトリを読み直し、他の書き手が作成中なら直列化する。branchのmergeなどで番号が重複した場合は、後から追加された側を最大値 + 1へ振り直して参照を揃える。
- 1ファイルには1件だけを書き、他のentryファイルを書き換えない (状態更新の例外は共通記録規則に従う)。
- 対象specのH1直下に `Decisions: D-0001, D-0002` の形式で関連するD番号を記録する。判断本文はspecへ複製しない。共通の決定を再利用する場合もIDをここへ加える。
- Evidenceのパスはrepository root基準とする。specの調査結果なら `.mjun/specs/<slug>/research/<topic>.md` のように書き、specを移動・削除しても判断の要点が残るようRationaleとEvidenceへ根拠の要約も記録する。

新しい依存、抽象、設定項目を採用するdecisionでは、より単純な候補 (既存実装や標準機能など) を `Alternatives` に、その候補では満たせない具体的な要求や設計制約を `Rationale` に、確認したコードや仕様を `Evidence` に記録する。既存の実装方針と信頼性も判断に含める。候補間で優劣が決まらず人間が選んだ場合は、そのtrade-offと選択理由を記録し、候補の不足を捏造しない。候補の網羅や別の比較表の作成は求めない。

- `Status: accepted` — 確定した決定
- `Status: tentative` — 確信度lowの暫定決定 (「要確認」)。承認前にmjun-specifyが証拠または人間の確認で解消し、承認後の残留はmjun-implementの起動時検査が検出する
- 決定を覆した場合は、旧エントリを `Status: superseded by D-NNNN` に変え、新エントリを追加する

```markdown
# D-0001: <論点を表すタイトル>

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
