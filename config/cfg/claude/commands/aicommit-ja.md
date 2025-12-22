---
allowed-tools: Bash(git status:*), Bash(git add:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*)
description: Commit current staged changes with AI-generated commit message in Japanese.
---

## Context

- 現在のステージングされた変更: !`git diff --cached`
- 現在のgitステータス: !`git status`
- 現在のブランチ: !`git branch --show-current`
- 最近のコミット: !`git log -10 --oneline`
- Convetional Commitsの仕様: `~/.dotfiles/doc/conventional_commits_ja.md`

## Task

IMPORTANT: このコマンドはステージングされた変更のみをコミットします。新しいファイルをステージングしません。
MUST: 生成されたコミットメッセージは日本語である必要があります。

1. 現在のステージングされた変更、ブランチ、最近のコミットを`git diff --cached`、`git status`、`git branch --show-current`、`git log -10 --oneline`を使って確認します。
2. ステージングされたコミットがない場合は，ユーザーにステージングを促します。
3. コンパクトで説明的なコミットメッセージを生成します。
   [Conventional Commitsのフォーマット](~/.dotfiles/doc/conventional_commits_ja.md)に従って、ステージングされた変更を要約します。
   最初の行（タイトル）の後に空の行を追加し、3行目から始まるコメントに変更内容を箇条書きで記述します。コミットタイトルにはスコープを含めないでください。
4. 生成された日本語のコミットメッセージを使用して、ステージングされた変更をコミットします。`git commit -m "<commit message>"`を使用します。
