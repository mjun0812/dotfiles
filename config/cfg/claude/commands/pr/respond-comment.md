---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [PR number] [--reply]
description: Review and respond to review comments on a pull request.
---

# Respond to Review Comments

## Arguments

- `PR number`: PR number to respond to (optional, defaults to PR for current branch)
- `--reply`: Post reply comments to GitHub after addressing (optional)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,url,reviewDecision 2>/dev/null || echo "No PR found"`
- PR title: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: !`gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- Pending reviews: !`gh pr view --json reviews --jq '.reviews | map(select(.state != "APPROVED")) | length' 2>/dev/null || echo "0"`

## Task

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use that PR
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All commit messages and reply comments MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Retrieve review comments**:
   - Get all reviews: `gh pr view <number> --json reviews`
   - Get review comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments`
   - Get general PR comments: `gh pr view <number> --comments`

3. **Categorize comments**:
   - **Requires code change**: Comments requesting modifications
   - **Questions**: Comments asking for clarification
   - **Suggestions**: Optional improvements
   - **Resolved**: Already addressed comments
   - **Informational**: Comments that don't require action

4. **Display comment summary** (in detected language):

#### English Format

```markdown
## Review Comments Summary

### Requires Code Change (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Proposed action: ...

### Questions (X items)

1. **[filename:line]** by @reviewer
   > Question content
   > → Proposed answer: ...

### Suggestions (X items)

1. **[filename:line]** by @reviewer
   > Suggestion content
   > → Accept / Decline with reason: ...
```

#### Japanese Format (日本語)

```markdown
## レビューコメント一覧

### 要修正 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 対応方針: ...

### 質問 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 質問内容
   > → 回答案: ...

### 提案 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 提案内容
   > → 採用/不採用の理由: ...
```

5. **Address each comment**:
   - For code changes:
     - Navigate to the affected file and line
     - Apply the requested change
     - Explain what was changed
   - For questions:
     - Prepare a clear answer (in detected language)
   - For suggestions:
     - Evaluate the suggestion
     - Apply if beneficial, or explain why not

6. **Commit and push** (use detected language for commit message):
   - Stage all changes: `git add -A`
   - Commit with message in detected language:
     - English: `fix: address review comments`
     - Japanese: `fix: レビューコメントに対応`
   - Push to remote: `git push`

7. **Post replies** (if `--reply` flag is provided):
   - Write replies in the detected language
   - For each addressed comment, post a reply using:
     `gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment-id>/replies -f body="<reply>"`
   - Reply content should indicate:
     - What action was taken
     - Reference to the commit if code was changed
   - Example replies:
     - English: "Fixed in abc1234. Changed X to Y as suggested."
     - Japanese: "abc1234 で修正しました。ご指摘の通り X を Y に変更しました。"

8. **Return the result** (in detected language):
   - Summary of actions taken
   - List of comments that need manual attention (if any)
   - Suggestion to request re-review if all blocking comments are addressed

## Notes

- If a comment's intent is unclear, ask the user for clarification before making changes
- For large design changes, discuss with the user before implementing
- Group related changes into logical commits if appropriate
