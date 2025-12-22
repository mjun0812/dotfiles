---
allowed-tools: Bash(git status:*), Bash(git add:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*)
description: Commit current staged changes with AI-generated commit message.
---

## Context

- Current staged changes: !`git diff --cached`
- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log -10 --oneline`
- Convetional Commits specification: `~/.dotfiles/doc/conventional_commits.md`

## Task

Important: This command only commits staged changes. It does not stage any new files.

1. Check the current staged changes, branch and recent commits using
   `git diff --cached`, `git status`, `git branch --show-current` and `git log -10 --oneline`.
2. If there are no staged changes, prompt the user to stage the changes.
3. Generate a concise and descriptive commit message summarizing the staged changes,
   following the [Conventional Commits format](~/.dotfiles/doc/conventional_commits.md).
   After the first line (title), add a blank line, then list comments as bullet points starting from the third line. Do not include scope in commit title.
4. Commit the staged changes with the generated commit message using `git commit -m "<commit message>"`.
