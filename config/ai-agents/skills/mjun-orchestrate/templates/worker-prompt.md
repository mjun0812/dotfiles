# Worker Prompt

`scripts/dispatch.sh` が、下のplaceholderをboardとHerdrの値で埋め、本文をworkerへ送る。
依頼文の後ろに添えるのは、作業場所の注意、memory、報告ファイル、完了の知らせ方の4つだけにする。進め方はworkerとskillが持っており、orchestratorが指示を足すとskillの手順と食い違うためである。

`## ` の見出しと、その下で最初に現れるcode blockは `scripts/dispatch.sh` が読む。見出しの文字列を変えるときはscriptも直す。

## Placeholder一覧

| placeholder           | 値                                            |
| --------------------- | --------------------------------------------- |
| `{{request}}`         | boardの `Request`(人間がpaneに打つ文面)       |
| `{{location_note}}`   | taskのkindに対応する下の文面                  |
| `{{completion_note}}` | workerのagent種別に対応する下の文面           |
| `{{memory_path}}`     | memoryの絶対パス(`<run-dir>/memory.md`)       |
| `{{slug}}`            | taskのslug                                    |
| `{{report_path}}`     | 報告ファイルの絶対パス(`<run-dir>/<slug>.md`) |
| `{{worker_name}}`     | worker agent名(`<orch名>-<slug>`)             |
| `{{orch_pane}}`       | boardの `Orchestrator` にあるpane ID          |
| `{{checkout_path}}`   | workerのcwd                                   |
| `{{branch}}`          | boardの `Branch`                              |
| `{{base}}`            | boardの `Base`                                |

## body

```text
{{request}}

---
{{location_note}}

Earlier workers in this run may have left notes for you in {{memory_path}}. Read it before you start if it exists. Each earlier task also has a report in the same directory, named <task>.md; if your request continues one of them, read that report too.

Write your report to {{report_path}} when you finish, and whenever you stop to wait for an answer. Create the parent directory if it is missing, and rewrite the whole file each time so it describes the current state:

    Status: <one of the values below>
    PR: <full pull request URL>      (only if you opened a pull request)
    Branch: <branch name>            (only if you committed to a branch)
    ## Result
    What you did, what you found, what is left, and what the user must decide. Start with a one-line summary.
    ## Verification
    How you checked the result: the commands you ran and what they showed, or the sources you read. Name anything you could not check, and why.
    ## Next
    One recommended next action per line, or nothing if there is none.

Status values:

    DONE                 Finished, and the checks in Verification passed.
    DONE_WITH_CONCERNS   Finished, but something is unchecked or doubtful. Say what in Result.
    NEEDS_CONTEXT        Stopped because you need information or a decision you cannot get yourself. Put the question in Result.
    BLOCKED              Stopped because you cannot proceed, for example a broken environment or a repeated failure. Put the cause in Result.

Before you finish, append a note to {{memory_path}} if you leave behind anything a later worker would need and could not learn from the repository or its git history: processes you left running and how you started them, builds, worktrees or files you created outside the repository, choices you made where the request was silent, and surprises in the environment. Keep it to a few lines, and skip it if there is nothing. Append with the command below instead of editing the file, because other workers write to it in parallel. If your work makes an earlier note untrue, say so in yours.

    cat >> {{memory_path}} <<'NOTE'

    ## {{slug}} (<date and time>)
    <your note>
    NOTE

{{completion_note}}
```

## location_note: worktree

kind `worktree` の文面。下の `tab` の文面とあわせて、並列に動く他のworkerと同じcheckoutを書き換えないためのものである。

```text
You are in a git worktree created for this task at {{checkout_path}} on branch {{branch}}. Work and commit here. Do not create another worktree and do not remove this one; the orchestrator removes it.
```

## location_note: tab

```text
Other agents are working in this repository in parallel. If you change files and neither you nor the skill you run creates a git worktree, create one and work there instead of the main checkout.
```

## location_note: stacked

kind `worktree` で、boardの `Base` がdefault branchでなければ、`worktree` の文面の後ろへ空白1つを挟んで続ける。workerとskillはdefault branchを比較の基準にするので、伝えないと依存先の変更まで自分の差分に数え、PRもdefault branchへ向ける。

```text
This branch is stacked on {{base}}, the branch of an earlier task that is not merged yet. Treat {{base}} as the base branch: compare your changes against it, and if you open a pull request, target {{base}} instead of the default branch.
```

## completion_note: hook

claudeとcodexの文面。この2つは、workerが止まるたびにStop hook(`hooks/orch-worker-report.sh`)が報告ファイルを読み、orchestratorへ1行で知らせる。workerに送らせると、turnの途中で届き、送り忘れも起きる。

```text
You do not need to tell anyone when you stop. Each time you stop after changing the report file, its status and first Result line are sent to the orchestrator for you, so write the report before you end your turn.
```

## completion_note: prompt

Stop hookを持たないagent種別(opencode、agyなど)の文面。worker自身に知らせを送らせる。

```text
When you finish with DONE or DONE_WITH_CONCERNS, send one line to the Herdr pane {{orch_pane}}:

    report="DONE {{worker_name}}: <one-line result, with the PR URL or branch if any>"
    herdr agent prompt {{orch_pane}} "$report"
```
