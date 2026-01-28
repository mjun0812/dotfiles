---
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(bat:*)
argument-hint: [language] [--label <name>] [--assignee <username>]
description: Create a GitHub Issue interactively by gathering information from the user.
context: fork
---

# Create GitHub Issue

Create a GitHub Issue interactively by gathering information from the user.

## Arguments

- `language`: Language for Issue title and body (e.g., "ja", "en"). Default: "English"
- `--label <name>`: Add label (optional, can be specified multiple times)
- `--assignee <username>`: Assign user (optional, can be specified multiple times)

## Context

- Repository info: !`gh repo view --json name,owner --jq '"\(.owner.login)/\(.name)"'`
- Available labels: !`gh label list --limit 50 --json name --jq '.[].name' 2>/dev/null || echo "none"`
- Issue templates: !`ls .github/ISSUE_TEMPLATE/ 2>/dev/null || echo "none"`

## Task

1. **Ask Issue type**: Use AskUserQuestion to ask the user what kind of Issue to create:
   - Feature Request
   - Bug Report
   - Other (free-form)

2. **Gather information**: Use AskUserQuestion to collect:
   - Issue title
   - Detailed description (what, why, context)
   - For Bug Report: steps to reproduce, expected behavior, actual behavior
   - For Feature Request: motivation, proposed solution

3. **Check for repository Issue templates**:
   - If `.github/ISSUE_TEMPLATE/` exists and contains templates, read the matching template and use it as the Issue body structure.
   - If no repository templates exist, use the [built-in templates below](#built-in-issue-templates) in the language specified by $ARGUMENTS (default: English).

4. **Generate Issue body**: Fill in the template with the information gathered from the user.

5. **Create the Issue**:
   ```
   gh issue create --title "<title>" --body "<body>" [--label <name>] [--assignee <username>]
   ```
   - If `--label` was provided in $ARGUMENTS, add those labels.
   - If `--assignee` was provided in $ARGUMENTS, add those assignees.

6. **Return the result**:
   - Show the URL of the created Issue
   - Show a brief summary (title, labels, assignees)

## Built-in Issue Templates

### Feature Request (English)

```markdown
## Summary

<!-- Briefly describe the feature you'd like. -->

## Motivation

<!-- Why do you need this feature? What problem does it solve? -->

## Proposed Solution

<!-- Describe your proposed solution or approach. -->

## Alternatives Considered

<!-- List any alternative solutions or features you've considered. -->

## Additional Context

<!-- Add any other context, mockups, or references. -->
```

### Feature Request (日本語)

```markdown
## 概要

<!-- 希望する機能を簡潔に記載してください -->

## 背景・動機

<!-- なぜこの機能が必要ですか？どのような問題を解決しますか？ -->

## 提案する解決策

<!-- 提案する解決策やアプローチを記載してください -->

## 検討した代替案

<!-- 検討した代替案があれば記載してください -->

## 補足情報

<!-- その他の参考情報やモックアップなどがあれば記載してください -->
```

### Bug Report (English)

```markdown
## Description

<!-- Describe the bug clearly and concisely. -->

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

<!-- What did you expect to happen? -->

## Actual Behavior

<!-- What actually happened? -->

## Environment

- OS:
- Version:

## Additional Context

<!-- Add any other context, logs, or screenshots. -->
```

### Bug Report (日本語)

```markdown
## 概要

<!-- バグの内容を簡潔に記載してください -->

## 再現手順

1.
2.
3.

## 期待する動作

<!-- 本来どのような動作を期待していますか？ -->

## 実際の動作

<!-- 実際にはどのような動作になりますか？ -->

## 環境

- OS:
- バージョン:

## 補足情報

<!-- その他の参考情報やログ、スクリーンショットなどがあれば記載してください -->
```
