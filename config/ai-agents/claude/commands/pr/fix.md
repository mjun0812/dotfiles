---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), SlashCommand
argument-hint: [PR number] [--reply]
description: Auto-detect and fix all PR issues (conflicts, CI failures, review comments).
---

# Fix All PR Issues

## Arguments

- `PR number`: PR number to fix (optional, defaults to PR for current branch)
- `--reply`: Post reply comments to GitHub after addressing (optional)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,url,mergeable,mergeStateStatus 2>/dev/null || echo "No PR found"`
- PR title: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: !`gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- CI status: !`gh pr checks --json name,state,conclusion 2>/dev/null || echo "No checks"`
- Pending reviews: !`gh pr view --json reviews --jq '[.reviews[] | select(.state == "CHANGES_REQUESTED")] | length' 2>/dev/null || echo "0"`

## Task

This command orchestrates three sub-commands to fix all PR issues in the correct order.

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use that PR
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message
   - Display initial PR status summary

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All reports and summaries MUST be written in this detected language
   - Sub-commands will also use the same language (they detect independently)
   - If language is ambiguous, default to English

2. **Step 1: Check and fix conflicts**:
   - Check merge status: `gh pr view --json mergeable --jq '.mergeable'`
   - If `CONFLICTING`:
     - Execute `/pr:fix-conflicts`
     - Wait for completion
     - Verify conflicts are resolved
   - If `MERGEABLE`: Skip to next step
   - Report status in detected language

3. **Step 2: Check and fix CI failures**:
   - Check CI status: `gh pr checks`
   - If any checks failed:
     - Execute `/github:fix-ci`
     - Wait for completion
     - Note: CI will re-run after push
   - If all checks pass: Skip to next step
   - If checks still running: Report status and continue
   - Report status in detected language

4. **Step 3: Check and respond to review comments**:
   - Check for pending review comments: `gh pr view --json reviews,comments`
   - If there are unaddressed comments:
     - Execute `/pr:respond-comment --reply`
     - Wait for completion
   - If no pending comments: Skip
   - Report status in detected language

5. **Final summary** (in detected language):

### English Format

```markdown
## PR Fix Summary

### Status

| Check     | Before | After |
| --------- | ------ | ----- |
| Conflicts | ❌/✅  | ✅    |
| CI        | ❌/✅  | ✅/⏳ |
| Reviews   | ❌/✅  | ✅    |

### Actions Taken

- [ ] Resolved X merge conflicts
- [ ] Fixed X CI failures
- [ ] Addressed X review comments

### Commits Created

- `abc1234` - merge: resolve conflicts with main
- `def5678` - fix: resolve CI failures
- `ghi9012` - fix: address review comments
```

### Japanese Format (日本語)

```markdown
## PR修正サマリー

### ステータス

| チェック     | 修正前 | 修正後 |
| ------------ | ------ | ------ |
| コンフリクト | ❌/✅  | ✅     |
| CI           | ❌/✅  | ✅/⏳  |
| レビュー     | ❌/✅  | ✅     |

### 実行したアクション

- [ ] X件のマージコンフリクトを解消
- [ ] X件のCI失敗を修正
- [ ] X件のレビューコメントに対応

### 作成したコミット

- `abc1234` - merge: mainとのコンフリクトを解消
- `def5678` - fix: CI失敗を修正
- `ghi9012` - fix: レビューコメントに対応
```

## Notes

- Each step is executed only if issues are detected
- If a step fails, subsequent steps may still be attempted
- User confirmation is requested before major changes
- Progress is reported after each step in the detected language
