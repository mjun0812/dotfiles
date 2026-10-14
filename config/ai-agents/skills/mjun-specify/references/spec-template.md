# spec.md Template

人間が承認するcontract。frontmatterにはライフサイクル状態 (`status: active | done`) とcontract承認状態 (`approval: pending | approved`) を持つ。

`Source:` 行は投影先のGitHub Issueがある場合だけ書く (純Localのspecでは省略する)。調査しても埋まらないセクションは省略する (空セクションやプレースホルダーを残さない)。小規模な修正ではBoundariesを丸ごと省略してよい。RequirementsとAcceptance Criteriaは省略しない。

```markdown
---
status: active
approval: pending
---

# <Title>

Source: #<N>

## Context

<なぜやるか。背景と現状>

## Goal

<この変更が実現する結果>

## Requirements

<満たすべき要求。番号付きで観察可能な振る舞いとして書く>

## Boundaries

### Owns

<この変更が所有する責務・モジュール>

### Does Not Own

<隣接するが所有しない責務。触れてはならない領域>

### Dependencies

<依存してよい既存の仕組み・モジュール。進行中の他specの成果に依存する場合は `spec: <slug>` の行で書く (そのspecが `status: done` になるまで実装を開始しない)>

### Public Contracts Affected

<この変更が影響するpublicなAPI・スキーマ・インターフェース>

### Revalidation Triggers

<このspecの前提が崩れ、見直しが必要になる条件>

## Acceptance Criteria

- [ ] <機械的に判定できる完了条件。「操作 → 観察できる結果」の形で、1件が1つの検査コマンドに落とせるように書く>

## Out of Scope

<やらないこと。スコープ外の明示>
```
