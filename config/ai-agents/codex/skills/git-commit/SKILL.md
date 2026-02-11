---
name: git-commit
description: Commit current staged changes with an AI-generated Conventional Commits message in the specified language.
---


# git commit

Commit current staged changes with AI-generated commit message in the specified language.

## Arguments

- `language`: Language for commit message (e.g., "ja", "en"). Default: "English"

## Context

- Current staged changes: !`git diff --cached`
- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log -10 --oneline`
- Conventional Commits specification: Read `~/.dotfiles/doc/templates/conventional_commits.md` for the full specification.

## Task

1. If no staged changes exist, prompt the user to stage changes first.
2. Generate a commit message following Conventional Commits format:
   - First line: `<type>: <description>` (no scope)
   - Second line: blank
   - Third line onwards: bullet points describing changes
3. **IMPORTANT: The commit message MUST be written in `$ARGUMENTS` language (default: English).** The Conventional Commits specification is for format reference only; always write the actual message in the specified language.
4. Commit with `git commit -m "<message>"`.
