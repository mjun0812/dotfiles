#!/usr/bin/env bash
set -euo pipefail

# setup_herdr.sh
#
# herdr の agent-state hook スクリプトを Claude Code / Codex に設置し、
# バイナリ同梱の agent skill を dotfiles に取り込み、
# dotfiles 管理の herdr plugin を link する。
# mise の postinstall (config/dot_config/mise/config.toml) から herdr の
# install / upgrade 時に呼ばれる。手動で再実行してもよい。
#
# hook の登録エントリは dotfiles 側 (config/ai-agents/claude/settings.json,
# config/ai-agents/codex/hooks.json) が OS 非依存の ~ 形式で所有する。
# herdr の installer は自分が書く quoted 絶対パス形式のエントリしか
# 自エントリと認識せず、~ 形式が登録済みでも絶対パス形式のエントリを
# 重複追加するため、設置後に herdr が追記したエントリを jq で除去する。

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

herdr integration install claude
herdr integration install codex

# dotfiles 管理の herdr plugin をすべて link する (link は冪等)。
# 実体は config/dot_config/herdr/plugins/ にあり、編集はそのまま反映される。
for plugin in "$DOTPATH"/config/dot_config/herdr/plugins/*/; do
    herdr plugin link "${plugin%/}"
done

# skill はバイナリ同梱版 (インストール済みバージョンと一致) を dotfiles 側に
# 生成する。herdr の更新で内容が変わると git diff に現れるので commit する。
# 各 agent への配布は既存の skill symlink 機構 (install.sh / setup_*.sh) が担う。
mkdir -p "$DOTPATH/config/ai-agents/skills/herdr"
herdr --skill >"$DOTPATH/config/ai-agents/skills/herdr/SKILL.md"

normalize() {
    local file="$1" canonical="$2"
    [ -f "$file" ] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        # フレッシュ環境の mise install 中は jq が PATH に無い場合がある。
        # その時点の実ファイルは後段の setup_*.sh で symlink に置き換わる
        # ため、正規化はスキップしてよい。
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    jq --arg canonical "$canonical" '
        .hooks.SessionStart |= (
            map(.hooks |= map(select(
                (.command | test("herdr-agent-state\\.sh") | not)
                or .command == $canonical
            )))
            | map(select(.hooks | length > 0))
        )
    ' "$file" >"$tmp"
    # file は dotfiles への symlink なので、mv で置き換えず中身だけ書き戻す
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

normalize "$HOME/.claude/settings.json" 'bash ~/.claude/hooks/herdr-agent-state.sh session'
normalize "$HOME/.codex/hooks.json" 'bash ~/.codex/herdr-agent-state.sh session'
