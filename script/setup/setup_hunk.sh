#!/usr/bin/env bash
set -euo pipefail

# setup_hunk.sh
#
# hunk の managed extension (hunk-gh: `hunk gh pr <N>` で GitHub PR を開く) を
# install する。mise の postinstall (config/dot_config/mise/config.toml) から
# hunk の install / upgrade 時に呼ばれ、install.sh からも呼ばれる。
#
# `hunk extension install` は install 済みだと exit 1 で終了するため、
# `hunk extension list` で有無を確認してから install する。
# 実体は ~/.config/hunk/extensions/installed/<name>/ に clone される。

if hunk extension list 2>/dev/null | grep -q '^hunk-gh'; then
    echo "hunk-gh is already installed"
else
    hunk extension install modem-dev/hunk-gh --yes
fi

# hunk 同梱の agent skill (hunk-review) を各 agent の skills ディレクトリへ symlink する。
# リンク先はバージョン入りのパスだが、本スクリプトは hunk 更新時の postinstall でも
# 走るので、そのたびに新バージョンへ張り直される。
# フレッシュ環境の mise install 中は skills ディレクトリがまだ無いので mkdir -p する
# (install.sh 側の mkdir -p と同じディレクトリで衝突しない)。
skill_dir=$(dirname "$(hunk skill path)")
for skills_root in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.gemini/antigravity-cli/skills"; do
    mkdir -p "$skills_root"
    ln -snfv "$skill_dir" "$skills_root/hunk-review"
done
