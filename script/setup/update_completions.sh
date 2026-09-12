#!/usr/bin/env zsh

COMPLETIONS_DIR="$HOME/.config/zsh_completions"
# 旧構成ではdotfiles内へのsymlinkだった。実ディレクトリに置き換える
# (宙吊りsymlinkをmkdir -pが辿ってrepo内にディレクトリを再生成するのを防ぐ)
[ -L "$COMPLETIONS_DIR" ] && rm -f "$COMPLETIONS_DIR"
mkdir -p "$COMPLETIONS_DIR"

print -P "%F{blue}%B==> %f%b%F{white}%BUpdating zsh completions...%f%b"

if command -v kubectl >/dev/null 2>&1; then
    kubectl completion zsh >"$COMPLETIONS_DIR/_kubectl"
    echo "Updated: _kubectl ($(kubectl version --client -o json 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])' 2>/dev/null || echo 'unknown version'))"
fi

if command -v docker >/dev/null 2>&1; then
    docker completion zsh >"$COMPLETIONS_DIR/_docker"
    echo "Updated: _docker ($(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'unknown version'))"
fi

# 生成されるのは `mise __complete_word__` を呼ぶ薄いwrapperで、subcommand一覧は実行時にmise本体から取得される。
# そのためmiseを更新しても再生成は不要
if command -v mise >/dev/null 2>&1; then
    mise completion zsh >"$COMPLETIONS_DIR/_mise"
    echo "Updated: _mise ($(mise --version 2>/dev/null | head -1))"
fi

# compinit -C は24時間以内の .zcompdump をそのまま使うため、新しい補完ファイルを認識させるには削除して再構築させる
rm -f "${ZDOTDIR:-$HOME}/.zcompdump"(N) "${ZDOTDIR:-$HOME}/.zcompdump.zwc"(N)
