#!/usr/bin/env bash
set -euo pipefail

# setup_herdr.sh
#
# herdrのagent-state hookスクリプトをClaude Code / Codexに設置し、
# dotfiles管理のherdr pluginをlinkする。
# miseのpostinstall (config/dot_config/mise/config.toml) からherdrの
# install / upgrade時に呼ばれる。手動で再実行してもよい。
#
# hookの登録エントリはdotfiles側 (config/ai-agents/claude/settings.json,
# config/ai-agents/codex/hooks.json) がOS非依存の~形式で所有する。
# herdrのinstallerは自分が書くquoted絶対パス形式のエントリしか
# 自エントリと認識せず、~形式が登録済みでも絶対パス形式のエントリを
# 重複追加するため、設置後にherdrが追記したエントリをjqで除去する。

DOTPATH=$(cd "$(dirname "$0")/../.." && pwd)

# フレッシュ環境のmise install中は~/.claudeがまだ無く、
# herdr integration installが失敗する。install.shがClaude Codeの
# 設定後に本スクリプトを再実行するので、その時点ではスキップしてよい。
# ~/.codexはinstall.shがmise installより前に作る (mise dot applyが
# config.tomlを書く) が、install.shを経ずにmiseから呼ばれたときのために同じく確かめる。
if [ -d "$HOME/.claude" ]; then
    herdr integration install claude
else
    echo "skip herdr integration install claude: $HOME/.claude not found"
fi
if [ -d "$HOME/.codex" ]; then
    herdr integration install codex
else
    echo "skip herdr integration install codex: $HOME/.codex not found"
fi

normalize() {
    # canonicalはdotfiles側が所有する~形式のcommandの接頭辞 (引数は含まない)。
    local file="$1" canonical="$2"
    [ -f "$file" ] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        # フレッシュ環境のmise install中はjqがPATHに無い場合がある。
        # その時点の実ファイルは後段のsetup_*.shでsymlinkに置き換わる
        # ため、正規化はスキップしてよい。
        return 0
    fi
    local tmp
    tmp="$(mktemp)"
    jq --arg canonical "$canonical" '
        .hooks |= with_entries(.value |= (
            map(.hooks |= map(select(
                (.command | test("herdr-agent-state\\.sh") | not)
                or (.command | startswith($canonical))
            )))
            | map(select(.hooks | length > 0))
        ))
    ' "$file" >"$tmp"
    # fileはdotfilesへのsymlinkなので、mvで置き換えず中身だけ書き戻す
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

# herdr plugin linkはherdr serverが古い (protocol mismatch) と失敗して
# set -eで終了するため、integration installの後始末である正規化を先に行う。
normalize "$HOME/.claude/settings.json" 'bash ~/.claude/hooks/herdr-agent-state.sh '
normalize "$HOME/.codex/hooks.json" 'bash ~/.codex/herdr-agent-state.sh '

# dotfiles管理のherdr pluginをすべてlinkする (linkは冪等)。
# 実体はconfig/dot_config/herdr/plugins/にあり、編集はそのまま反映される。
for plugin in "$DOTPATH"/config/dot_config/herdr/plugins/*/; do
    herdr plugin link "${plugin%/}"
done
