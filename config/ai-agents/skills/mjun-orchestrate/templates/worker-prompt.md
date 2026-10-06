# Worker Prompt

orchestratorが下表のplaceholderを埋め、本文をquoted heredocでshell変数に入れて `herdr agent prompt <worker名> "$task_prompt"` で送る。
依頼文の後ろに添えるのは、並列作業の注意と完了報告の2つだけとし、workerやskillの進め方を上書きする指示は足さない。

## Placeholder一覧

| placeholder       | 値                                           |
| ----------------- | -------------------------------------------- |
| `{{request}}`     | Phase 2で決めた依頼文 (人間がpaneに打つ文面) |
| `{{worker_name}}` | worker agent名 (`<orch名>-<slug>`)           |
| `{{orch_name}}`   | orchestratorのagent名                        |

## 本文

```text
{{request}}

---
Other agents are working in this repository in parallel. If neither you nor the skill you run creates a git worktree, create one and work there instead of the main checkout.
When everything is finished, send one line to Herdr agent {{orch_name}}:

    report="DONE {{worker_name}}: <one-line result, with the PR URL or branch if any>"
    herdr agent prompt {{orch_name}} "$report"
```
