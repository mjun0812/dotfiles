# <reviewer-name> PR Review

<!--
記述ルール:
- 指摘事項には verifier が confirmed と判定した Finder と Standards と Contract SubAgent 由来の指摘のみを書く
- Standards / Contract SubAgent 由来の指摘もmergeをブロックしVerdictに影響する
- 指摘事項がない場合は見出しを残し中身を「なし」と書く
- 各項目には、問題の主な実害または種類を表す短いカテゴリラベルを付ける
- Finder由来、Standards由来、Contract由来の順に並べ、指摘事項全体を1から連番にする
- Finder由来の各項目には `問題` / `発生経路` / `完了条件` を含める
- Standards由来とContract由来の各項目には `問題` / `根拠` / `完了条件` を含める
- Finder由来の `問題` には発生条件・原因・具体的な実害をまとめる
- Standards由来の `問題` にはdiffで観察できる事実と、merge後への先送りが安全でない理由をまとめる
- Contract由来の `問題` には実装の現状と、contractの約束との食い違いをまとめる
- Contract由来の `根拠` にはspecの該当記述の引用と実装の `file:line` を書く
- Local spec由来のContract指摘は個別項目として書かず、概要に件数と未掲載理由を1行書く
- `発生経路` には問題へ到達する実行パスを `file:line` の連鎖で書く
- `完了条件` には実装方法ではなく、問題が解消されたと判断できる状態を書く
- Finder と verifier の生の `証拠` と検証ログはレビュー本文と inline comment に書かない。到達経路は `発生経路` として校正した形で書く
- CI に失敗がある場合は概要にその旨を1行含める
- 最終レビューに指摘事項以外の指摘セクションは作成しない
- inline comment 化されるのは指摘事項セクションのみ
-->

## 概要

<!-- このプルリクエストの変更内容とレビュー結果を1-4文で要約 -->

## 判定

<!-- APPROVE or REQUEST_CHANGES -->

## 指摘事項

<!-- Finder由来の指摘 -->

- 1: `ファイルパス:行番号` - **[カテゴリ] 問題の説明**
  - 問題: ...
  - 発生経路: `file:line` (説明) -> `file:line` (説明)
  - 完了条件: ...

<!-- Standards由来の指摘。merge後への先送りが安全でなく、mergeをブロックする -->

- 2: `ファイルパス:行番号` - **[カテゴリ] 問題の説明**
  - 問題: ...
  - 根拠: ...
  - 完了条件: ...

<!-- Contract由来の指摘。spec contractとの不整合で、mergeをブロックする -->

- 3: `ファイルパス:行番号` - **[カテゴリ] 問題の説明**
  - 問題: ...
  - 根拠: ...
  - 完了条件: ...

---

Reviewed by <reviewer-name> at `<short-sha>`
