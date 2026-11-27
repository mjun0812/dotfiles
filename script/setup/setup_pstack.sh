#!/usr/bin/env zsh
# pstack (cursor/pluginsのplugin) を、claude-pstack・codex-pstack関数が使う設定ディレクトリへ入れて有効にする。
# どのコマンドも入れ済みの状態で繰り返して成功するので、入っているかを判定せずに毎回実行する。
# 入れた版のまま使い、更新はしない (更新の手順はdoc/ai-agents.md)。

export CLAUDE_CONFIG_DIR="$HOME/.claude-pstack"
claude plugin marketplace add cursor/plugins
claude plugin install pstack@cursor-plugins -s user

# Codexは、CODEX_HOMEのディレクトリが無いと起動できない
export CODEX_HOME="$HOME/.codex-pstack"
mkdir -p "$CODEX_HOME"
codex plugin marketplace add cursor/plugins
codex plugin add pstack@cursor-plugins
