---
description: Commit current staged changes with AI-generated commit message in the specified language.
argument-hint: [LANGUAGE=<language>]
---

## Arguments

- `language`: Language for commit message (e.g., "ja", "en"). Default: "English"

## Context

- Current staged changes: !`git diff --cached`
- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log -10 --oneline`

## Task

Important: This command only commits staged changes. It does not stage any new files.

1. Check the current staged changes, branch and recent commits using
   `git diff --cached`, `git status`, `git branch --show-current` and `git log -10 --oneline`.
2. If no staged changes exist, prompt the user to stage changes first.
3. Determine the commit message language from $ARGUMENTS (default: English) and ensure the commit message is written in that language.
4. Generate a concise and descriptive commit message summarizing the staged changes, following the Conventional Commits format.
   After the first line (title), add a blank line, then list comments as bullet points starting from the third line. Do not include scope in commit title.
5. Commit the staged changes with the generated commit message using `git commit -m "<commit message>"`.

