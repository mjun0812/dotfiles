---
allowed-tools: Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(ls:*), Bash(bat:*), Bash(eza:*), Bash(grep:*), Bash(head:*), Bash(tail:*), Bash(jq:*)
argument-hint: [PR number] [--post]
description: Review a pull request as an independent reviewer and provide structured feedback with inline comments.
---

# Review Pull Request

## Arguments

- `PR number`: PR number to review (optional, defaults to PR for current branch)
- `--post`: Post the review with inline comments to GitHub (optional)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,title,state,baseRefName,headRefName,url 2>/dev/null || echo "No PR found for current branch"`
- PR title: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: !`gh pr view --json body --jq '.body' 2>/dev/null | head -50`
- Repository: !`gh repo view --json nameWithOwner --jq .nameWithOwner`

## Task

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use `gh pr view <number>`
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English, Chinese)
   - **IMPORTANT**: All review comments and reports MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Gather PR information**:
   - Get PR metadata: `gh pr view <number> --json title,body,baseRefName,headRefName,author,additions,deletions,changedFiles`
   - Get list of changed files: `gh pr view <number> --json files --jq '.files[].path'`
   - Get the diff: `gh pr diff <number>`
   - Get the latest commit SHA: `gh pr view <number> --json commits --jq '.commits[-1].oid'`

3. **Analyze the changes**:
   - Understand the purpose of the PR from title and description
   - Identify the scope of changes (which modules/features are affected)
   - Note the size of the PR (additions, deletions, files changed)

4. **Review the code** with the following perspectives:
   - **Correctness**: Logic errors, bugs, edge cases not handled
   - **Security**: Vulnerabilities, injection risks, authentication/authorization issues
   - **Performance**: Inefficient algorithms, N+1 queries, unnecessary computations
   - **Readability**: Naming conventions, code structure, complexity
   - **Maintainability**: Code duplication, tight coupling, missing abstractions
   - **Testing**: Test coverage, test quality, missing test cases
   - **Documentation**: Missing comments, outdated docs, unclear code

5. **Generate review report**:
   - Use the appropriate template based on the detected language
   - See [Review Report Templates](#review-report-templates) below
   - **IMPORTANT**: For items in "Must Fix" and "Should Fix", use exact format `` `filepath:line` `` to enable inline comment posting

6. **Post review to GitHub** (if `--post` flag is provided):
   - Confirm with user before posting
   - Parse the review report to extract inline comments from "Must Fix" and "Should Fix" sections
   - Post using `gh api` with the reviews endpoint (see [Posting Review with Inline Comments](#posting-review-with-inline-comments))

7. **Return the result**:
   - Display the review report in the detected language
   - If posted, show the URL of the PR

## Review Report Templates

### English Template

```markdown
# Review by Claude

## Summary

<!-- 1-2 sentence summary of what this PR does -->

## Good Points

- <!-- Positive aspects of the implementation -->

## Must Fix (Blocking)

- [ ] `filename:line` - Description of the issue

## Should Fix (Non-blocking)

- [ ] `filename:line` - Description of the suggestion

## Questions

- <!-- Questions for the author -->

## Verdict

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->
```

### Japanese Template (日本語)

```markdown
# Review by Claude

## 概要

<!-- このPRの変更内容を1-2文で要約 -->

## 良い点

- <!-- 実装の良い点 -->

## 要修正（ブロッキング）

- [ ] `ファイルパス:行番号` - 問題の説明

## 提案（ノンブロッキング）

- [ ] `ファイルパス:行番号` - 提案内容

## 質問

- <!-- 作成者への質問 -->

## 判定

<!-- APPROVE / REQUEST_CHANGES / COMMENT -->
```

## Posting Review with Inline Comments

When `--post` flag is provided:

### Step 1: Parse inline comments from report

Extract items from "Must Fix" / "要修正" and "Should Fix" / "提案" sections.

Pattern: `` `filepath:line` - comment ``

Example:

```
- [ ] `src/auth.ts:42` - null チェックが必要です
```

→ `{ "path": "src/auth.ts", "line": 42, "body": "🔴 **要修正**: null チェックが必要です" }`

### Step 2: Prepare variables

```bash
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER=$(echo $REPO | cut -d'/' -f1)
REPO_NAME=$(echo $REPO | cut -d'/' -f2)
PR_NUMBER=<number>
COMMIT_SHA=$(gh pr view $PR_NUMBER --json commits --jq '.commits[-1].oid')
```

### Step 3: Build and post the review

```bash
gh api repos/$OWNER/$REPO_NAME/pulls/$PR_NUMBER/reviews \
  -f body="# Review by Claude

## 概要
...

## 判定
REQUEST_CHANGES" \
  -f commit_id="$COMMIT_SHA" \
  -f event="REQUEST_CHANGES" \
  --raw-field 'comments=[{"path":"src/auth.ts","line":42,"body":"🔴 **要修正**: null チェックが必要です"}]'
```

### Comment prefixes by section

| Section    | English    | Japanese | Emoji Prefix   |
| ---------- | ---------- | -------- | -------------- |
| Must Fix   | Must Fix   | 要修正   | 🔴 **要修正**: |
| Should Fix | Suggestion | 提案     | 💡 **提案**:   |

### Event types

| Verdict         | Event             |
| --------------- | ----------------- |
| APPROVE         | `APPROVE`         |
| REQUEST_CHANGES | `REQUEST_CHANGES` |
| COMMENT         | `COMMENT`         |

## Notes

- Line numbers must correspond to the NEW file (right side of diff)
- If a comment cannot be posted as inline (e.g., line not in diff), it will be included in the body
- Maximum 50 inline comments per review
