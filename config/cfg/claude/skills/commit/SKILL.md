---
name: commit
description: When user requests to commit, use this skill. Commit current staged changes with commit message formatted by Conventional Commits.
allowed-tools: Read, Grep, Glob
---

# Commit

This skill is used to commit current staged changes with commit message formatted by Conventional Commits.

## Task

1. Check the current staged changes, branch and recent commits using
   `git diff --cached`, `git status`, `git branch --show-current` and `git log -10 --oneline`.
2. If there are no staged changes, respond with "No staged changes found. Can I add all changes to the commit with command `git add -A`?"
3. Generate a concise and descriptive commit message summarizing the staged changes,
   following the Conventional Commits format.
   After the first line (title), add a blank line, then list comments as bullet points starting from the third line. Do not include scope in commit title.
4. Commit the staged changes with the generated commit message using `git commit -m "<commit message>"`.

## References

- Current staged changes: !`git diff --cached`
- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log -10 --oneline`
- Convetional Commits specification: [Conventional Commits 1.0.0](./conventional_commits.md)
