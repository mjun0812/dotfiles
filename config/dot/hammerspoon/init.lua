-- コマンドライン(`hs` CLI)からHammerspoonを操作できるようにIPCを有効化する。
-- これによりターミナルから `hs -c "hs.reload()"` 等でリロードや実行が可能になる。
require("hs.ipc")

-- 機能ごとのモジュールを読み込む。実装は各ファイルを参照。
require("claude-wezterm-focus") -- Claude Codeの通知クリックからWezTermのwindow/paneへ戻る
require("center-window") -- hammerspoon://center でフォーカス中のウィンドウを中央寄せ
require("aerospace-workspace-hud") -- hammerspoon://aerospace-workspace でworkspace番号をHUD表示
require("chrome-vertical-tab-toggle") -- Chromeの縦タブサイドバーをホットキー/マウスエッジでトグル
