# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

macOS / Linux向けのdotfiles。`install.sh` がリポジトリ内のファイルをホームディレクトリへsymlinkとして展開する方式で、リポジトリ内のファイルを編集すればそのまま実環境に反映される。

## コマンド

```bash
# フルインストール (症状の再現・検証はCIコンテナで行う。ローカルでの再実行は既存環境を上書きするので注意)
./install.sh

# 個別セットアップ (install.shから呼ばれる。対象部分だけ再実行したいとき)
zsh script/setup/setup_claude_code.sh   # Claude Code設定のsymlink・plugin
zsh script/setup/setup_codex.sh         # Codex設定 (config.tomlはキー単位マージ、他はsymlink)
bash script/setup/setup_herdr.sh        # herdr integration・plugin link (miseのpostinstallからも呼ばれる)
bash script/setup/setup_hunk.sh         # hunk-gh extensionのinstall (miseのpostinstallからも呼ばれる)
zsh script/setup/setup_codex_daemon.sh pin   # Codex daemonをmise管理のバージョンに固定 (miseのpostinstallからも呼ばれる。migrate/runも有り)
script/setup/update_completions.sh      # zsh補完の更新

# VSCode拡張リストをリポジトリへ逆同期し、miseで宣言したmacOSの設定とのずれを報告
./update.sh

# macOSの設定を変える前後の差分を、config.macos.toml に貼れる形で表示
python3 script/tools/mac_defaults.py snapshot   # 設定を変える前に実行
python3 script/tools/mac_defaults.py changes

# フォーマット (pre-commit hookでも実行される)
prek run --all-files              # oxfmt (md/json/yaml/js/css) + shfmt + stylua (lua)

# textlintのルールを入れ直す (miseのbun_args変更後)
mise install --force npm:textlint
zsh script/setup/setup_textlint.sh     # 共通設定と旧CLIリンクの移行

# VSCode拡張をextensions.txtと完全同期 (--dry-runで差分確認)
script/tools/sync_vscode_extensions.sh --dry-run
```

全体の検証はGitHub Actions (`ci-ubuntu.yml` / `ci-rocky.yml` / `ci-macos.yml`) がクリーンな環境で `install.sh` を実行し、symlinkと主要ツールの存在を確認する形で行われる。`ci-macos-packages.yml` は `mise bootstrap packages apply` (brew / brew-cask) の適用・冪等性・statusを、`ci-lint.yml` は `prek run --all-files` を検証する。

## アーキテクチャ

### symlink展開の対応関係

`install.sh` と `script/setup/setup_*.sh` が以下のように展開する。展開先を直接編集しても実体はこのリポジトリ内のファイルである。

| リポジトリ内                                                                                                                          | 展開先                                                                        |
| ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `config/dot/<name>`                                                                                                                   | `~/.<name>`                                                                   |
| `config/dot_config/<name>`                                                                                                            | `~/.config/<name>`                                                            |
| `config/dot_config/{herdr,hunk}/config.toml`, `config/dot_config/cli-proxy-api/config.yaml`, `config/dot_config/omniwm/settings.toml` | `~/.config/<name>/` 配下にファイル単位でsymlink (ディレクトリは実体)          |
| `config/dot_config/herdr/plugins/<plugin>`                                                                                            | `herdr plugin link` で登録 (symlinkではない。`setup_herdr.sh` が実行)         |
| `config/ai-agents/claude/{CLAUDE.md,settings.json,statusline.py,subagent_statusline.py}`                                              | `~/.claude/` 配下                                                             |
| `config/ai-agents/rules/*`                                                                                                            | `~/.claude/rules/`(Codexへは `codex-rules-hook.sh` が渡す)                    |
| `config/ai-agents/skills/<skill>`                                                                                                     | `~/.agents/skills/`, `~/.claude/skills/`, `~/.gemini/antigravity-cli/skills/` |
| `config/ai-agents/codex/hooks.json`                                                                                                   | `~/.codex/hooks.json`                                                         |
| `config/ai-agents/AGENTS_global.md`                                                                                                   | `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`                                   |
| `config/ai-agents/gemini/antigravity-cli/settings.json`                                                                               | `~/.gemini/antigravity-cli/settings.json`                                     |
| `config/ai-agents/apm.yml`                                                                                                            | `~/.apm/apm.yml`                                                              |
| `config/textlint/textlintrc.js`                                                                                                       | `~/.textlintrc.js` (CLIはmiseのPATH / shimから公開)                           |
| `config/mac/iterm2/DynamicProfiles/dotfiles.json` (macOS)                                                                             | `~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json`          |
| `config/mac/karabiner` (macOS)                                                                                                        | `~/.config/karabiner`                                                         |
| `config/{vscode,cursor}/{settings.json,keybindings.json}`                                                                             | 各アプリのUserディレクトリ (`extensions.txt` は展開されず参照専用)            |

上書き前の既存ファイルは `.backup/` に退避される。

### zsh起動ファイルの役割分担

| ファイル                      | 読まれるタイミング          | 置くもの                                                                                                                             |
| ----------------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `config/dot/zshenv`           | 全shell                     | 環境変数のみ。login shellを経由しない場合は `~/.zprofile` をsourceする (`__ZPROFILE_SOURCED`)                                        |
| `config/dot/zprofile`         | login時1回                  | PATHの組み立て、`brew shellenv`、非対話shell用の `mise activate --shims`                                                             |
| `config/dot/zshrc`            | 対話shell                   | p10k instant prompt、`mise activate`、`sheldon source`、`~/.zshrc.local`、`~/.config/zsh/profiles/*.zsh` (マシン固有設定、zsh-defer) |
| `config/dot_config/zsh/*.zsh` | sheldonがlocal pluginとして | options / completion (即時)、functions / aliases (zsh-defer)                                                                         |
| `config/dot_config/sheldon/`  | zshrcから1回                | サードパーティpluginと上記ファイルの読み込み順序・遅延指定                                                                           |
| `config/dot_config/mise/`     | tool解決時                  | toolとバージョン、postinstall、`[settings]`、task、macOSのbrewパッケージ・常駐サービス・設定の定義 (`bootstrap.*`)                   |

順序の制約 (zsh-completionsのfpath追加 → compinit、history設定は即時、syntax-highlightingは最後) は `plugins.toml` 冒頭のコメントにある。tool別の補完ファイル (`_mise`, `_docker`, `_kubectl`) は `script/setup/update_completions.sh` が `~/.config/zsh_completions/` に生成し、`.zcompdump` を削除して次回起動で再構築させる。

### AI agent設定の共有構造

- 共有skillとcode-reviewer agentはこのリポジトリでは管理せず、[mjun0812/skills](https://github.com/mjun0812/skills) の `main` をapmで購読する。購読定義は `config/ai-agents/apm.yml` (`~/.apm/apm.yml` へsymlink) にあり、`install.sh` が `apm update -g -y` を実行して展開する。
- MCPサーバーも `config/ai-agents/apm.yml` の `dependencies.mcp` で一元管理する。apmが各agentの設定 (`~/.claude.json` の `mcpServers`、`~/.codex/config.toml` の `[mcp_servers.*]`、`~/.gemini/config/mcp_config.json`) へ直接書き込むので、symlinkや `--mcp-config` は使わない。Codexのテンプレートには `[mcp_servers.*]` を書かない (apmの書き込みと二重管理になるため)。
- このリポジトリに残る私用skill (`mjun-*`) は `config/ai-agents/skills/` に一元管理され、`~/.agents/skills/`, `~/.claude/skills/`, `~/.gemini/antigravity-cli/skills/` の3箇所へsymlinkされる。Codexは `~/.agents/skills/` を直接読むため `~/.codex/skills/` には展開しない。1箇所の編集が全agentに反映される。
- skillの一覧と依存関係は `doc/skills.md` (英語) と `doc/skills_ja.md` に記載されている。skillを追加・変更したらここも更新する (`doc-sync` skillがこの同期を担う)。
- Codexの `~/.codex/config.toml` だけはsymlinkではなく、`script/setup/rewrite_config.py` (tomlkit) がテンプレート (`config/ai-agents/codex/config.toml`) 側のキーだけを既存ファイルへマージする方式。Codexが自動生成する `[projects.*]` や `[hooks.state]` などのローカル状態を温存するため。キーの上書きのみでキーの削除はできない点に注意。
- agent向けのrule(`config/ai-agents/rules/*.md`)は、Claude CodeとCodexで同じファイルを使う。Claude Codeは `~/.claude/rules/` のsymlinkからfrontmatterの `paths` を見て自分で読み込む。Codexには同じ機能が無いので、`script/hooks/codex-rules-hook.sh` が `apply_patch` の対象ファイルが `paths` に合うかを調べ、合うruleの本文をadditionalContextで渡す。同じsessionでは1回だけ渡し、PostCompactで記録を消す。frontmatterは、両方が同じ意味で読める書式に限る。書式は `script/tools/rule-paths.sh` が定義し、prekが確かめる。
- Codexのhookは `config/ai-agents/codex/hooks.json` で管理され、`~/.codex/hooks.json` へsymlinkされる。hook定義を変更すると `[hooks.state]` の `trusted_hash` が無効になり、TUIの `/hooks` で再承認が必要になる。
- agentが編集したファイルには、Claude Code・Codex共通のPostToolUse hookが2つかかる。編集されたファイルの取り出しは `script/hooks/edited-files.sh` で共通にしている。2つのhookは並列に起動される。
  - `script/hooks/format-hook.sh`: formatterと自動修正だけをかけ、指摘はagentへ返さない。Markdownには `textlint --fix` (`textlintrc.fix.json`: 全角括弧) をかけてから `oxfmt` を通す。
  - `script/hooks/report-hook.sh`: 今回変わった行(git追跡中ならHEADとの差分、それ以外は全行)にある、hookが自動では直さない指摘を、exit 2でagentへ返す。
    - Markdown: textlintの指摘(`textlintrc.report.json`)。ルールは `preset-ai-words-ja`、`@textlint-ja/preset-ai-writing`(`no-ai-list-formatting` と `no-ai-colon-continuation` を無効化)、`preset-ja-technical-writing`(`sentence-length` を無効化)、`no-kangxi-radicals`、英数字と日本語の間の空白(`ja-space-between-half-and-full-width`)、日本語と半角括弧の間の空白(`@textlint-rule/pattern`)。`.mjun/` 配下(mjun系skillのspec・tasks・brief)を対象から外している。tasksがspecのAcceptance Criteriaを文言のまま写すので、言い換えを促すと食い違うためである。
    - シェルスクリプト: shellcheckの指摘と、他の言語のコードを `-c`・`-e`・heredocでべた書きした行。zshのscriptはshellcheckが対応していないので、shellcheckだけ対象から外す。
  - textlintの設定と辞書は `config/textlint/` にあり、`script/tools/textlint.sh <fix|report>` 経由で実行する。`config/textlint/ignore-files.txt` に書いたファイル(global指示のCLAUDE.md・AGENTS_global.md)は、symlink経由で渡しても指摘と自動修正の対象から外れる。本体とルールはmiseの `npm:textlint` と `bun_args` で同じBun prefixに導入する。wrapperはdotfilesのディレクトリから `mise where npm:textlint` で解決し、呼び出し元projectの別バージョンを使わない。`--fix` で直せるルールはfix側、直せないルールはreport側に置く。ただし空白のルールは直せてもreport側に置く。fix側はファイル全体を書き換えるので、他のrepoの文書の既存の行まで一斉に変わるためである。
  - 人が手で使う `textlint` も同じ本体とルールを使う。CLIはmiseのPATH / shimから公開され、ルールは同じinstall先の `node_modules` から解決される。`setup_textlint.sh` はdotfilesが作った旧 `~/.local/bin/textlint` のsymlinkだけを撤去する。設定の `~/.textlintrc.js` (`textlintrc.js`) はfix側とreport側のルールをまとめたもので、textlintが設定をカレントディレクトリから親へ探すため、自前の設定を持たないホーム配下のディレクトリから実行したときだけ使われる (対象のファイルはホームの外でもよい)。`--config` には渡せない (rc-config-loaderが拡張子付きのJSをYAMLとして読む)。
- textlintの導入・更新手順とBun backendへの依存は `config/textlint/README.md` に記載する。ルールは `bun_args` の固定版を明示的に変更する。旧 `package.json` / `bun.lock` は使わず、推移依存の完全固定は行わない。
- `templates/` にはMarkdownのPDF出力用CSSと設定、`repo: local` のpre-commit設定テンプレート、agentsviewのリモートホスト定義 (`~/.agentsview/remotes.toml`) のplaceholderがある。PDF用ファイルはVS Code・Cursorの設定と `md-to-pdf` のaliasから参照される。commit・PR・Issue・レビュー用テンプレートは各skillに同梱される。

## 規約

- スクリプトはzsh (`#!/usr/bin/env zsh`)。pre-commitのshfmt (`-s -i 4`) が `.sh` はshebangからのzsh自動判定で、`.zsh` は `--ln=zsh` 指定でフォーマットする。ただし `p10k.zsh` (生成ファイル) は対象外。
- oxfmtの対象外ファイルは `.oxfmtrc.json` の `ignorePatterns` に定義されている (`config/ai-agents/claude/settings.json` など)。フォーマッタが壊す設定ファイルを追加する場合はここに登録する。
- `main` にはrulesetでレビュー必須が設定されているが、owner (mjun0812) はこれをbypassしてよい。PRは `gh pr merge --admin` でmergeし、軽微な変更は `main` へ直接commit・pushして構わない。
