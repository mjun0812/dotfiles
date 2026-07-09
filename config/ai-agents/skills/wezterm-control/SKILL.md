---
name: wezterm-control
description: >-
  weztermのpane・tab・windowを `wezterm cli` で操作するskill。paneの分割・フォーカス移動・リサイズ・zoom・close、
  tab/windowの作成・切替・リネーム、paneの表示内容の読み取り、paneへのコマンド送信と実行結果の確認を行う。
  ユーザーが「weztermのpaneを分割して」「weztermの別paneでコマンドを実行して」のように、weztermと明示して依頼したときだけ使うこと。
  ユーザーはtmuxも併用しているため、「paneを分割して」のようにweztermと明示されていないpane/tab操作の依頼では使わない (どちらを指すかユーザーに確認する)。
  tmuxの操作、およびwezterm自体の設定 (wezterm.luaやkeybinding) の変更にも使わない。
---

# wezterm-control

## Objective

このSkillは、weztermのpane・tab・windowを `wezterm cli` サブコマンドで操作するためのものです。
tmuxの知識で代用せず、必ず [cli_reference.md サブコマンド一覧](references/cli_reference.md#サブコマンド一覧) にある実機確認済みのコマンドだけを使ってください。

## Rules

ユーザーが明示的に上書きしない限り、必ず次を守ってください。

1. 操作の前に必ず `wezterm cli list --format json` で現在のwindow/tab/pane構成とIDを取得すること。
2. すべての操作で `--pane-id` や `--tab-id` を明示すること。ID省略時は環境変数 `WEZTERM_PANE` (=自分が動いているpane) が対象になり、意図しないpaneを操作する事故につながる。
3. ユーザーが依頼した操作だけを行うこと。依頼されていないpaneのclose・フォーカス移動・レイアウト変更をしない。
4. 他のpaneへ送るコマンドは非破壊なものに限ること。削除・強制終了・push・デプロイなどの破壊的コマンドを送る前はユーザーに確認する。
5. `kill-pane` の対象は、このセッションで自分が作成したpaneに限ること。それ以外のpaneを閉じる場合は事前にユーザーへ確認する。
6. コマンド送信後は即座に結果を判断せず、待ってから `get-text` で出力を検証すること。

## Steps

0. `wezterm cli list --format json` を実行し、失敗する場合 (`wezterm` コマンドが無い、weztermが起動していない、mux serverに接続できない) は操作を続けず、その旨をユーザーに報告して終了する。
1. 手順0で取得した構成から対象のIDを決める。ユーザーの指示 (「右のpane」「2番目のtab」など) とtitle・cwd・位置情報を突き合わせる。曖昧なら候補を提示して確認する。
2. 対象IDを明示して操作を実行する。`split-pane` と `spawn` は新しいpane-idをstdoutへ出力するので、後続の操作のために保持する。
3. 操作結果を検証する。レイアウト変更は `list` で、コマンド実行は `get-text` で確認する。
4. 実行した操作と、作成・操作したpane-id/tab-idをユーザーに報告する。

## Key Patterns

### paneでコマンドを実行する

`send-text` はペースト相当であり、改行を送らないとコマンドは実行されない。
また、bracketed paste modeが有効なpaneでは改行もペースト扱いになり実行されないため、必ず `--no-paste` を付けて末尾に改行を含める。

```bash
wezterm cli send-text --pane-id <ID> --no-paste $'ls -la\n'
```

### 実行結果を読み取る

`get-text` は指定しなければ現在の画面表示のみを返す。過去の出力が必要な場合は負の行番号でscrollbackを遡る。

```bash
wezterm cli get-text --pane-id <ID> --start-line -1000
```

### 長時間コマンドの完了を検知する

コマンド末尾にmarkerを付けて送信し、`get-text` の出力にmarkerが現れるまで数秒間隔でpollingする。

```bash
wezterm cli send-text --pane-id <ID> --no-paste $'make build; echo __WEZTERM_DONE_$?__\n'
```

marker (`__WEZTERM_DONE_0__` など) から終了コードも判定できる。

## 最終チェックと返答

最後の返答前に次を確認する:

- 実行した操作がすべてユーザーの依頼に対応している
- 作成したpaneやtabのIDを報告に含めている
- コマンド送信を行った場合、`get-text` による検証結果を報告に含めている
