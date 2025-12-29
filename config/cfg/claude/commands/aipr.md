---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git fetch:*), Bash(git merge-base:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*)
argument-hint: [language]
description: Generate pull request for current branch with AI-generated title and description in the specified language.
---

## Arguments

- `language`: Language for PR title and description (e.g., "ja", "en"). Default: "English"

## Context

- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Branch base: !`git merge-base --is-ancestor origin/main HEAD`
- List of commits diverging from base: !`git fetch origin && git log --oneline origin/main..HEAD`
- List of changes in this branch: !`git fetch origin && git log -p origin/main..HEAD`

## Task

1. Verify that the current branch is derived from `main`.
2. Check the status and changes (diffs) of the current branch.
3. Check if a PR template file exists in the current repository (e.g., `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`).
4. Generate PR title and description:
   - **If a repository PR template exists**: Use that template and follow its language (do NOT translate to the specified language).
   - **If no repository PR template exists**: Use the [default template below](#default-pull-request-templates) in the language specified by $ARGUMENTS (default: English).
5. Create the pull request using `gh pr create` with the generated PR title and description.
6. Return the URL of the created PR.

## Default Pull Request Templates

### English Template

```markdown
## Overview

<!-- Describe the purpose of this PR in short. -->

## Changes

<!-- Describe the changes made in this PR in bullet points. -->

## Test Instructions

<!-- Describe the test instructions for this PR. -->
```

### Japanese Template (日本語)

```markdown
## 概要

<!-- このPRは何を目的としているかを簡潔に一言で記載してください -->

## 変更内容

<!-- このPRで行われた変更を箇条書きで記載してください -->

## テスト方法

<!-- このPRのテスト方法を記載してください -->
```
