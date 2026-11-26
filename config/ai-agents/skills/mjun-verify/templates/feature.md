# 機能ファイルの形

機能ファイルは、H1と機能の説明1段落の後に、次の4つのH2をこの順で持つ。実装の詳細は書かず、ユーザーの操作、変わりにくい手がかり、必要な状態、コマンド、観察できる結果だけを書く。

```markdown
# <機能名>

<ユーザーから見て、この機能で何ができるかを1段落で>

## 小機能

- `<短いID>`: <振る舞いを1行で>

## 到達方法

- <ユーザーがこの機能に届く方法。UI、キーボード、CLI、APIのうち当てはまるものをすべて、1行ずつ>

## 操作と結果

前提:

- <この機能を操作する前に成り立っている状態>

- **<操作の名前>**: <ユーザーの操作>。`<そのまま実行できるコマンド>` を実行する。<観察できる結果>
- **証明**: <残す証拠と、取得するコマンド。証拠が何を示していれば、この機能が動いていると言えるか>

## 注意点

- <検証を無駄にする、または無効にする条件>
```

## 例

```markdown
# メモの検索

タイトルか本文に含まれる語でメモを探し、一致が無い場合と区別できる。

## 小機能

- `search-match`: タイトルと本文の一致を返し、メモのデータを変えない
- `search-empty`: 一致が無い語では、空の結果を返す
- `search-cli`: terminalから同じ結果を返す

## 到達方法

- web UIの `Search memos` 入力欄に語を入れる
- terminalで `memo search <query>` を実行する
- `GET /api/memos?q=<query>` を呼ぶ

## 操作と結果

前提:

- 検証手順の「起動」が済み、状態確認が通っている
- データの置き場に、タイトル `Quarterly plan`、本文 `Draft budget` のメモがある

- **本文の一致**: 入力欄に `budget` を入れる。`agent-browser --session verify fill 'input[aria-label="Search memos"]' budget` を実行する。一覧に `Quarterly plan` だけが出る
- **一致なし**: 入力欄に `volcano` を入れる。同じコマンドを `volcano` で実行する。一覧が空になる
- **CLIの一致**: `memo search budget --json` を実行する。終了コードが0で、標準出力がタイトル `Quarterly plan` のobject 1件を含む配列になる
- **証明**: `agent-browser --session verify screenshot .mjun/evidence/<run>/search-budget.png` と、CLIの出力を `.mjun/evidence/<run>/search-cli.txt` に残す。どちらも、語 `budget` と `Quarterly plan` を含む

## 注意点

- 一覧は入力のたびに取り直す。固定のsleepではなく、一覧の内容が変わるのを待つ
- CLIの既定の出力は人間向けである。判定には `--json` を使う
```
