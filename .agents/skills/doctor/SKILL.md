---
name: doctor
description: dotfilesの更新にlocal環境を追従させるため、必要な手動作業を見つけて実施するSkill。ユーザーが「dotfilesの更新をlocalに反映して」「手動でやる作業があればやって」「doctorして」「環境が壊れていないか見て」と依頼したときや、install.shを流さずにpullした後に使うこと。dotfiles自体の機能追加や修正には使わない。
---

# doctor

## 概要

`script/tools/doctor.py` が機械的に分かるずれを列挙し、agentが原因を調べて直す。scriptが検出できない作業は、前回の確認以降のcommitから拾う。

## 手順

1. `python3 script/tools/doctor.py` を実行する。
2. 出力の「変更されたファイル」を下の表に当て、scriptが検出しない作業を拾う。表に無いファイルは、そのcommitの差分を読んで必要な作業を判断する。
3. ずれとcommitから拾った作業を一覧にし、原因を調べてから「判断の基準」に従って直す。
4. もう一度 `python3 script/tools/doctor.py` を実行する。残った指摘が、ユーザーに頼む作業か報告だけにする項目になったことを確かめる。
5. commitから拾った作業をすべて実施するか最終報告に書いたら、`python3 script/tools/doctor.py mark` で確認したcommitを記録する。

## 変更ファイルと作業

| 変わったファイル                                         | 作業                                                                                                                                |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `config/dot_config/mise/config*.toml`                    | `mise install`。`npm:textlint` の `bun_args` が変わったときは `mise install --force npm:textlint` (versionが同じだと入れ直されない) |
| `script/setup/install_mise.sh`                           | `zsh script/setup/install_mise.sh`                                                                                                  |
| `config/ai-agents/apm.yml`、`script/setup/setup_hunk.sh` | ホームで `apm update -g -y`                                                                                                         |
| `config/ai-agents/codex/hooks.json`                      | Codexの `/hooks` での再承認をユーザーに頼む。定義を変えたhookの承認切れはscriptでは検出できない                                     |
| `config/ai-agents/codex/config.toml`                     | `zsh script/setup/setup_codex.sh`                                                                                                   |
| `script/setup/setup_*.sh`                                | 変わったscriptを再実行する                                                                                                          |
| `install.sh`                                             | 変わった節のコマンドだけを手で実行する                                                                                              |
| `config/mac/`、`config.macos.toml`                       | macOSでだけ作業する                                                                                                                 |

## 判断の基準

- ファイルを削除しない。`~/.dotfiles/.backup/` へ `mv` し、名前で元の場所が分かるようにする(例: `.backup/codex_agents_stale/`)。リンク切れのsymlinkは、参照先の一覧を `.backup/` に書いてから `unlink` する。
- `apm-unmanaged` のファイルは、`~/.apm/apm_modules/` の取得元と差分を取る。取得元より古いだけなら退避してapmに入れ直させる。取得元に無い記述があれば、ユーザーに確認する。
- 外部ツールの挙動変更による失敗(例: apmの新版が展開先を拒否する)は、引数やtargetを絞ってlocalで回避する。原因と回避方法は報告する。repoを変える直し方(版の固定、install.shの変更)は提案にとどめ、ユーザーの指示を待つ。
- `codex-stale-key` は、キーを消したcommitの意図を読んでから消す。意図が読み取れなければユーザーに確認する。
- Codexの `/hooks` やブラウザでのログインのように、対話の画面でしかできない作業はユーザーに頼む。
- `install.sh` 全体は実行しない。既存の環境を上書きするため。
- ドキュメント(`CLAUDE.md`、`README.md`)と実態のずれは直さず、最終報告に書く。

## 最終報告

次の4節で報告する。該当が無い節は「なし」と書く。

1. 実施したこと: 項目、状態、対応、退避先
2. ユーザーに頼む作業
3. 未解決(報告のみ): 原因と、repo側の直し方の案
4. ドキュメントと実態のずれ
