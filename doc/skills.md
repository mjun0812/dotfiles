# Agent Skills

This document describes the AI agent skills bundled in this repository and how they depend on each other.

Skill sources live under [`config/ai-agents/skills/`](../config/ai-agents/skills) and are deployed by `install.sh` as symlinks into:

- `~/.agents/skills/<skill>` — shared skills directory
- `~/.claude/skills/<skill>` — Claude Code
- `~/.codex/skills/<skill>` — Codex
- `~/.gemini/antigravity-cli/skills/<skill>` — Antigravity CLI

Editing a file under `config/ai-agents/skills/` updates every agent at once via the symlink.

## Skill List

Each skill is a directory containing `SKILL.md`. The agent loads the front-matter `description` to decide when to use it.

### Development Flow (mjun)

The self-authored dev-flow skill suite under the `mjun-` prefix. Specs always live in `.mjun/specs/` as the source of truth, and GitHub issues act as import/projection adapters. The entry point is `mjun-specify`; after contract approval it breaks the spec into tasks when needed, and `mjun-implement` carries it through to a PR.

| Skill                                                                  | Purpose                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`mjun-specify`](../config/ai-agents/skills/mjun-specify/SKILL.md)     | Polish an idea, GitHub issue, or local markdown into an implementable spec (contract): investigate facts, resolve agent-owned decisions autonomously, confirm human-owned ones one at a time, auto-run task breakdown for multi-task specs, then project the approved contract with the task checklist to the issue (local-only specs are offered a projection-target issue at that point) |
| [`mjun-grill`](../config/ai-agents/skills/mjun-grill/SKILL.md)         | Resolve plan / design / spec decisions interactively one question at a time (whole-design mode and single-decision mode)                                                                                                                                                                                                                                                                   |
| [`mjun-research`](../config/ai-agents/skills/mjun-research/SKILL.md)   | Investigate external facts from primary sources (official docs, library source, specs), save each claim with a citation to the local spec, and return the evidence to the caller without posting to GitHub                                                                                                                                                                                 |
| [`mjun-prototype`](../config/ai-agents/skills/mjun-prototype/SKILL.md) | Answer a UI / state / logic design question that talking cannot settle with one throwaway prototype per question                                                                                                                                                                                                                                                                           |
| [`mjun-to-tasks`](../config/ai-agents/skills/mjun-to-tasks/SKILL.md)   | Persist a spec as independently verifiable vertical-slice tasks in tasks.md, including single-task specs; completed tasks whose acceptance criteria change return to ready                                                                                                                                                                                                                 |
| [`mjun-implement`](../config/ai-agents/skills/mjun-implement/SKILL.md) | Gate the spec on explicit contract approval and content (issue numbers resolve via Source lookup; unimported issues are routed to mjun-specify), implement task by task in a worktree via implementer/reviewer subagents, resume from the branch recorded in tasks.md, verify both spec and task acceptance criteria, then commit and optionally open a PR                                 |
| [`mjun-steering`](../config/ai-agents/skills/mjun-steering/SKILL.md)   | Maintain `.mjun/steering/` as implementation-grounded project memory: bootstrap from the codebase, sync with drift detection                                                                                                                                                                                                                                                               |

### Git

| Skill                                                                      | Purpose                                                                                                                                                |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`git-commit`](../config/ai-agents/skills/git-commit/SKILL.md)             | Stage and commit the current changes in appropriate units                                                                                              |
| [`git-squash`](../config/ai-agents/skills/git-squash/SKILL.md)             | Squash / tidy commits on the current branch, force-with-lease push if needed                                                                           |
| [`git-fix-conflict`](../config/ai-agents/skills/git-fix-conflict/SKILL.md) | Detect and resolve conflicts from merge, rebase, cherry-pick, revert, apply, PR, etc.                                                                  |
| [`self-review`](../config/ai-agents/skills/self-review/SKILL.md)           | Adversarially review uncommitted changes or one specified commit with two independent Finders (`--spec` adds a contract axis checked against the spec) |

### GitHub

| Skill                                                                                        | Purpose                                                                                                                                                                                                            |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`github-issue-create`](../config/ai-agents/skills/github-issue-create/SKILL.md)             | Create one GitHub issue quickly from a rough todo, memo, or bug note (template and label auto-selection, approval before creation); spec work belongs to mjun-specify                                              |
| [`github-pr-create`](../config/ai-agents/skills/github-pr-create/SKILL.md)                   | Create a Pull Request from the current branch with a six-part description covering overview and background, related issues, implementation approach, changes, impact, and validation results                       |
| [`github-pr-review`](../config/ai-agents/skills/github-pr-review/SKILL.md)                   | Find merge-blocking issues, standards findings, and spec mismatches (when a spec resolves via `--spec` or a linked issue) with parallel reviewers, verify each candidate, and replace the previous review snapshot |
| [`github-pr-fix`](../config/ai-agents/skills/github-pr-fix/SKILL.md)                         | Detect and fix all PR problems (conflicts, CI failures, review comments) inside a dedicated worktree                                                                                                               |
| [`github-fix-ci`](../config/ai-agents/skills/github-fix-ci/SKILL.md)                         | Inspect CI status, analyze failures, and apply fixes                                                                                                                                                               |
| [`github-resolve-pr-comment`](../config/ai-agents/skills/github-resolve-pr-comment/SKILL.md) | Triage PR review comments and respond / address them                                                                                                                                                               |

### Planning & Design

| Skill                                                                    | Purpose                                                                                                                |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| [`experiment-plan`](../config/ai-agents/skills/experiment-plan/SKILL.md) | Interview the user one decision at a time and save a testable machine-learning experiment plan to `.mjun/experiments/` |

### Docs & Notes

| Skill                                                      | Purpose                                                                                                    |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [`doc-sync`](../config/ai-agents/skills/doc-sync/SKILL.md) | Diff repo docs (Markdown, docstrings, OpenAPI, config samples) against the implementation and update drift |
| [`md-note`](../config/ai-agents/skills/md-note/SKILL.md)   | Save the current conversation's research as a self-contained Japanese Markdown file                        |

### Japanese Writing

| Skill                                                                                | Purpose                                                                                                                                      |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [`japanese-tech-writing`](../config/ai-agents/skills/japanese-tech-writing/SKILL.md) | Style guide for writing and revising Japanese technical prose (formatting, paragraph-driven argument, removing LLM-flavored filler)          |
| [`stop-ai-slop-jp`](../config/ai-agents/skills/stop-ai-slop-jp/SKILL.md)             | Edit AI-generated Japanese back into human-written prose — fixes missing authorial stance, propositional H2s, false-balance, monotone rhythm |

Sources:

- `japanese-tech-writing` — based on [k16shikano/fd287c3133457c4fd8f5601d34aa817d](https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d)

### Cross-Agent Consultation & Delegation

These skills are user-invoked only — the agent does not trigger them on its own.

Each skill defaults to a read-only consultation mode, and runs with edit permissions only when the user explicitly asks to delegate work. An agent never uses the skill for its own CLI.

| Skill                                                  | Purpose                                                                                   |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| [`claude`](../config/ai-agents/skills/claude/SKILL.md) | Consult Claude Code (`claude -p`, read-only) or delegate work to it with edit permissions |
| [`codex`](../config/ai-agents/skills/codex/SKILL.md)   | Consult Codex (`codex exec`, read-only sandbox) or delegate work via `workspace-write`    |

### Misc

| Skill                                                                          | Purpose                                                                                                                                                             |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`agent-browser`](../config/ai-agents/skills/agent-browser/SKILL.md)           | Browser automation via the `agent-browser` CLI (vendored upstream stub; usage is loaded at runtime with `agent-browser skills get core`)                            |
| [`herdr`](../config/ai-agents/skills/herdr/SKILL.md)                           | Control herdr panes / tabs / workspaces from inside a herdr-managed pane (vendored from the binary via `herdr --skill`; regenerated by `setup_herdr.sh` on upgrade) |
| [`resume-other-agent`](../config/ai-agents/skills/resume-other-agent/SKILL.md) | Resume another coding agent (Codex / Claude Code) by session ID, replaying its prior context                                                                        |
| [`skill-review`](../config/ai-agents/skills/skill-review/SKILL.md)             | Validate Agent Skills compliance and report per-criterion verdicts, including trigger conflicts with nearby skills — no edits                                       |
| [`wezterm-control`](../config/ai-agents/skills/wezterm-control/SKILL.md)       | Drive wezterm panes / tabs / windows via `wezterm cli`: split, focus, resize, read pane contents, send commands and verify their output                             |

## Dependencies

The following skills invoke other skills through the agent's `Skill` tool. Arrows point from caller to callee.

```mermaid
graph LR
    git-squash -. on conflict .-> git-fix-conflict

    mjun-specify --> mjun-grill
    mjun-specify --> mjun-research
    mjun-specify --> mjun-prototype
    mjun-specify --> mjun-to-tasks

    mjun-implement --> git-commit
    mjun-implement --> github-pr-create

    github-pr-fix --> git-fix-conflict
    github-pr-fix --> github-fix-ci
    github-pr-fix --> github-resolve-pr-comment
```

### Caller → callee table

| Caller           | Callee                                                           | When                                                           |
| ---------------- | ---------------------------------------------------------------- | -------------------------------------------------------------- |
| `git-squash`     | `git-fix-conflict`                                               | Only if a conflict surfaces during squash                      |
| `mjun-specify`   | `mjun-grill`, `mjun-research`, `mjun-prototype`                  | When a human-owned / evidence-blocked decision needs resolving |
| `mjun-specify`   | `mjun-to-tasks`                                                  | Auto-chained after contract approval for multi-task specs      |
| `mjun-implement` | `git-commit`, `github-pr-create`                                 | Phase 4 commits the worktree changes; PR only with `--pr`      |
| `github-pr-fix`  | `git-fix-conflict`, `github-fix-ci`, `github-resolve-pr-comment` | Each callee runs only if the corresponding problem is detected |

### Standalone skills

These skills do not delegate to other skills:

`agent-browser`, `claude`, `codex`, `doc-sync`, `experiment-plan`, `git-commit`, `git-fix-conflict`, `github-fix-ci`, `github-issue-create`, `github-pr-create`, `github-pr-review`, `github-resolve-pr-comment`, `herdr`, `japanese-tech-writing`, `md-note`, `mjun-grill`, `mjun-prototype`, `mjun-research`, `mjun-steering`, `mjun-to-tasks`, `resume-other-agent`, `self-review`, `skill-review`, `stop-ai-slop-jp`, `wezterm-control`.

## Conventions

- Skill names use kebab-case and are scoped by domain (`git-*`, `github-*`, plus a few generic ones).
- Front matter (`name`, `description`, `allowed-tools`) is the contract the agent reads — keep `description` rich enough to trigger correctly, and list `Skill(<dep>)` in `allowed-tools` for any sub-skill the body invokes.
- Client-specific fields such as `allowed-tools` may be ignored by unsupported agents. When present, follow the target client's current syntax and grant only the tools and command scopes the skill requires.
- When extending an existing skill's behavior, prefer calling the original skill via the `Skill` tool rather than duplicating its logic, so all agents pick up improvements in one place.
