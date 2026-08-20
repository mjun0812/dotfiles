# Offline環境での利用

インターネットから隔離された環境 (例: offline運用のコンテナ) でこのdotfilesを使う場合の注意点。

## 前提

network接続がある段階 (例: Docker Imageのbuild時) で `install.sh` を実行し、成果物を焼き込む構成を想定している。`install.sh` はmise tools・Neovimのplugin / treesitter parser / LSP server・uv venv・zsh plugin (sheldon・fzf binary・p10kのgitstatusd) までを一括でdownloadする。

## 注意点

### lazy.nvimのcheckerはruntimeでnetworkへアクセスする

`config/dot_config/nvim/lua/config/lazy.lua` の `checker = { enabled = true }` により、nvim起動のたびにpluginの更新チェックが走る。offline環境では失敗するが、`notify = false` のためエラー表示はなく実害は小さい。気になる場合はoffline環境側で `checker.enabled = false` にする。

### install.shはofflineで再実行できない

以下がnetwork前提のため、隔離環境内での `install.sh` 再実行 (設定の反映し直し) はできない。

- `script/setup/install_mise.sh` はmiseがinstall済みでも `mise self-update` と `mise up` を実行する
- `setup_claude_code.sh` のplugin marketplace更新、`install_vp.sh`、uvのpackage取得などもnetworkに接続する

設定を変更した場合は、networkのある環境でImageをbuildし直すこと。symlinkの張り直しだけであれば、該当セクションのコマンドを個別に実行する余地はある。
