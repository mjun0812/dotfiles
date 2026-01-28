---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [--rebase | --merge]
description: Detect and resolve merge conflicts in the current PR.
context: fork
---

# Fix Merge Conflicts

## Arguments

- `--rebase`: Use rebase strategy to resolve conflicts (optional)
- `--merge`: Use merge strategy to resolve conflicts (optional, default)

## Context

- Current branch: !`git branch --show-current`
- Base branch: !`gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo "main"`
- PR title: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: !`gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- Merge status: !`gh pr view --json mergeable,mergeStateStatus --jq '"\(.mergeable) - \(.mergeStateStatus)"' 2>/dev/null || echo "unknown"`
- Conflict files: !`git diff --name-only --diff-filter=U 2>/dev/null || echo "none"`

## Task

0. **Pre-checks**:
   - Verify a PR exists for the current branch
   - Check merge status: `gh pr view --json mergeable --jq '.mergeable'`
   - If `MERGEABLE`, report "No conflicts detected" (in detected language) and exit
   - If `UNKNOWN`, fetch latest and re-check

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All commit messages and reports MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Fetch latest changes**:
   - Fetch from origin: `git fetch origin`
   - Identify base branch: `gh pr view --json baseRefName --jq '.baseRefName'`

3. **Start conflict resolution**:
   - If `--rebase` flag or user prefers rebase:
     - `git rebase origin/<base-branch>`
   - Otherwise (default merge):
     - `git merge origin/<base-branch>`

4. **Identify conflicting files**:
   - List conflicts: `git diff --name-only --diff-filter=U`
   - For each file, show conflict regions

5. **Resolve each conflict**:
   - For each conflicting file:
     - Display the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
     - Analyze both versions:
       - **HEAD (ours)**: Changes from current branch
       - **theirs**: Changes from base branch
     - Determine the correct resolution:
       - Keep ours
       - Keep theirs
       - Combine both changes
       - Write new implementation
     - Apply the resolution
     - Explain the reasoning (in detected language)

6. **Mark as resolved**:
   - Stage resolved files: `git add <resolved-files>`
   - If rebasing: `git rebase --continue`
   - If merging, commit with message in detected language:
     - English: `merge: resolve conflicts with <base-branch>`
     - Japanese: `merge: <base-branch>とのコンフリクトを解消`

7. **Push changes**:
   - If rebasing: `git push --force-with-lease`
   - If merging: `git push`
   - Warn user before force push (in detected language)

8. **Return the result** (in detected language):

## English Format

```markdown
## Conflict Resolution Summary

### Resolved Files

| File            | Resolution    | Reasoning                     |
| --------------- | ------------- | ----------------------------- |
| path/to/file.ts | Combined both | Both changes were independent |

### Actions Taken

- Strategy used: merge / rebase
- Commits created: X
- Force push required: Yes / No
```

## Japanese Format (日本語)

```markdown
## コンフリクト解消サマリー

### 解消したファイル

| ファイル        | 解決方法   | 理由                         |
| --------------- | ---------- | ---------------------------- |
| path/to/file.ts | 両方を統合 | 両方の変更が独立していたため |

### 実行したアクション

- 使用した戦略: merge / rebase
- 作成したコミット: X件
- Force pushが必要: はい / いいえ
```

## Notes

- For complex conflicts (large files, architectural changes), show the conflict and ask for guidance
- Always use `--force-with-lease` instead of `--force` for safety
- If rebase results in many conflicts, consider aborting and using merge instead
- After resolution, suggest running tests to verify nothing is broken
