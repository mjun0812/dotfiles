---
name: github-issue-create
description: >-
  mjun-specifyのGitHub Issue作成alias。ユーザーが `/github-issue-create` を明示的に起動したときだけ使い、
  受け取った内容に `--issue` を付けてmjun-specifyへそのまま渡す。
  agentがこのskillを自発的に起動してはならない (Issue作成の依頼には直接mjun-specifyを使うこと)。
disable-model-invocation: true
allowed-tools: Skill(mjun-specify)
---

# github-issue-create

`mjun-specify` のGitHub Issue作成aliasです。従来の「issue作って」の入口を、明示起動のコマンドとして残しています。

受け取った引数と依頼内容に `--issue` を付けて、そのまま `mjun-specify` をSkill toolで呼び出してください。spec作成・Issue作成 (投影先)・調査・decision解決・承認・投影のすべては `mjun-specify` が行います。このskill自身は他に何もしません。

Skill toolが使えない環境では、`mjun-specify` のSKILL.mdを直接読み込み、その手順に従って実行してください。
