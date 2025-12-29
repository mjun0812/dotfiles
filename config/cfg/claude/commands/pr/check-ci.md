---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [PR number]
description: Check CI status for a PR, analyze failures, and fix issues automatically.
---

# Check CI Status and Fix Failures

## Arguments

- `PR number`: PR number to check (optional, defaults to PR for current branch)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,url 2>/dev/null || echo "No PR found"`
- PR title and body: !`gh pr view --json title,body --jq '"\(.title)\n\(.body)"' 2>/dev/null | head -30`
- CI status: !`gh pr checks 2>/dev/null || echo "No checks found"`

## Task

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use that PR
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All commit messages MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Check CI status**:
   - Run `gh pr checks` to get all check statuses
   - If all checks pass, report success (in detected language) and exit
   - If checks are still running, report status and ask user whether to wait or proceed

3. **Identify failed checks**:
   - List all failed checks with their names
   - Get the workflow run IDs: `gh run list --branch <branch> --json databaseId,name,status,conclusion`

4. **Retrieve error logs**:
   - For each failed check, get detailed logs: `gh run view <run-id> --log-failed`
   - Parse the logs to identify:
     - Error type (test failure, lint error, build error, type error, etc.)
     - Affected files and line numbers
     - Error messages

5. **Analyze and categorize errors**:
   - **Test failures**: Identify failing test cases and assertions
   - **Lint errors**: Identify style violations and their locations
   - **Build errors**: Identify compilation or bundling issues
   - **Type errors**: Identify type mismatches and their locations
   - **Other**: Categorize any other error types

6. **Fix the issues**:
   - For each identified issue:
     - Navigate to the affected file
     - Apply the appropriate fix
     - Verify the fix doesn't break other functionality
   - If a fix is unclear or risky, ask user for confirmation

7. **Commit and push** (use detected language for commit message):
   - Stage all changes: `git add -A`
   - Commit with message in detected language:
     - English: `fix: resolve CI failures - <brief description>`
     - Japanese: `fix: CI失敗を修正 - <簡潔な説明>`
   - Push to remote: `git push`

8. **Verify fix**:
   - Report that changes have been pushed (in detected language)
   - Note that CI will re-run automatically
   - Suggest running `/pr:check-ci` again after CI completes to verify

## Notes

- If multiple CIs fail, fix them in dependency order (e.g., build before test)
- For flaky tests, report the suspicion and suggest re-running
- For environment-related failures (missing secrets, permissions), report that manual intervention is needed
- If the same CI fails repeatedly, suggest investigating the root cause
