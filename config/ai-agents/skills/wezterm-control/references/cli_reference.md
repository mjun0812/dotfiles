# wezterm cli リファレンス

`wezterm 20260607-082427-8afe0ad3` の `--help` 出力から作成した実機確認済みリファレンス。
ここに無いサブコマンドやオプションを推測で使わないこと。不明な場合は `wezterm cli <subcommand> --help` で確認する。

共通事項:

- `--pane-id` を省略すると環境変数 `WEZTERM_PANE` (=呼び出し元のpane) が対象になる。
- `wezterm cli list --format json` の各要素は `window_id` / `tab_id` / `pane_id` / `workspace` / `title` / `cwd` / `size` などを持つ。

## サブコマンド一覧

### 状態の取得

| コマンド   | 用途                          | 主なオプション                                                                                                      |
| ---------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `list`     | window/tab/paneの一覧とID取得 | `--format <table\|json>` (default: table)                                                                           |
| `get-text` | paneの表示内容をstdoutへ出力  | `--pane-id`, `--start-line <N>`, `--end-line <N>` (0が画面先頭、負数でscrollbackを遡る), `--escapes` (装飾を含める) |

### paneの作成・削除・移動

| コマンド               | 用途                                                         | 主なオプション                                                                                                                                                                                                                              |
| ---------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `split-pane`           | paneを分割。新しいpane-idをstdoutへ出力                      | `--pane-id`, `--left`/`--right`/`--top`/`--bottom` (default: `--bottom`), `--percent <N>`, `--cells <N>`, `--cwd`, `--top-level` (window全体を分割), `--move-pane-id <ID>` (新規spawnせず既存paneを移動), 末尾 `-- PROG` で起動コマンド指定 |
| `spawn`                | 新しいtabまたはwindowでコマンドを起動。pane-idをstdoutへ出力 | `--window-id`, `--new-window`, `--cwd`, `--workspace <NAME>` (要 `--new-window`), 末尾 `-- PROG`                                                                                                                                            |
| `move-pane-to-new-tab` | paneを新しいtabへ移動                                        | `--pane-id`, `--window-id`, `--new-window`, `--workspace <NAME>`                                                                                                                                                                            |
| `kill-pane`            | paneを終了                                                   | `--pane-id`                                                                                                                                                                                                                                 |

### フォーカス・レイアウト

| コマンド                  | 用途                 | 主なオプション                                                                                           |
| ------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------- |
| `activate-pane`           | paneへフォーカス     | `--pane-id`                                                                                              |
| `activate-pane-direction` | 隣接paneへフォーカス | 引数: `Up`/`Down`/`Left`/`Right`/`Next`/`Prev`                                                           |
| `get-pane-direction`      | 隣接paneのIDを取得   | 引数: 方向 (同上)                                                                                        |
| `activate-tab`            | tabを切り替え        | `--tab-id`, `--tab-index <N>` (0始まり、負数で右端から), `--tab-relative <N>` (±で相対移動), `--no-wrap` |
| `adjust-pane-size`        | paneをリサイズ       | 引数: 方向 (`Up`/`Down`/`Left`/`Right`/`Next`/`Prev`), `--amount <N>` (default: 1)                       |
| `zoom-pane`               | paneのzoom切替       | `--pane-id`, `--zoom`/`--unzoom`/`--toggle`                                                              |

### 入力・タイトル

| コマンド           | 用途                         | 主なオプション                                                                         |
| ------------------ | ---------------------------- | -------------------------------------------------------------------------------------- |
| `send-text`        | paneへテキストをペースト送信 | `--pane-id`, `--no-paste` (bracketed pasteを使わず直接送信)。TEXT省略時はstdinから読む |
| `set-tab-title`    | tabのタイトルを変更          | 引数: TITLE, `--tab-id`                                                                |
| `set-window-title` | windowのタイトルを変更       | 引数: TITLE                                                                            |
| `rename-workspace` | workspaceをリネーム          | 引数: OLD NEW                                                                          |
