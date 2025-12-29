---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [language] [--draft] [--reviewer <username>] [--label <name>]
description: Generate pull request for current branch with AI-generated title and description in the specified language.
---

# Create Pull Request

## Arguments

- `language`: Language for PR title and description (e.g., "ja", "en"). Default: "English"
- `--draft`: Create as draft PR (optional)
- `--reviewer <username>`: Assign reviewer (optional, can be specified multiple times)
- `--label <name>`: Add label (optional, can be specified multiple times)

## Context

- Current branch: !`git branch --show-current`
- Default branch: !`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`
- Existing PR: !`gh pr view --json url,state 2>/dev/null || echo "none"`

## Task

0. **Pre-checks**:
   - Verify there are commits to push (`git log origin/<base>..HEAD` is not empty)
   - Check if a PR already exists for this branch (`gh pr view --json url`)
   - If PR exists, ask user whether to update or abort

1. **Determine the base branch**:
   - First, check tracking branch: `git rev-parse --abbrev-ref @{upstream}`
   - Use `git merge-base --fork-point` for more accurate detection
   - Analyze branch naming convention (e.g., `feature/xxx` → `develop`, `hotfix/xxx` → `main`)
   - If unable to determine, fall back to the repository's default branch

2. **Get changes in this branch**:
   - Commits diverging from base: `git log --oneline origin/<base-branch>..HEAD`.
   - Detailed changes: `git log -p origin/<base-branch>..HEAD`.

3. Check if a PR template file exists in the current repository (e.g., `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`).

4. **Detect related Issues**:
   - Extract Issue numbers from the branch name (e.g., `feature/123-add-something` → `#123`)
   - Extract Issue numbers from commit messages (e.g., `fix #456`, `closes #789`, `refs #101`)
   - Match extracted numbers against the Issue list to verify they exist (`gh issue list`)
   - If no Issue numbers are found automatically, analyze Issue titles/bodies to find semantically related Issues based on the PR changes

5. Generate PR title and description:
   - **If a repository PR template exists**: Use that template and follow its language (do NOT translate to the specified language).
   - **If no repository PR template exists**: Use the [default template below](#default-pull-request-templates) in the language specified by $ARGUMENTS (default: English).
   - **Add related Issues**: Include detected Issues in the "Related Issues" section using appropriate keywords (`Closes #xxx` for Issues that will be resolved, `Related to #xxx` for referenced Issues).

6. Create the pull request using
   `gh pr create --base <base-branch> --title "<PR Title>" --body "<PR Description>" [--draft] [--reviewer <username>] [--label <name>]`.

7. **Return the result**:
   - Return the URL of the created PR
   - Show summary of the PR (title, base branch, reviewers, labels)

## Default Pull Request Templates

### English Template

```markdown
## Overview and Background

<!-- Describe the purpose of this PR and the background in short. -->

## Related Issues

<!-- List related Issues. Use "Closes #xxx" for Issues resolved by this PR, "Related to #xxx" for referenced Issues. -->

## Changes

<!-- Describe the changes made in this PR in bullet points. -->

## Test Instructions

<!-- Describe the test instructions for this PR. -->
```

### Japanese Template (日本語)

```markdown
## 概要・背景

<!-- このPRの目的と背景を簡潔に記載してください -->

## 関連Issue

<!-- 関連するIssueを記載してください。このPRで解決するIssueは「Closes #xxx」、参照するIssueは「Related to #xxx」の形式で記載 -->

## 変更内容

<!-- このPRで行われた変更を箇条書きで記載してください -->

## テスト方法

<!-- このPRのテスト方法を記載してください -->
```
