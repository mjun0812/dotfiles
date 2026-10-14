# SubAgentのmodel

mjun-implementが起動するSubAgentのmodelとeffortは、この表に従う。環境のグローバル指示 (CLAUDE.md、AGENTS.mdなど) にある一般的なモデル指針より、この表を優先する。model名はこのファイルにだけ書き、版が変わったらここだけを更新する。

## roleごとの指定

| role        | Claude Code (`model` / `effort`) | Codex (`model` / `reasoning_effort`) |
| ----------- | -------------------------------- | ------------------------------------ |
| implementer | `sonnet` / `high`                | `gpt-6-luna` / `max`                 |
| refactorer  | `sonnet` / `medium`              | `gpt-6-luna` / `xhigh`               |
| verifier    | `opus` / `high`                  | `gpt-6.1-sol` / `high`               |
| reviewer    | `opus` / `high`                  | `gpt-6.1-sol` / `high`               |
| debugger    | `opus` / `xhigh`                 | `gpt-6.1-sol` / `xhigh`              |
| advisor     | `opus` / `xhigh`                 | `gpt-6.1-sol` / `xhigh`              |

reviewer・verifier・advisorは、implementerより上位のmodelにする。implementerを昇格させた場合も、これらをimplementerより下にしない。

## implementerの昇格

次の場合は、implementerを `opus` / `gpt-6.1-sol` (effortは `high`) で起動する。

- groupに統合task (Boundaryに `(integration)`) を含む
- debuggerの分類を受けて、implementerを新規に起動し直す

これより上位のmodel (`gpt-6-astra` など) は使わない。昇格したimplementerでも収束しない場合は、[recovery.md](recovery.md) の規則に従ってtaskを隔離する。

## 指定できない環境

model名やeffortを指定できない環境では、指定せずに起動し、Phase 5の報告にその旨を書く。表にないmodelへ勝手に置き換えない。
