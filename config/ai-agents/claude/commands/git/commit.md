---
name: commit
allowed-tools: Read(~/.dotfiles/doc/templates/conventional_commits.md), Bash(git status:*), Bash(git add:*), Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git commit:*)
argument-hint: [language]
description: AIが生成したコミットメッセージを使用して、ステージングされた変更をコミットします。
context: fork
---

# git commit

AIが生成したコミットメッセージを使用して、ステージングされた変更をコミットします。

## 引数

- `language`: コミットメッセージの言語（例: "ja", "en"）。デフォルト: "English"

## コンテキスト

- ステージングされた変更: !`git diff --cached`
- Git ステータス: !`git status`
- 現在のブランチ: !`git branch --show-current`
- 最近のコミット: !`git log -10 --oneline`
- Conventional Commits 仕様: `~/.dotfiles/doc/templates/conventional_commits.md` を Read で参照してください。

## タスク

1. ステージングされた変更がない場合は、先に変更をステージングするようユーザーに促してください。
2. Conventional Commits 形式に従ったコミットメッセージを生成してください:
   - 1行目: `<type>: <description>`（スコープなし）
   - 2行目: 空行
   - 3行目以降: 変更内容を箇条書きで記述
3. **重要: コミットメッセージは必ず `$ARGUMENTS` で指定された言語（デフォルト: 英語）で記述してください。** Conventional Commits 仕様はフォーマットの参考としてのみ使用し、実際のメッセージは指定された言語で記述してください。
4. `git commit -m "<メッセージ>"` でコミットを実行してください。
5. 最後に、生成したコミットメッセージのみを出力してください。余計な説明や情報は不要です。
