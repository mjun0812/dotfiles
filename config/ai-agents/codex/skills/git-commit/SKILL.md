---
name: git-commit
description: Commit current staged changes with an AI-generated Conventional Commits message in the specified language.
---

# git commit

Commit current staged changes with AI-generated commit message in the specified language.

## Arguments

- `language`: Language for commit message (e.g., "ja", "en"). Default: "English"

## Context

- Current git status: !`git status --short`
- Current staged summary: !`git diff --cached --stat && printf '\n---\n' && git diff --cached --name-only`
- Recent commits: !`git log -5 --oneline`

## Task

1. If no staged changes exist, prompt the user to stage changes first.
2. Start from the staged summary above. Inspect full or per-file diffs only when the summary is not enough to determine an accurate commit message.
3. Generate a commit message following Conventional Commits format:
   - First line: `<type>: <description>` (no scope)
   - Second line: blank
   - Third line onwards: bullet points describing changes
4. Use a standard Conventional Commits type such as `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, or `style`.
5. Do not use Markdown formatting in the commit message. Never include backticks.
6. **IMPORTANT: The commit message MUST be written in `$ARGUMENTS` language (default: English).** Always write the actual message in the specified language.
7. Commit safely in a way that preserves newlines and avoids shell interpolation issues. Prefer `git commit --file=-` with stdin over embedding the full message inside double quotes.
