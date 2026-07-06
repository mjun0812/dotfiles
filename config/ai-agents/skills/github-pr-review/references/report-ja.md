# <reviewer-name> PR Review

<!--
記述ルール:
- 最終レビューには Must Fix のみを書く（verifier が confirmed と判定した指摘のみ）
- `[reviewer カテゴリ]` は **太字**、複数併記は `**[correctness / security]**` のようにスラッシュ区切り
- Must Fix がない場合も見出しを残し中身を「なし」と書く
- Must Fix の各項目には `理由` / `影響` / `対応` / `確度` / `証拠` を含める
- `確度` は `high` または `medium` のみ。確度の弱い指摘は最終レビューに出さない
- `証拠` は問題に実際に到達する実行パス（`file:line` の連鎖）
- CI に失敗がある場合は概要にその旨を1行含める
- 最終レビューに Should Fix / Question セクションは作成しない
- inline comment 化されるのは Must Fix セクションのみ
-->

## 概要

<!-- このプルリクエストの変更内容とレビュー結果を1-4文で要約 -->

## 判定

<!-- APPROVE or REQUEST_CHANGES -->

## Must Fix

- 1: `ファイルパス:行番号` - **[reviewer カテゴリ]** 問題の説明
  - 理由: ...
  - 影響: ...
  - 対応: ...
  - 確度: high | medium
  - 証拠: `file:line` -> `file:line` の連鎖

---

Reviewed by <reviewer-name> at `<short-sha>`
