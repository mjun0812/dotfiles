# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

macOS / Linux 向けのdotfiles。`install.sh` がリポジトリ内のファイルをホームディレクトリへsymlinkとして展開する方式で、リポジトリ内のファイルを編集すればそのまま実環境に反映される。

## コマンド

```bash
# フルインストール (症状の再現・検証はCIコンテナで行う。ローカルでの再実行は既存環境を上書きするので注意)
./install.sh

# 個別セットアップ (install.shから呼ばれる。対象部分だけ再実行したいとき)
zsh script/setup/setup_claude_code.sh   # Claude Code設定のsymlink・plugin
zsh script/setup/setup_codex.sh         # Codex設定 (config.tomlはキー単位マージ、他はsymlink)
bash script/setup/setup_herdr.sh        # herdr integration・skill生成・plugin link (miseのpostinstallからも呼ばれる)
script/setup/update_completions.sh      # zsh補完の更新

# ローカルのapp設定 (macOS app defaults・VSCode拡張リスト) をリポジトリへ逆同期
./update.sh

# フォーマット (pre-commit hookでも実行される)
prek run --all-files              # oxfmt (md/json/yaml/js/css) + shfmt + stylua (lua)

# VSCode拡張をextensions.txtと完全同期 (--dry-runで差分確認)
script/tools/sync_vscode_extensions.sh --dry-run
```

テストスイートは無い。検証はGitHub Actions (`ci-ubuntu.yml` / `ci-macos.yml`) がクリーンなコンテナで `install.sh` を実行し、symlinkと主要ツールの存在を確認する形で行われる。

## アーキテクチャ

### symlink展開の対応関係

`install.sh` と `script/setup/setup_*.sh` が以下のように展開する。展開先を直接編集しても実体はこのリポジトリ内のファイルである。

| リポジトリ内                                                                                | 展開先                                                                                            |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `config/dot/<name>`                                                                         | `~/.<name>`                                                                                       |
| `config/dot_config/<name>`                                                                  | `~/.config/<name>`                                                                                |
| `config/ai-agents/claude/{CLAUDE.md,settings.json,mcp.json,statusline.py,agents/*,rules/*}` | `~/.claude/` 配下                                                                                 |
| `config/ai-agents/skills/<skill>`                                                           | `~/.agents/skills/`, `~/.claude/skills/`, `~/.codex/skills/`, `~/.gemini/antigravity-cli/skills/` |
| `config/ai-agents/codex/{hooks.json,agents/*}`                                              | `~/.codex/` 配下                                                                                  |
| `config/ai-agents/AGENTS_global.md`                                                         | `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`                                                       |
| `config/vscode/`, `config/cursor/`                                                          | 各アプリのUserディレクトリ                                                                        |

上書き前の既存ファイルは `.backup/` に退避される。

### AI agent設定の共有構造

- skillは `config/ai-agents/skills/` に一元管理され、Claude Code / Codex / Gemini / Antigravityの4箇所へsymlinkされる。1箇所の編集が全agentに反映される。
- skillの一覧と依存関係は `doc/skills.md` (英語) と `doc/skills_ja.md` に記載されている。skillを追加・変更したらここも更新する (`doc-sync` skillがこの同期を担う)。
- Codexの `~/.codex/config.toml` だけはsymlinkではなく、`script/setup/rewrite_config.py` (tomlkit) がテンプレート (`config/ai-agents/codex/config.toml`) 側のキーだけを既存ファイルへマージする方式。Codexが自動生成する `[projects.*]` や `[hooks.state]` などのローカル状態を温存するため。キーの上書きのみでキーの削除はできない点に注意。
- Codexのhookは `config/ai-agents/codex/hooks.json` で管理され、`~/.codex/hooks.json` へsymlinkされる。hook定義を変更すると `[hooks.state]` の `trusted_hash` が無効になり、TUIの `/hooks` で再承認が必要になる。そのため通知の条件や文言はhooks.jsonではなくシェルスクリプト側に置く。
- `templates/` にはcommit message・PR・Issue・レビューのテンプレートがあり、skillから参照される。

## 規約

- スクリプトはzsh (`#!/usr/bin/env zsh`)。pre-commitのshfmt (`-s -i 4`) が `.sh` はshebangからのzsh自動判定で、`.zsh` は `--ln=zsh` 指定でフォーマットする。ただし `p10k.zsh` (生成ファイル) と `alias.zsh` (shfmtが未対応のzsh構文を含む) は対象外。
- oxfmtの対象外ファイルは `.oxfmtrc.json` の `ignorePatterns` に定義されている (`config/ai-agents/claude/settings.json` など)。フォーマッタが壊す設定ファイルを追加する場合はここに登録する。
- `main` にはrulesetでレビュー必須が設定されているが、owner (mjun0812) はこれをbypassしてよい。PRは `gh pr merge --admin` でmergeし、軽微な変更は `main` へ直接commit・pushして構わない。
