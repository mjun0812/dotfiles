# Worker Prompt

orchestratorが下表のplaceholderを埋め、本文をquoted heredocでshell変数に入れて `herdr agent prompt <worker名> "$task_prompt"` で送る。
依頼文の後ろに添えるのは、作業場所の注意、報告ファイル、完了報告の3つだけにする。進め方はworkerとskillが持っており、orchestratorが指示を足すとskillの手順と食い違うためである。

## Placeholder一覧

| placeholder         | 値                                             |
| ------------------- | ---------------------------------------------- |
| `{{request}}`       | Phase 2で決めた依頼文 (人間がpaneに打つ文面)   |
| `{{location_note}}` | taskのkindに対応する下の文面                   |
| `{{report_path}}`   | 報告ファイルの絶対パス (`<run-dir>/<slug>.md`) |
| `{{worker_name}}`   | worker agent名 (`<orch名>-<slug>`)             |
| `{{orch_name}}`     | orchestratorのagent名                          |

`{{location_note}}` はkindで決まる。`<branch>` と `<checkout_path>` はPhase 2とPhase 3で記録した値。どちらの文面も、並列に動く他のworkerと同じcheckoutを書き換えないためのものである。

| kind       | 文面                                                                                                                                                                                                   |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `worktree` | `You are in a git worktree created for this task at <checkout_path> on branch <branch>. Work and commit here. Do not create another worktree and do not remove this one; the orchestrator removes it.` |
| `tab`      | `Other agents are working in this repository in parallel. If you change files and neither you nor the skill you run creates a git worktree, create one and work there instead of the main checkout.`   |

## 本文

```text
{{request}}

---
{{location_note}}

Write your report to {{report_path}} when you finish, and whenever you stop to wait for an answer. Create the parent directory if it is missing, and rewrite the whole file each time so it describes the current state:

    Status: <one of the values below>
    PR: <full pull request URL>      (only if you opened a pull request)
    Branch: <branch name>            (only if you committed to a branch)
    ## Result
    What you did, what you found, what is left, and what the user must decide.
    ## Verification
    How you checked the result: the commands you ran and what they showed, or the sources you read. Name anything you could not check, and why.
    ## Next
    One recommended next action per line, or nothing if there is none.

Status values:

    DONE                 Finished, and the checks in Verification passed.
    DONE_WITH_CONCERNS   Finished, but something is unchecked or doubtful. Say what in Result.
    NEEDS_CONTEXT        Stopped because you need information or a decision you cannot get yourself. Put the question in Result.
    BLOCKED              Stopped because you cannot proceed, for example a broken environment or a repeated failure. Put the cause in Result.

When you finish with DONE or DONE_WITH_CONCERNS, send one line to Herdr agent {{orch_name}}:

    report="DONE {{worker_name}}: <one-line result, with the PR URL or branch if any>"
    herdr agent prompt {{orch_name}} "$report"
```
