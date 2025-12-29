---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [PR number] [--post]
description: Review a pull request as an independent reviewer and provide structured feedback.
---

# Review Pull Request

## Arguments

- `PR number`: PR number to review (optional, defaults to PR for current branch)
- `--post`: Post the review comment to GitHub after review (optional)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,title,state,baseRefName,headRefName,url 2>/dev/null || echo "No PR found for current branch"`
- PR title and body: !`gh pr view --json title,body --jq '"\(.title)\n\(.body)"' 2>/dev/null | head -50`
- Repository: !`gh repo view --json nameWithOwner --jq .nameWithOwner`

## Task

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use `gh pr view <number>`
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English, Chinese)
   - **IMPORTANT**: All review comments and reports MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Gather PR information**:
   - Get PR metadata: `gh pr view <number> --json title,body,baseRefName,headRefName,author,additions,deletions,changedFiles`
   - Get list of changed files: `gh pr view <number> --json files --jq '.files[].path'`
   - Get the diff: `gh pr diff <number>`

3. **Analyze the changes**:
   - Understand the purpose of the PR from title and description
   - Identify the scope of changes (which modules/features are affected)
   - Note the size of the PR (additions, deletions, files changed)

4. **Review the code** with the following perspectives:
   - **Correctness**: Logic errors, bugs, edge cases not handled
   - **Security**: Vulnerabilities, injection risks, authentication/authorization issues
   - **Performance**: Inefficient algorithms, N+1 queries, unnecessary computations
   - **Readability**: Naming conventions, code structure, complexity
   - **Maintainability**: Code duplication, tight coupling, missing abstractions
   - **Testing**: Test coverage, test quality, missing test cases
   - **Documentation**: Missing comments, outdated docs, unclear code

5. **Generate review report**:
   - Use the appropriate template based on the detected language
   - See [Review Report Templates](#review-report-templates) below

6. **Post review to GitHub** (if `--post` flag is provided):
   - Confirm with user before posting
   - Post in the same language as the PR
   - Use `gh pr review <number> --comment --body "<review body>"` for comments
   - Use `gh pr review <number> --approve --body "<review body>"` for approval
   - Use `gh pr review <number> --request-changes --body "<review body>"` for requesting changes

7. **Return the result**:
   - Display the review report in the detected language
   - If posted, show the URL of the review comment

## Review Report Templates

### English Template

```markdown
## Summary

<!-- 1-2 sentence summary of what this PR does -->

## Good Points

- <!-- Positive aspects of the implementation -->

## Must Fix (Blocking)

- [ ] `filename:line` - Description of the issue

## Should Fix (Non-blocking)

- [ ] `filename:line` - Description of the suggestion

## Questions

- <!-- Questions for the author -->

## Verdict

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->
```

### Japanese Template (日本語)

```markdown
## 概要

<!-- このPRの変更内容を1-2文で要約 -->

## 良い点

- <!-- 実装の良い点 -->

## 要修正（ブロッキング）

- [ ] `ファイル名:行番号` - 問題の説明

## 提案（ノンブロッキング）

- [ ] `ファイル名:行番号` - 提案内容

## 質問

- <!-- 作成者への質問 -->

## 判定

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->
```
