---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git fetch:*), Bash(git merge-base:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*)
description: Generate pull request for current branch with AI-generated title and description in Japanese.
argument-hint: [instructions]
---

## Context

- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Branch base: !`git merge-base --is-ancestor origin/main HEAD`
- List of commits diverging from base: !`git fetch origin && git log --oneline origin/main..HEAD`
- List of changes in this branch: !`git fetch origin && git log -p origin/main..HEAD`

## Task

MUST: The generated pull request title and description must be in Japanese.
MUST: If a PR template file (e.g., `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`) exists in the current repository, create the pull request following its content.

1. If instructions are specified in $ARGUMENTS, create the pull request according to them.
2. Verify that the current branch is derived from `main`.
3. Check the status and changes (diffs) of the current branch.
4. If a PR template file exists in the current repository, create the pull request following its content. If not, create the PR title and description following the [template below](#pull-request-template).
5. Create the pull request using `gh pr create` with the generated PR title and description.
6. Return the URL of the created PR.

## Pull Request Template

```markdown
## Overview

## Changes

## Test Instructions
```
