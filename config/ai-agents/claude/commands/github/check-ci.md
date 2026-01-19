---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
description: Check CI status for a repository, analyze failures, and fix issues automatically.
---

# Check CI Status and Fix Failures

## Context

- Current branch: !`git branch --show-current`
- CI status: !`gh pr checks 2>/dev/null || echo "No checks found"`

## Task

1. **Check CI status**:
   - Run `gh pr checks` to get all check statuses
   - If all checks pass, report success (in detected language) and exit
   - If checks are still running, report status and ask user whether to wait or proceed

2. **Identify failed checks**:
   - List all failed checks with their names
   - Get the workflow run IDs: `gh run list --branch <branch> --json databaseId,name,status,conclusion`

3. **Retrieve error logs**:
   - For each failed check, get detailed logs: `gh run view <run-id> --log-failed`
   - Parse the logs to identify:
     - Error type (test failure, lint error, build error, type error, etc.)
     - Affected files and line numbers
     - Error messages

4. **Analyze and categorize errors**:
   - **Test failures**: Identify failing test cases and assertions
   - **Lint errors**: Identify style violations and their locations
   - **Build errors**: Identify compilation or bundling issues
   - **Type errors**: Identify type mismatches and their locations
   - **Other**: Categorize any other error types

5. **Fix the issues**:
   - For each identified issue:
     - Navigate to the affected file
     - Apply the appropriate fix
     - Verify the fix doesn't break other functionality
   - If a fix is unclear or risky, ask user for confirmation

## Notes

- If multiple CIs fail, fix them in dependency order (e.g., build before test)
- For flaky tests, report the suspicion and suggest re-running
- For environment-related failures (missing secrets, permissions), report that manual intervention is needed
- If the same CI fails repeatedly, suggest investigating the root cause
