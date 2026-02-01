# Global Instructions

Always respond in Japanese.

## Tools

You can use the following cli tools:

- fd
- ripgrep
- gh
- bat
- eza

## Versioning

- Follow Semantic Versioning 2.0.0 when handling version numbers.

## Python

- Use `uv` for environment and package management.
- Use `uvx ruff format` and `uvx ruff check --fix` for code formatting and linting.

## Git

- Commit messages must be in English.
- Always follow the conventional commits format when making commit messages.
- Always insert blank line on the second line and begin the commit description starting from the third line.
- When using Git tags, please use the format “v1.0.0” or “v2.1.3” for version control.

## Post accept plan

Plan modeのplanが承認された後は，planファイルの名前を，`YYYY-MM-DD-<short description>.md`の形式に変更してください．
設定でplanファイルの場所が変更されている場合があるので，注意してください．

例: `2024-06-15-add-github-issue-create-command.md`
