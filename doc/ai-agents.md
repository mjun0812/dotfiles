# AI agentの初期設定

dotfilesを展開した後、使うagentの認証を端末ごとに済ませる。OpenCode 2の設定、専用のglobal指示、hookを呼ぶplugin `shared-hooks` は `mise dot apply` が配置し、rtkのplugin `rtk.ts` は `script/setup/setup_rtk.sh` が置く。共有skillとMCPサーバーはAPMが配置する。APIキーは利用するproviderの分だけ用意する。

## ログイン

| 利用方法    | 初回に行う操作                                                                                                                                                                                                                         |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenCode 2  | `opencode auth login anthropic` または `opencode auth login openai` を実行し、使いたい認証方式を選ぶ。登録後は `opencode auth list` で確認する。                                                                                       |
| Claude Code | `claude auth login` でログインする。別設定の `claude-bare` と `claude-pstack` も使う場合は、それぞれ `claude-bare auth login` と `claude-pstack auth login` を実行する。                                                               |
| Codex       | `codex login` でログインする。`codex-bare` と `codex-pstack` は設定ディレクトリが別なので、使う場合は `codex-bare login` と `codex-pstack login` も実行する。hookを追加・変更した後は、使用する設定のTUIで `/hooks` を開いて承認する。 |

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

## pstackだけを入れた設定

`claude-pstack`・`codex-pstack` は、`claude-bare`・`codex-bare` の設定にpstack(cursor/pluginsが配布するplugin)だけを足した設定ディレクトリ(`~/.claude-pstack`・`~/.codex-pstack`)で起動する。どちらも、本体のskillやglobal指示を読み込まずにpstackを使える。Codexで残るskillと、ホームのskillを無効にできる条件は「Codexでの制限」に書く。`/pstack:poteto-mode` から使い始める。pstackは `install.sh` が入れる。入っていなければ `~/.dotfiles/script/setup/setup_pstack.sh` を実行する。

### Codexでの制限

Codexでは、pstackを公式の対応なしで使う。Claude Code向けのpluginをそのまま読み込むので、skillは `pstack:<name>` として読まれるが、subagentの `poteto-agent` と `comment-sicko` は使えない。

Codexは `CODEX_HOME` に関係なく、ホームの `~/.agents/skills` にあるskillを読み込む。そこで `codex-bare`・`codex-pstack` 関数は、起動のたびに `~/.agents/skills/*/SKILL.md` を列挙し、`-c 'skills.config=[{path="<SKILL.mdのパス>",enabled=false},...]'` で1件ずつ無効にしてCodexへ渡す。起動時に列挙するので、共有skillやmjun系のskillが増減しても追従する。Codexの組み込みskill、pluginのskill、作業中のrepositoryの `.agents/skills` は読み込まれたままである。

この指定は関数が付けるので、`CODEX_HOME=~/.codex-pstack codex` のように関数を通さずに起動すると付かず、`~/.agents/skills` のskillも読み込まれる。また、無効になることを確かめたのは `codex debug prompt-input` が出すpromptまでである。TUIで起動した実際のsessionと、常駐プロセス(`daemon_auto_start`)が先に動いている場合でも無効になるかは確かめていない。

### モデル設定

pstackが役割ごとに使うモデルは、`config/ai-agents/claude-pstack/pstack-models.md` を編集して変える。このファイルは `~/.claude-pstack/rules/pstack-models.md` へlinkされ、pstackの既定と同じ内容になっている。`/pstack:setup-pstack` は使わない。このskillは、本体のClaude Code・Codex・OpenCodeが共有する `~/.claude/rules/` へモデル設定を書くからである。

### 更新

pstackは自動では更新されず、入れた版のまま使う。更新するときは、Claude Code・Codexのそれぞれで、marketplaceを取得し直してからpluginを更新する。

```sh
claude-pstack plugin marketplace update cursor-plugins
claude-pstack plugin update pstack@cursor-plugins

codex-pstack plugin marketplace upgrade
codex-pstack plugin add pstack@cursor-plugins
```

更新した後は、`pstack-models.md` を新しい版の既定へ合わせ直す。上流では `/setup-pstack` の再実行が古い既定を置き換えるが、この設定では使わないので手で直す。見比べる先は、`~/.claude-pstack/plugins/cache/cursor-plugins/pstack/<version>/` にある `skills/setup-pstack/SKILL.md`(手順5の既定値)と `docs/harness/claude-code.md`(Claude Code向けのモデル名の読み替え)である。

### 本体の `~/.claude/` を読み書きするskill

pstackのskillの一部は、この設定で起動しても本体の `~/.claude/` を読み書きする。pstackのClaude Code向けの読み替え表が、設定ディレクトリを `~/.claude/` と固定で書いているためである。`/pstack:recall` と `/pstack:automate-me` は本体の会話の履歴(`~/.claude/projects/`)を読み、`/pstack:automate-me` は個人のskillを `~/.claude/skills/` へ書くことがある。
