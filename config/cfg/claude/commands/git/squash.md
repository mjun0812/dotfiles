---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*)
argument-hint: [--one | --auto] [--message <commit message>]
description: Squash and organize commits on the current branch using interactive rebase.
---

# Squash Commits

## Arguments

- `--one` or `-1`: Squash all commits into a single commit
- `--auto`: Automatically organize commits by logical units
- `--message <msg>`: Specify the final commit message (used with `--one`)
- (none): Show commit analysis and ask for user preference

## Context

- Current branch: !`git branch --show-current`
- Base branch: !`gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"`
- PR title and body: !`gh pr view --json title,body --jq '"\(.title)\n\(.body)"' 2>/dev/null | head -30`
- Commits to squash: !`git log --oneline origin/$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo main)..HEAD 2>/dev/null | head -20`
- Commit count: !`git rev-list --count origin/$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null || echo main)..HEAD 2>/dev/null || echo "0"`

## Task

0. **Pre-checks**:
   - Verify there are commits to squash
   - If only 1 commit exists, report "Nothing to squash" (in detected language) and exit
   - Check for uncommitted changes: `git status --porcelain`
   - If dirty working directory, ask to stash or abort

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All commit messages and reports MUST be written in this detected language
   - If no PR exists, analyze existing commit messages to detect language
   - If language is ambiguous, default to English

2. **Identify base branch**:
   - If PR exists: `gh pr view --json baseRefName --jq '.baseRefName'`
   - Otherwise: Use repository default branch or `main`

3. **Analyze commit history**:
   - Get commits: `git log --oneline origin/<base>..HEAD`
   - Get detailed info: `git log --format="%h %s" origin/<base>..HEAD`
   - Categorize commits:
     - Feature commits (`feat:`, `add:`)
     - Fix commits (`fix:`, `bugfix:`)
     - Refactor commits (`refactor:`, `chore:`)
     - Style commits (`style:`, `format:`)
     - Test commits (`test:`)
     - Doc commits (`docs:`)

4. **Propose squash strategy** (in detected language):

#### English Format

```markdown
## Current Commits (X total)

| Hash    | Type  | Message                 |
| ------- | ----- | ----------------------- |
| abc1234 | feat  | Add user authentication |
| def5678 | fix   | Fix typo in auth        |
| ghi9012 | fix   | Address review comment  |
| jkl3456 | style | Format code             |

## Recommended Strategy

### Option 1: Single commit (--one)

All commits → `feat: Add user authentication`

### Option 2: Logical grouping (--auto)

- `feat: Add user authentication` (abc1234, def5678, ghi9012)
- `style: Format code` (jkl3456)

### Option 3: Keep as-is

No changes
```

#### Japanese Format (日本語)

```markdown
## 現在のコミット (全X件)

| ハッシュ | タイプ | メッセージ             |
| -------- | ------ | ---------------------- |
| abc1234  | feat   | ユーザー認証を追加     |
| def5678  | fix    | 認証のtypoを修正       |
| ghi9012  | fix    | レビューコメントに対応 |
| jkl3456  | style  | コードをフォーマット   |

## 推奨する整理方法

### オプション1: 1つにまとめる (--one)

全コミット → `feat: ユーザー認証を追加`

### オプション2: 論理単位でグループ化 (--auto)

- `feat: ユーザー認証を追加` (abc1234, def5678, ghi9012)
- `style: コードをフォーマット` (jkl3456)

### オプション3: 現状維持

変更なし
```

5. **Execute squash**:
   - If `--one`:
     - `git reset --soft origin/<base>`
     - `git commit -m "<message or generated>"` (in detected language)
   - If `--auto`:
     - Create rebase todo list grouping related commits
     - Execute `git rebase -i origin/<base>` with prepared instructions
   - If interactive:
     - Ask user for preference
     - Execute accordingly

6. **Generate commit message** (for `--one` without `--message`):
   - Analyze all commit messages
   - Identify the primary change type
   - Generate a comprehensive commit message in detected language:

   ```
   <type>: <primary change summary>

   - Detail 1
   - Detail 2
   - Detail 3
   ```

7. **Push changes**:
   - Warn in detected language: "This will require force push. Continue? (y/n)"
   - If confirmed: `git push --force-with-lease`
   - If declined: Provide manual instructions

8. **Return the result** (in detected language):

#### English Format

```markdown
## Squash Complete

### Before

- X commits

### After

- Y commits

### New Commit(s)

| Hash    | Message                       |
| ------- | ----------------------------- |
| xyz7890 | feat: Add user authentication |

### Pushed

- ✅ Force pushed to origin/<branch>
- ⚠️ CI will re-run
```

#### Japanese Format (日本語)

```markdown
## Squash完了

### 変更前

- X件のコミット

### 変更後

- Y件のコミット

### 新しいコミット

| ハッシュ | メッセージ               |
| -------- | ------------------------ |
| xyz7890  | feat: ユーザー認証を追加 |

### プッシュ

- ✅ origin/<branch>にforce pushしました
- ⚠️ CIが再実行されます
```

## Notes

- Always use `--force-with-lease` instead of `--force`
- Warn if branch is shared with others
- If rebase conflicts occur, guide user through resolution
- Preserve co-author information if commits have multiple authors
