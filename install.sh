#!/usr/bin/env zsh

log_section() {
    print -P "%F{blue}%B==> %f%b%F{white}%B$1%f%b"
}

DOTPATH=$(cd $(dirname $0) && pwd)
CONFIG_DIR="$HOME/.config"
cd "$DOTPATH"

mkdir -p ${DOTPATH}/.backup
mkdir -p "$CONFIG_DIR"
mkdir -p "$HOME/.cargo"
mkdir -p "$HOME/.local/bin"

################ [mise] ################
log_section "Setting up mise..."
# 新しい環境ではまだ~/.zprofileが無く、miseの導入先がPATHに無い
export PATH="$HOME/.local/bin:$PATH"
$DOTPATH/script/setup/install_mise.sh

################ [dotfiles] ################
log_section "Setting up dotfiles..."
# miseが[dotfiles]の宣言 (conf.d/dotfiles.toml) を読めるように、~/.config/miseだけは先に手でlinkする
if [ -e "$CONFIG_DIR/mise" ] && [ ! -L "$CONFIG_DIR/mise" ]; then
    mkdir -p "$DOTPATH/.backup/.config"
    rm -rf "$DOTPATH/.backup/.config/mise"
    mv "$CONFIG_DIR/mise" "$DOTPATH/.backup/.config/mise"
fi
ln -snfv "$DOTPATH/config/dot_config/mise" "$CONFIG_DIR/mise"
# mise dot applyは展開先の実ファイルを置き換えずに止まるので、HOMEからの相対パスのまま.backup/へ移しておく
# jqはまだ入っていないことがあるので、mise xで呼ぶ
mise dot status --json |
    mise x jq -- jq -r '.files[] | select(.reason == "exists but is not a symlink") | .target' |
    while read -r target; do
        backup="$DOTPATH/.backup/${target#\~/}"
        mkdir -p "${backup:h}"
        rm -rf "$backup"
        mv "$HOME/${target#\~/}" "$backup"
    done
mise dot apply --yes

################ [mise tools] ################
log_section "Installing mise tools..."
source "$HOME/.zprofile"
mise install
mise reshim

log_section "Applying mise bootstrap..."
if [ "$(uname -s)" = "Darwin" ]; then
    if [ "${DOTFILES_SKIP_BOOTSTRAP_PACKAGES:-0}" != "1" ]; then
        mise bootstrap packages apply --yes
        mise bootstrap packages upgrade --yes
    fi
    # defaultsが指すディレクトリを先に作る
    mise bootstrap files apply --yes
    # appは書き換えた設定を次の起動時に読む
    mise bootstrap macos defaults apply --yes
    zsh "$DOTPATH/script/setup/setup_mozkey.sh"

    # install Homebrew if not installed (for macOS)
    if ! command -v brew >/dev/null 2>&1; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi
mise bootstrap services apply --yes
zsh "$DOTPATH/script/setup/setup_codex_daemon.sh" pin

################ [bat] ################
log_section "Setting up bat themes..."
bat cache --build

################ [Zsh Completion Update] ################
$DOTPATH/script/setup/update_completions.sh

################ [Zsh Plugin Warm-up] ################
log_section "Warming up zsh plugins..."
# sheldon plugin clone
zsh -i -c exit
# install powerlevel10k gitstatusd
sh "$HOME/.local/share/sheldon/repos/github.com/romkatv/powerlevel10k/gitstatus/install"

################ [Python] ################
log_section "Setting up Python..."
cd "$HOME"
uv venv --allow-existing
uv pip install -U \
    pip \
    setuptools \
    wheel \
    pymupdf \
    pynvim \
    PyYAML \
    'python-lsp-server[all]' \
    jupyterlab \
    jupyter-collaboration \
    jupyter-mcp-tools \
    jupytext \
    nbformat \
    nbclient \
    nbconvert \
    nbmake \
    ipykernel
"$HOME/.venv/bin/python" -m ipykernel install \
    --user \
    --name home-venv \
    --display-name "Python (~/.venv)"

cd "$DOTPATH"

################ [Neovim (background)] ################
log_section "Starting Neovim setup in the background..."
# 全処理でいちばん長いので、裏で走らせる。CPUを使うzsh pluginの取得やPythonの準備と重ねると、
# 3コアのmacOSのrunnerでそれらが進まなくなるので、それらが終わった後に始める。後続のAPMなども重なる間は遅くなるが、合計の時間は縮む
nvim_log=$(mktemp)
(
    # parserは明示的なinstallで1回だけ入れる。起動時の自動installと重なると、同じparserを二重にcompileする
    export NVIM_TS_AUTO_INSTALL=0
    nvim --headless "+Lazy! restore" +qa
    nvim --headless -c "lua require('nvim-treesitter').install(require('config.treesitter-langs'), { summary = true }):wait(600000)" +qa
) >"$nvim_log" 2>&1 &
nvim_pid=$!

################ [Node] ################
# macOS installs vp with mise bootstrap (brew:vite-plus)
if [ "$(uname -s)" != "Darwin" ]; then
    log_section "Setting up Vite plus..."
    $DOTPATH/script/setup/install_vp.sh || echo "vp install/upgrade failed (ignored)"
fi

################ [APM] ################
log_section "Setting up APM..."
apm update -g -y

################ [Claude Code] ################
log_section "Setting up Claude Code..."
zsh "$DOTPATH/script/setup/setup_claude_code.sh"

################ [pstack] ################
log_section "Setting up pstack..."
zsh "$DOTPATH/script/setup/setup_pstack.sh"

################ [herdr] ################
log_section "Setting up herdr..."
bash "$DOTPATH/script/setup/setup_herdr.sh"

################ [hunk] ################
log_section "Setting up hunk..."
bash "$DOTPATH/script/setup/setup_hunk.sh"

################ [rtk] ################
log_section "Setting up rtk..."
zsh "$DOTPATH/script/setup/setup_rtk.sh"

################ [Neovim (wait)] ################
log_section "Setting up Neovim plugins..."
wait $nvim_pid && nvim_status=0 || nvim_status=$?
if [ "$nvim_status" -eq 0 ]; then
    rm -f "$nvim_log"
else
    # 出力を全量は出さない。CIでは標準出力がnon-blockingのpipeになっていることがあり、
    # 約9,000行を一度に書くとEAGAINで失敗する
    tail -n 200 "$nvim_log"
    echo "Neovim setup failed (exit $nvim_status). Full log: $nvim_log"
fi
# 失敗は出力を表示した後に伝える。(exit)なら、zsh -eのときはここでscriptが止まり、
# -eなしでも、この行が最後なのでinstall.shの終了コードがNeovimの準備の終了状態になる
(exit $nvim_status)
