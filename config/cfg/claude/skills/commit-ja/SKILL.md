---
name: commit-ja
description: "Commit current staged changes with commit message formatted by Conventional Commits in Japanese.　WHEN: When user requests to "日本語でコミットして", use this skill."
allowed-tools: Read, Grep, Glob
---

# Commit in Japanese

This skill is used to commit current staged changes with commit message formatted by Conventional Commits in Japanese.

## Task

MUST: 生成されたコミットメッセージは日本語である必要があります。

1. 現在のステージングされた変更、ブランチ、最近のコミットを`git diff --cached`、`git status`、`git branch --show-current`、`git log -10 --oneline`を使って確認します。
2. ステージングされたコミットがない場合は，ユーザーに"現在の変更を全てコミットしてもよろしいですか？"と確認します。
3. コンパクトで説明的なコミットメッセージを生成します。
   Conventional Commitsのフォーマットに従って、ステージングされた変更を要約します。
   最初の行（タイトル）の後に空の行を追加し、3行目から始まるコメントに変更内容を箇条書きで記述します。コミットタイトルにはスコープを含めないでください。
4. 生成された日本語のコミットメッセージを使用して、ステージングされた変更をコミットします。`git commit -m "<commit message>"`を使用します。
5. 続いてリモートにpushをするかをユーザーに確認します。"リモートにpushしてもよろしいですか？"と確認します。
6. ユーザーが"はい"と回答した場合は、`git push`を使用してリモートにpushします。

## Context

- 現在のステージングされた変更: `git diff --cached`
- 現在のgitステータス: `git status`
- 現在のブランチ: `git branch --show-current`
- 最近のコミット: `git log -10 --oneline`
- Convetional Commitsの仕様: [Conventional Commits 1.0.0](./conventional_commits_ja.md)
