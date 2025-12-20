# dotfiles

## Install

require git, zsh

```bash
git clone --recursive git@github.com:mjun0812/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## Git Commands

```bash
# Delete local branches that are deleted and merged
# すでにremoteでマージされて，削除されたブランチをローカルでも削除する
git prune-branch

# commit with AI generated commit message
# AIが生成したコミットメッセージでコミットする
git aicommit
# commit with AI generated commit message in Japanese
# AIが生成した日本語のコミットメッセージでコミットする
git aicommit-ja

# generate pull request with AI generated title and description
# AIが生成したタイトルと説明でプルリクエストを作成する
git aipr
# generate pull request with AI generated title and description in Japanese
# AIが生成した日本語のタイトルと説明でプルリクエストを作成する
git aipr-ja
```

## Alias

```bash
# Show NVIDIA GPUs that are not used by Xorg or gnome
nvs

# Claude Code
cc-commit # AIが生成したコミットメッセージでコミットする
cc-commit-ja # AIが生成した日本語のコミットメッセージでコミットする
cc-pr # AIが生成したタイトルと説明でプルリクエストを作成する
cc-pr-ja # AIが生成した日本語のタイトルと説明でプルリクエストを作成する

# Gemini-cli
gemini-commit # AIが生成したコミットメッセージでコミットする
gemini-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Codex
codex-commit # AIが生成したコミットメッセージでコミットする
codex-commit-ja # AIが生成した日本語のコミットメッセージでコミットする

# Copilot-cli
copilot-commit # AIが生成したコミットメッセージでコミットする
copilot-commit-ja # AIが生成した日本語のコミットメッセージでコミットする
copilot-pr # AIが生成したタイトルと説明でプルリクエストを作成する
copilot-pr-ja # AIが生成した日本語のタイトルと説明でプルリクエストを作成する

# Alias
aicommit # = cc-commit
aicommit-ja # = cc-commit-ja
aipr # = cc-pr
aipr-ja # = cc-pr-ja
```
