#!/usr/bin/env zsh
# リポジトリの用語集 CONTEXT.md をagentのcontextに注入するSessionStart hook。
# repo直下の CONTEXT.md を優先し、無ければ .mjun/CONTEXT.md を使う。
# Claude Code・Codexとも、SessionStart hookのplain stdoutをそのままcontextに加える。

set -u

command -v jq >/dev/null 2>&1 || exit 0

cwd=$(jq -r '.cwd // ""')
[[ -n $cwd ]] || cwd=$PWD
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=$cwd

for glossary in "$root/CONTEXT.md" "$root/.mjun/CONTEXT.md"; do
    [[ -f $glossary ]] || continue
    print -r -- "このリポジトリの用語集 (${glossary#"$root"/}) です。ここで定義された語彙を使うこと。"
    print
    cat "$glossary"
    break
done

exit 0
