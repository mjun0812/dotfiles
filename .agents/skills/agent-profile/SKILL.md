---
name: agent-profile
description: Claude Code・Codexを別の設定ディレクトリで起動する実行方式(`claude-bare`・`claude-pstack` のようなprofile)を、このdotfilesへ足す・直すSkill。ユーザーが「〜だけ入れた実行方式を足して」「bareをもとに別のprofileを作って」「pstackのような検証用の環境を作って」と依頼したときや、既存のprofileの展開やinstallを直すときに使うこと。本体(`~/.claude`・`~/.codex`)の設定変更や、pluginの中身の変更には使わない。
---

# agent-profile

## 概要

profileは、本体の設定を読み込まずに何かを試すための、別の設定ディレクトリ(`~/.<agent>-<name>`)と、そこで起動するzsh関数(`<agent>-<name>`)の組である。見本は `claude-pstack`・`codex-pstack` で、`grep -rn pstack` に出る箇所(関数、展開の宣言、setup script、`install.sh`、CI、文書、整形の除外)が、足すときに触る場所のすべてである。

このskillには、repositoryを読んでも分からないことだけを書く。CLIの挙動と、実環境を壊さない確かめ方である。

## 作り方の方針

- **設定はbareのテンプレートを `merge = true` で展開する。** profile用の写しを置くと、bareを変えるたびに直す箇所が増える。profile固有のキーが要るときは、同じ展開先に2つ目のテンプレートをマージできる(宣言のキー `<展開先>/<名前>` の名前を変える)。
- **pluginの登録はテンプレートに書かず、`script/setup/setup_<name>.sh` のCLIに書かせる。** 登録だけあって本体が無い状態を作らないためである。展開先はマージで作った実ファイルなので、CLIが書き足した登録は次の `mise dot apply` でも残る。
- **bareとpstackに続く3つ目を足すときは、重なる部分(関数、宣言、setup)をまとめるかをユーザーに提案する。** 2つの時点では共通の形が見えず、汎用の仕組みを作っていない。

## 足すものについて先に調べること

入れるpluginやskillの中身を読み、次を確かめる。当てはまれば、実装の前にユーザーへ伝えて扱いを決める。pluginは、一時の設定ディレクトリへ入れると中身を読める。一時ディレクトリを1つ作って `CLAUDE_CONFIG_DIR` に指定し、`setup_pstack.sh` と同じ形の `claude plugin marketplace add` と `claude plugin install -s user` を実行すると、その下の `plugins/cache/` に本体が入る。

- **hookやMCPを同梱しているか(`hooks/`、`.mcp.json`)。** bareは、agentの動作を変えるhookとMCPを置かない設定である。同梱していれば「〜だけ足す」の意味が変わる。
- **`~/.claude/` を固定で読み書きする箇所があるか(本体を `~/.claude` や `.claude/` でgrepする)。** 設定を書くskillや会話の履歴を読むskillは、`CLAUDE_CONFIG_DIR` を見ずに本体のディレクトリを指すことがある。`~/.claude/rules` は本体のClaude Code・Codex・OpenCodeが共有するruleへのlinkなので、そこへ書く機能は使わせない。必要な設定はdotfilesに置き、`~/.<agent>-<name>/rules/` へlinkする。
- **Codexでどこまで動くか。** Claude Code向けのpluginは、Codexではskillだけが読まれ、subagentの定義は登録されない。ホームの `~/.agents/skills` のskillは関数で無効にできるが、Codexの組み込みskillと作業中のrepositoryの `.agents/skills` は残る。

## CLIの挙動

確かめた版は、claude 2.1.332、codex-cli 0.172.0、mise 2026.11.14である。版が進んでいたら、当てにする項目を確かめ直す。

| 事実                                                                                                                                                                                | 影響                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Codexは `CODEX_HOME` に関係なく `$HOME/.agents/skills` を読む。`--enable skip_host_skill_discovery` を付けても変わらず、`skills.include_instructions=false` はpluginのskillまで消す | 関数の中で `~/.agents/skills/*/SKILL.md(N)` を列挙し、`-c 'skills.config=[...]'` で起動のたびに無効にする(`codex-bare` が見本)。関数を通さない起動では無効にならない |
| `skills.config` の `{path="<パス>",enabled=false}` は、SKILL.mdのパスを書くとそのskillを無効にし、ディレクトリを書いても無効にならない。0件の `skills.config=[]` も受け付ける       | 1件ずつ並べる。`~/.agents` が無い環境でも同じ形で起動できる                                                                                                          |
| Codexは `CODEX_HOME` のディレクトリが無いと `failed to resolve CODEX_HOME` で失敗する                                                                                               | setup scriptで先に `mkdir -p` する                                                                                                                                   |
| Codexは、登録だけあって取得していないmarketplaceがあると `failed to load marketplace(s)` で失敗する                                                                                 | 登録をテンプレートに書かない                                                                                                                                         |
| Codexは `.claude-plugin/marketplace.json` のmarketplaceを読める                                                                                                                     | Claude Code向けのmarketplaceをそのまま `codex plugin marketplace add` に渡せる                                                                                       |
| `claude plugin marketplace add`、`claude plugin install -s user`、`codex plugin marketplace add`、`codex plugin add` は、繰り返しても成功する                                       | setup scriptに、入っているかの判定が要らない                                                                                                                         |
| pluginの本体は、どちらも設定ディレクトリの `plugins/cache/<marketplace>/<plugin>/<version>/` に入る                                                                                 | CIは、このディレクトリが在ることを確かめる                                                                                                                           |
| Claude Codeは `$CLAUDE_CONFIG_DIR` の `settings.json`・`rules/`・`skills/` を読み、ログインも設定ディレクトリごとに要る                                                             | profileに足すruleやmodは、設定ディレクトリの中へlinkする                                                                                                             |
| マージは、テンプレートからキーごと消した変更を展開先へ反映しない(配列の中身の変更は反映する)                                                                                        | bareからキーを消したときは、profileの展開先に残る                                                                                                                    |
| oxfmtは、Markdownの `#` で始まる行を見出しとして扱い、前後に空行を入れる                                                                                                            | pluginが書式を決めている `.md` は、`.oxfmtrc.json` と `.pre-commit-config.yaml` で除外する                                                                           |

## 確かめ方

実環境の `~/.claude*`・`~/.codex*` を作らず、変えない。確認はすべて一時ディレクトリで行い、`install.sh` は実行しない。

1. **展開**: 宣言と展開元のファイルを置いた後、確かめるcheckoutの中で `zsh .agents/skills/agent-profile/scripts/deploy_to_temp.sh '<pattern>'` を実行する。`<pattern>` は展開先に合わせる正規表現で、pstackなら `'\.(claude|codex)-pstack/'` である。合う宣言だけが一時ディレクトリへ展開され、そのパスが出力の最後の行になる(以下 `$T`)。`mise dot apply` を直接実行しない。展開先を引数に付け忘れると、実環境の宣言まで適用される。
2. **install**: `HOME=$T zsh script/setup/setup_<name>.sh` を2回実行し、どちらも終了コード0であることを見る。偽のHOMEでも実物のCLIが動き、ログインは要らない。
3. **入ったもの**: `CLAUDE_CONFIG_DIR=$T/.claude-<name> claude plugin list --json` と `CODEX_HOME=$T/.codex-<name> codex plugin list` で、入って有効になっていることを見る。
4. **Codexに見えるskill**: 目印のskillを `$T/.agents/skills/<目印>/SKILL.md` として置く。空のディレクトリで `HOME=$T zsh -c 'source <checkoutのroot>/config/dot_config/zsh/aliases.zsh; codex-<name> debug prompt-input hi'` を実行する。モデルに見えるpromptが出るので、読み込まれたskillが分かる。ログインは要らない。目印のskillが出ず、`### Skill roots` に `.agents/skills` で終わるrootが無ければ、ホームのskillを切り離せている。関数を通さずに `CODEX_HOME` だけを変えて実行すると、無効の指定が付かず、確かめたことにならない。
5. **関数**: `claude` と `codex` を、環境変数と引数を出力するだけの偽物に差し替えて `aliases.zsh` を読み込み、関数を呼ぶ。
6. **マージとの両立**: 展開の後にinstallを行い、もう一度 `deploy_to_temp.sh '<pattern>' $T` を実行する。`all edits are applied` と出れば、installがbareのキーを消していない。

Claude Codeに読み込まれるskillとruleは、sessionを起動しないと見られない。モデルを呼ぶ確認(`claude -p` など)とログインは、実行する前にユーザーへ確認する。環境にAPIキーがあると、ログインしていなくても実行できて課金される。確認が取れなければ、人間が確かめる項目として報告に残す。

## よくある間違い

- 偽のHOMEへmiseの設定をlinkして `mise dot apply` を全体に実行する。偽のHOMEでのmiseの挙動は確かめておらず、全部の宣言を展開することになる。同梱のscriptを使う。
- bareのテンプレートを写したprofile用の `settings.json` や `config.toml` を置く。
- profileを足したのに、`AGENTS.md` のmodの展開先と `doc/ai-agents.md` のログインの表を直し忘れる。
