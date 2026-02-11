---
name: github-pr-respond-comment
description: Review and respond to review comments on a pull request.
---


# Respond to Review Comments

## Arguments

- `PR number`: PR number to respond to (optional, defaults to PR for current branch)
- `--reply`: Post reply comments to GitHub after addressing (optional)

## Context

- Current branch: !`git branch --show-current`
- Current PR: !`gh pr view --json number,url,reviewDecision 2>/dev/null || echo "No PR found"`
- PR title: !`gh pr view --json title --jq '.title' 2>/dev/null`
- PR body: !`gh pr view --json body --jq '.body' 2>/dev/null | head -30`
- Pending reviews: !`gh pr view --json reviews --jq '.reviews | map(select(.state != "APPROVED")) | length' 2>/dev/null || echo "0"`

## Task

0. **Pre-checks**:
   - If PR number is provided in $ARGUMENTS, use that PR
   - Otherwise, use the PR associated with the current branch
   - If no PR exists, abort with an error message

1. **Detect PR language**:
   - Analyze the PR title and body to detect the language (e.g., Japanese, English)
   - **IMPORTANT**: All commit messages and reply comments MUST be written in this detected language
   - If language is ambiguous, default to English

2. **Retrieve review comments**:
   - Get all reviews: `gh pr view <number> --json reviews`
   - Get review comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments`
   - Get general PR comments: `gh pr view <number> --comments`

3. **Filter out resolved comments**:
   - Skip comments that are already marked as "RESOLVED" in GitHub
   - Use `gh api` to check the `isResolved` status of review threads
   - Only process comments that are still pending/unresolved

4. **Categorize comments**:
   - **Requires code change**: Comments requesting modifications
   - **Questions**: Comments asking for clarification
   - **Suggestions**: Optional improvements
   - **Informational**: Comments that don't require action

5. **Display comment summary** (in detected language):

## English Format

```markdown
## Review Comments Summary

### ✅ Requires Code Change (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Proposed action: ...

### 💬 Requires Discussion (X items)

1. **[filename:line]** by @reviewer
   > Comment content
   > → Concern: [why this needs discussion]
   > → Your position: [your perspective with reasoning]

### Questions (X items)

1. **[filename:line]** by @reviewer
   > Question content
   > → Proposed answer: ...

### Suggestions (X items)

1. **[filename:line]** by @reviewer
   > Suggestion content
   > → Accept / Decline with reason: ...
```

## Japanese Format (日本語)

```markdown
## レビューコメント一覧

### ✅ 要修正 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 対応方針: ...

### 💬 要議論 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > コメント内容
   > → 懸念点: [議論が必要な理由]
   > → 見解: [技術的な根拠を含めた自分の立場]

### 質問 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 質問内容
   > → 回答案: ...

### 提案 (X件)

1. **[ファイル名:行番号]** by @reviewer
   > 提案内容
   > → 採用/不採用の理由: ...
```

6. **Evaluate comment validity**:
   - Before accepting any comment, critically assess its correctness and relevance
   - Consider:
     - Is the reviewer's understanding correct?
     - Does the suggestion actually improve the code?
     - Are there trade-offs the reviewer may not have considered?
     - Is this a matter of personal preference vs. objective improvement?
   - For **incorrect or debatable comments**:
     - Do NOT immediately implement the change
     - Instead, prepare a respectful reply explaining your perspective
     - Provide technical reasoning, references, or examples to support your position
     - Ask clarifying questions if the reviewer's intent is unclear
     - Wait for discussion resolution before making changes
   - Mark comments as:
     - ✅ **Accept**: Comment is valid and should be implemented
     - 💬 **Discuss**: Comment needs discussion before action
     - ❌ **Decline**: Comment is incorrect (provide clear reasoning)

7. **Address accepted comments**:
   - For code changes:
     - Navigate to the affected file and line
     - Apply the requested change
     - Explain what was changed
   - For questions:
     - Prepare a clear answer (in detected language)
   - For suggestions:
     - Apply if beneficial, or explain why not

8. **Commit and push** (use detected language for commit message):
   - Stage all changes: `git add -A`
   - Commit with message in detected language:
     - English: `fix: address review comments`
     - Japanese: `fix: レビューコメントに対応`
   - Push to remote: `git push`

9. **Post replies** (if `--reply` flag is provided):
   - Write replies in the detected language
   - For each comment, post a reply using:
     `gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment-id>/replies -f body="<reply>"`
   - Reply content depends on the action:
     - **Accepted & implemented**: What was changed + commit reference
     - **Needs discussion**: Your perspective + reasoning + questions
     - **Declined**: Clear explanation of why the suggestion wasn't adopted
   - Example replies for accepted changes:
     - English: "Fixed in abc1234. Changed X to Y as suggested."
     - Japanese: "abc1234 で修正しました。ご指摘の通り X を Y に変更しました。"
   - Example replies for discussion:
     - English: "Thanks for the suggestion! I chose X because [reason]. However, I see your point about Y. Could you clarify [question]?"
     - Japanese: "ご提案ありがとうございます。[理由] のため X を選択しましたが、Y についてのご指摘も理解できます。[質問] について教えていただけますか？"

10. **Return the result** (in detected language):
   - Summary of actions taken
   - List of comments marked for discussion (awaiting reviewer response)
   - List of comments that need manual attention (if any)
   - Suggestion to request re-review if all blocking comments are addressed
   - **Note**: If there are comments awaiting discussion, recommend waiting for reviewer response before requesting re-review

## Notes

- If a comment's intent is unclear, ask the user for clarification before making changes
- For large design changes, discuss with the user before implementing
- Group related changes into logical commits if appropriate
- **Critical thinking is essential**: Not all review comments are correct. Reviewers can make mistakes or have different contexts. Always evaluate comments objectively.
- When disagreeing with a reviewer, be respectful and provide concrete technical reasoning
- Resolved comments are skipped entirely - no need to re-address them
