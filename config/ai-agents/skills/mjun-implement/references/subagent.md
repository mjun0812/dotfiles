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

reviewerとverifierは、implementerより上位のmodelにする。implementerを昇格させた場合も、これらをimplementerより下にしない。

## implementerの昇格

次の場合は、implementerを `opus` / `gpt-6.1-sol` (effortは `high`) で起動する。

- groupのtaskのBoundaryが、2つ以上の責務にまたがる。責務をまたぐ変更は、呼び出し規約やデータの受け渡しを複数の箇所でそろえる必要があり、難しいからである
- debuggerの分類を受けて、implementerを新規に起動し直す

これより上位のmodel (`gpt-6-astra` など) は使わない。昇格したimplementerでも収束しない場合は、[recovery.md](recovery.md) の規則に従ってtaskを隔離する。

## roleごとの原則

コードの書き方の原則は `principles/` に1原則1ファイルで置き、roleごとに次の原則だけを渡す。roleの仕事に関係しない原則まで読ませると、判断の材料が増えるだけで、そのroleの作業は良くならないからである。原則は、cursor/pluginsのpstack (MIT License) のprincipleを元にしている。

| 原則                                          | implementer | reviewer | refactorer | verifier | debugger |
| --------------------------------------------- | ----------- | -------- | ---------- | -------- | -------- |
| `laziness-protocol.md`                        | ○           | ○        | ○          |          |          |
| `subtract-before-you-add.md`                  | ○           | ○        | ○          |          |          |
| `minimize-reader-load.md`                     | ○           | ○        | ○          |          |          |
| `foundational-thinking.md`                    | ○           | ○        |            |          |          |
| `redesign-from-first-principles.md`           | ○           |          |            |          | ○        |
| `model-the-domain.md`                         | ○           | ○        | ○          |          |          |
| `type-system-discipline.md`                   | ○           | ○        |            |          |          |
| `boundary-discipline.md`                      | ○           | ○        |            |          |          |
| `make-operations-idempotent.md`               | ○           | ○        |            |          |          |
| `separate-before-serializing-shared-state.md` | ○           | ○        |            |          |          |
| `migrate-callers-then-delete-legacy-apis.md`  | ○           | ○        | ○          |          |          |
| `test-behavior-not-implementation.md`         | ○           | ○        |            | ○        |          |
| `fix-root-causes.md`                          | ○           | ○        |            |          | ○        |
| `comments-explain-why.md`                     | ○           | ○        | ○          |          |          |

## 指定できない環境

model名やeffortを指定できない環境では、指定せずに起動し、Phase 5の報告にその旨を書く。表にないmodelへ勝手に置き換えない。
