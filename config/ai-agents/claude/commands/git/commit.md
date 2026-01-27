---
name: commit
allowed-tools: Read(~/.dotfiles/doc/templates/conventional_commits.md), Bash(git status:*), Bash(git add:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*)
argument-hint: [language]
description: Commit current staged changes with AI-generated commit message in the specified language.
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
2. Generate a commit message in $ARGUMENTS language (default: English) following Conventional Commits:
   - First line: `<type>: <description>` (no scope)
   - Second line: blank
   - Third line onwards: bullet points describing changes
3. Commit with `git commit -m "<message>"`.
