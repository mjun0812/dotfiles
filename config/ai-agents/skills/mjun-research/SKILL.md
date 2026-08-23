---
name: mjun-research
description: >-
  意思決定に必要な外部事実を一次資料 (公式ドキュメント・ソースコード・仕様書) から調査し、claimごとに出典を付けて記録するSkill。
  ユーザーが「一次資料で調べて」「公式ドキュメントを確認して」と依頼したときや、spec作成中に外部仕様の知識不足でdecisionが決められないときに使うこと。
  会話済み内容のまとめ (md-note) や、対象リポジトリのコードを読むだけで足りる調査には使わない。
allowed-tools: Read, Write, Glob, Grep, WebSearch, WebFetch, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(ls:*), Bash(cat:*)
---

# mjun-research

外部事実の知識不足をユーザーへの質問で埋めず、一次資料への調査で解決するSkillです。調査結果はdecisionの証拠として呼び出し元へ返します。decisionそのものは確定しません。

## Arguments

- `question` (必須): 調査する質問。1回の起動で1つの質問だけを扱う
- `destination` (任意): 結果の保存先。`.mjun/specs/<slug>` のLocal specディレクトリ、またはGitHub Issue番号。未指定で、会話の文脈からも特定できない場合は保存先をユーザーに確認する

## 調査の原則

- **一次資料を優先する**: 公式ドキュメント、対象ライブラリのソースコード、標準仕様、first-partyのAPIリファレンスを読む。解説記事やQ&Aサイトは、一次資料への手がかりとしてだけ使い、根拠として引用しない
- **バージョンを特定する**: 対象リポジトリが使っているバージョン (lockfile、manifest) を確認し、そのバージョンに対応する資料を読む
- **claimごとに出典を付ける**: 調査結果の各主張に、URL・ファイルパス・仕様の節番号など、検証可能な出典を添える。出典を示せない主張は「未確認」として区別する
- **decisionを確定しない**: 調査は判断材料の提供までとする。結果を受けたdecisionの分類・決定は呼び出し元が行う

## 手順

1. 質問を、答えの形が定まる1文に明確化する。複数の質問が混ざっている場合は分割し、今回の1問を呼び出し元またはユーザーに確認する
2. 対象リポジトリの依存とバージョンを確認し、読むべき一次資料を特定する
3. 一次資料を調査する。WebSearchは資料の所在探しに使い、根拠は必ず一次資料本体から取る
4. 結果を次の形式で記録する

```markdown
# Research: <topic>

## Question

<調査した質問>

## Findings

- <claim 1>
  - Source: <URL / path / 仕様の節>
- <claim 2>
  - Source: ...

## Unresolved

- <一次資料では確認できなかった点。なければ「なし」>

## Implication

<このdecisionに対して調査結果が示唆すること (推奨ではなく含意)>
```

5. 保存する
   - Local spec: `.mjun/specs/<slug>/research/<topic>.md` (`<topic>` は内容を表す英語kebab-case。`research/` が無ければ作成する)
   - GitHub Issue: 上記の内容を要約してIssueコメントとして投稿する (`gh issue comment`)
   - どちらでもない単発調査: 保存先をユーザーに確認してから保存する
6. 呼び出し元へFindings・Unresolved・Implicationを返す
