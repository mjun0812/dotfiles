# AI agentの初期設定

dotfilesを展開した後、使うagentの認証を端末ごとに済ませる。OpenCode 2の設定、専用のglobal指示、hookを呼ぶplugin `shared-hooks` は `mise dot apply` が配置し、rtkのplugin `rtk.ts` は `script/setup/setup_rtk.sh` が置く。共有skillとMCPサーバーはAPMが配置する。APIキーは利用するproviderの分だけ用意する。

## ログイン

| 利用方法    | 初回に行う操作                                                                                                                                                                               |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenCode 2  | `opencode auth login anthropic` または `opencode auth login openai` を実行し、使いたい認証方式を選ぶ。登録後は `opencode auth list` で確認する。                                             |
| Claude Code | `claude auth login` でログインする。別設定の `claude-bare` も使う場合は `claude-bare auth login` を実行する。                                                                                |
| Codex       | `codex login` でログインする。`codex-bare` は設定ディレクトリが別なので、使う場合は `codex-bare login` も実行する。hookを追加・変更した後は、使用する設定のTUIで `/hooks` を開いて承認する。 |

## APIキーを環境変数で渡す場合

端末固有の設定は `~/.zshrc.local` に書く。次のうち使う行だけを追加し、引用符の中を自分のキーに置き換える。反映するには新しいターミナルを開く。

```sh
export ANTHROPIC_API_KEY='Anthropic Consoleで発行したAPIキー'
export OPENAI_API_KEY='OpenAI APIで発行したAPIキー'
```

APIキーでの利用は、そのキーを発行したAPIアカウントに計上される。新しいターミナルから `opencode --standalone` を起動すると、そのシェルの環境を引き継いだ専用サーバーで確認できる。

### claudexでローカルのCLIProxyAPIを使う場合

`claudex` は接続先を `127.0.0.1:8317` に設定し、`CLIPROXY_API_KEY` を `ANTHROPIC_AUTH_TOKEN` としてClaude Codeに渡す。プロキシ側でクライアント認証を有効にした場合だけ、対応するキーをローカル設定に追加する。

```sh
export CLIPROXY_API_KEY='ローカルプロキシのクライアントキー'
```

同梱のプロキシ設定は `api-keys: []` である。プロキシから上流へのログイン手順と、キーを設定する場合の設定ファイルの置き場所は[CLIProxyAPIの設定](macOS.md#cliproxyapi-configuration)を参照する。

## OpenCode 2の確認

- `opencode models` でモデル一覧を確認する。利用を許可するproviderとシェル権限は[opencode.jsonc](../config/ai-agents/opencode/opencode.jsonc)にある。
- 共有skillやMCPを更新するには `apm update -g -y` を実行する。配布対象は[共有skill一覧](skills_ja.md)を参照する。
- `opencode plugin list` で `mjun.shared-hooks` が出ることを確認する。出なければ `mise dot apply` を実行してOpenCodeを再起動する。
- `rtk init -g --show` で `OpenCode` の行が `[ok]` になっていることを確認する。`[--]` なら `~/.dotfiles/script/setup/setup_rtk.sh` を実行してOpenCodeを再起動する。
- `herdr integration status` で `opencode` の行を確認する。`needs repair` と表示されるのは、OpenCode 1用の `tui.jsonc` を `script/setup/setup_herdr.sh` が消しているためで、OpenCode 2の連携は動く。`not installed` なら `~/.dotfiles/script/setup/setup_herdr.sh` を実行してOpenCodeを再起動する。
