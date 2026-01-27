---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [PR number] [--no-commit]
description: Check CI status for a repository or PR, analyze failures, and fix issues automatically.
---

# Check CI Status and Fix Failures

## Arguments

- `PR number`: PR number to check (optional)
- `--no-commit`: Skip committing and pushing after fixing (optional)

## Context

- Current branch: `git branch --show-current`
- Current PR: `gh pr view --json number,url 2>/dev/null || echo "No PR found"`
- PR title: `gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: `gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- CI status: `gh pr checks 2>/dev/null || echo "No checks found"`

## Task

### Phase 0: Pre-checks and Mode Detection

Determine the operation mode:

1. **If PR number is provided in $ARGUMENTS**: Use PR mode with that PR
2. **If no PR number but current branch has an associated PR**: Use PR mode with that PR
3. **If no PR exists**: Use Repository mode (no commit/push at the end)

Store the detected mode for later phases.

### Phase 1: Detect Language (PR mode only)

- Analyze the PR title and body to detect the language (e.g., Japanese, English)
- **IMPORTANT**: All commit messages MUST be written in this detected language
- If language is ambiguous, default to English

### Phase 2: Check CI Status

- Run `gh pr checks` to get all check statuses
- If all checks pass, report success (in detected language for PR mode) and exit
- If checks are still running, report status and ask user whether to wait or proceed

### Phase 3: Identify Failed Checks

- List all failed checks with their names
- Get the workflow run IDs: `gh run list --branch <branch> --json databaseId,name,status,conclusion`

### Phase 4: Retrieve Error Logs

- For each failed check, get detailed logs: `gh run view <run-id> --log-failed`
- Parse the logs to identify:
  - Error type (test failure, lint error, build error, type error, etc.)
  - Affected files and line numbers
  - Error messages

### Phase 5: Analyze and Categorize Errors

- **Test failures**: Identify failing test cases and assertions
- **Lint errors**: Identify style violations and their locations
- **Build errors**: Identify compilation or bundling issues
- **Type errors**: Identify type mismatches and their locations
- **Other**: Categorize any other error types

### Phase 6: Fix the Issues

- For each identified issue:
  - Navigate to the affected file
  - Apply the appropriate fix
  - Verify the fix doesn't break other functionality
- If a fix is unclear or risky, ask user for confirmation

### Phase 7: Commit and Push (PR mode only, unless --no-commit)

**Skip this phase if**:

- Running in Repository mode
- `--no-commit` flag is provided

**Execute**:

- Stage all changes: `git add -A`
- Commit with message in detected language:
  - English: `fix: resolve CI failures - <brief description>`
  - Japanese: `fix: CI失敗を修正 - <簡潔な説明>`
- Push to remote: `git push`

### Phase 8: Verify and Report

**PR mode**:

- Report that changes have been pushed (in detected language)
- Note that CI will re-run automatically
- Suggest running `/github:fix-ci` again after CI completes to verify

**Repository mode**:

- Report what was fixed
- Note that user should commit and push manually if satisfied

## Notes

- If multiple CIs fail, fix them in dependency order (e.g., build before test)
- For flaky tests, report the suspicion and suggest re-running
- For environment-related failures (missing secrets, permissions), report that manual intervention is needed
- If the same CI fails repeatedly, suggest investigating the root cause
