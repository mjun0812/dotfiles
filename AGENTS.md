# dotfiles

macOS / Linux向けのdotfiles。リポジトリ内のファイルをホームディレクトリへsymlinkで展開するので、編集は実環境にそのまま反映される。

`AGENTS.md` が実体で、`CLAUDE.md` はそこへのsymlinkである。

## コマンド

```bash
./install.sh                     # フルインストール。既存環境を上書きするので、検証はローカルで再実行せずCIで行う
mise dot status                  # symlinkの展開状態
mise dot apply                   # symlinkを展開する
mise bootstrap packages status   # macOSのパッケージと宣言の差分
mise bootstrap packages apply    # 宣言どおりにパッケージを入れる
prek run --all-files             # フォーマットと検査 (pre-commit hookと同じ)
./update.sh                      # ローカルのapp設定をdotfilesへ逆同期する
python3 script/tools/doctor.py   # local環境がdotfilesの更新に追従しているかを調べる
```

`install.sh` の一部だけをやり直すときは、`script/setup/` の該当scriptを実行する。

## symlinkの展開

展開するファイルは `config/dot_config/mise/conf.d/dotfiles.toml` の `[dotfiles]` に宣言する。`config/dot/<name>` は `~/.<name>` へ、`config/dot_config/<name>` は `~/.config/<name>` へ展開する。

- `config/dot` や `config/dot_config` にファイルを足したら、`dotfiles.toml` にもエントリを足す。ファイルかディレクトリ1つにつき1エントリで並べ、`dot_prefix` は使わない。足し忘れはprekが検出する。
- OSで展開先が変わるものは `variants` で分ける。
- appが状態を書き込むディレクトリは、ディレクトリごとではなく設定ファイルだけをlinkする。
- 展開先にあった実ファイルは `.backup/` へ退避される。

## パッケージ管理

toolとパッケージは `config/dot_config/mise/` に宣言する。共通のものは `config.toml`、OS別のものは `config.macos.toml` と `config.linux.toml` に書く。

- CLI toolは `[tools]` に宣言し、`mise install` で入れる。
- Homebrewのformulaとcaskは、`config.macos.toml` の `[bootstrap.packages]` に `brew:<formula>` / `brew-cask:<cask>` として宣言し、`mise bootstrap packages apply` で入れる。tapは `[bootstrap.brew.taps]` に宣言する。`brew install` や `brew tap` などのbrewコマンドを直接使うのは、`mise bootstrap packages` で扱えない場合に限る。

## AI agentの設定

Claude Code・Codex・Geminiの設定は `config/ai-agents/` にまとめている。

- global指示は、Claude Code用の `claude/CLAUDE.md` と、CodexとGemini用の `AGENTS_global.md` に分かれている。
- 共有skillとcode-reviewer agentは [mjun0812/skills](https://github.com/mjun0812/skills) にあり、`apm.yml` で購読して `apm update -g -y` で展開する。このリポジトリの `skills/` には私用skill(`mjun-*`)だけを置き、`script/setup/setup_skills.sh` が展開する。skillを追加・変更したら `doc/skills.md` と `doc/skills_ja.md` も更新する。
- このリポジトリ専用のskillは `.agents/skills/` に置き、`.claude/skills/` からsymlinkする。
- MCPサーバーは `apm.yml` の `dependencies.mcp` で管理し、apmが各agentの設定へ書き込む。agentごとの設定ファイルには直接書かない。
- `rules/*.md` はClaude CodeとCodexが共有するので、frontmatterは両方が読める書式に限る。書式は `script/tools/rule-paths.sh` が定義し、prekが確かめる。
- hookのscriptは `hooks/` に置き、`claude/settings.json` と `codex/hooks.json` から呼ぶ。Codexのhook定義を変えると、TUIの `/hooks` で再承認が必要になる。
- `codex/config.toml` はsymlinkせず、テンプレートにあるキーだけを `~/.codex/config.toml` へマージする。Codexが書き込むローカル状態を残すためである。キーの削除はできない。`[projects]` のようなローカル状態のテーブルと、apmが書き込む `[mcp_servers.*]` はテンプレートに書かない。
- `gemini/antigravity-cli/settings.json` も同じ方式でマージする。Antigravity CLIが起動のたびにファイルを書き直すためである。CLIが書き足す `trustedWorkspaces` はテンプレートに書かない。

## zsh

起動ファイルは、読まれるタイミングで役割を分けている。

| ファイル                      | 読まれるタイミング | 置くもの                  |
| ----------------------------- | ------------------ | ------------------------- |
| `config/dot/zshenv`           | 全shell            | 環境変数                  |
| `config/dot/zprofile`         | login時に1回       | PATH                      |
| `config/dot/zshrc`            | 対話shell          | 対話shellの初期化         |
| `config/dot_config/zsh/*.zsh` | sheldonが読み込む  | option、補完、関数、alias |

pluginの読み込み順序には制約があり、`config/dot_config/sheldon/plugins.toml` 冒頭のコメントに書いてある。

## 規約

- スクリプトは原則としてzsh(`#!/usr/bin/env zsh`)で書く。
- フォーマッタが壊す設定ファイルは、`.oxfmtrc.json` の `ignorePatterns` と、`.pre-commit-config.yaml` にあるoxfmtの `exclude` の両方に登録する。
- テストとCIで確かめるのは、toolやappがインストールされ、設定ファイルが展開されていることだけにする。設定の中身(キー割り当てや値、補助スクリプトの動作など)が正しいかは、そのappやtoolを実際に使って判断する。
- `main` にはrulesetでレビュー必須が設定されているが、owner(mjun0812)はbypassしてよい。PRは `gh pr merge --admin` でmergeし、軽微な変更は `main` へ直接commit・pushしてよい。
