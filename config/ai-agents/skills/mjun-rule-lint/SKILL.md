---
name: mjun-rule-lint
description: >-
  CLAUDE.md・steering・ADR・レビュー指摘・会話などに文章で書かれたコード規約を、repositoryに含めないlocalのlint (`.mjun/lint/` のast-grep ruleとscript) に変換し、作成済みのlintを直したり消したりするSkill。
  ユーザーが「規約をlintにして」「何度も指摘していることを自動チェックにして」「このlintを直して」のように依頼したら使うこと。
  repositoryのlinter設定・git hook・CIにlintを足す依頼には使わない (通常の作業としてmjun-startが扱う)。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(ast-grep:*), Bash(sg:*), Bash(git:*), Bash(zsh:*), Bash(ls:*), Bash(cat:*), Bash(mkdir:*), Bash(mktemp:*), Bash(rm:*)
---

# mjun-rule-lint

文章の規約は、読まれずに破られる。lintにすれば、agentは作業のたびに違反を知る。ただし、他人のrepositoryや、まだチームで合意していない規約のlintをrepositoryへ入れると、他の人の開発環境とCIを変えてしまう。このskillは、自分のagentの作業だけで守らせるlintを、repositoryの外 (`.mjun/lint/`、Git管理外) に作って管理する。

lintを実行するのはmjun系skillである。mjun-implementの検証コマンドと、mjun-startの軽微な修正で回すlintが、`scripts/run_local_lint.sh` を通して実行する。対象は今回の作業で追加・変更したファイルだけなので、触っていないファイルにある既存の違反では作業は止まらない。触ったファイルに既存の違反があれば、そのファイルでは検出される。

## 置き場所

```text
.mjun/lint/
├── sgconfig.yml      # ast-grepの設定 (ruleDirs: [rules])
├── rules/<id>.yml    # ast-grepのrule。1 rule 1ファイル
└── scripts/<id>.sh   # ast-grepで書けないlint。`zsh <script> <file>...` で呼ばれる
```

- `.mjun/` はglobal gitignoreでGit管理外にしてあるので、repositoryの `.gitignore` は変えない
- scriptには、repository rootからの相対パスでファイルが渡される。対象のものだけを見て、違反を `<file>:<line>: <何が違反で、どう直すか>` で出し、違反があればexit 1で終える。severityを `warning` にしたscriptは、違反を出してもexit 0で終える
- 既存のlinterを呼ぶscriptは、repositoryが使っている呼び方 (`uv run ruff`、`npx eslint` など) に合わせる
- テストやfixtureは残さない。lintが正しく働くことは、作るときに1回だけ確かめる

## 手順

1. **規約を集める**: 依頼に出典があればそれを、無ければ `CLAUDE.md`、`AGENTS.md`、`.mjun/steering/`、ADR (`docs/adr/` と `.mjun/steering/adr/`)、READMEの規約節を読む。レビュー指摘からは、2回以上出たものだけを対象にする。1回の指摘をlintにすると、例外の多いlintが増えるからである
2. **規約ごとに判定する**
   - 完全: 規約の文面が対象とする書き方を、lintがすべて判定できる
   - 部分: 一部の書き方しか判定できない (名前による近似など)
   - 不可: 手順・判断・プロセスの規約。lintにしない
3. **手段を選ぶ**: repositoryが既に使っているlinterが同じ判定のruleを持っていれば、設定ファイルを変えずにコマンドの引数で有効にするscriptを作る (例: `ruff check --select T201`)。保守されたruleのほうが、自作より取りこぼしが少ないからである。無ければ、構文の形で判定できるものはast-grepのrule、それ以外 (行やファイルの単位、複数ファイルの関係) はscriptにする。repositoryの既存のlinter設定は変えない
4. **作る**: ruleには `id`、`language`、`severity: error`、`message` (何が違反で、どう直すか)、`note` (出典の場所と、規約の要約1文) を書く。scriptは先頭のコメントに同じ内容を書く。出典は、lintを直すか消すかを後で判断する根拠になる
   - 規約が認める例外 (CLIの出力のための `print` など) は、ruleの `ignores` (ファイルのglob) かscriptの中の条件で除き、`note` か先頭のコメントに理由を書く。repositoryのコードに抑制のコメントは書かない。他の人のコードに、見えないlintのための注記が残るからである。規約が例外を決めていなければ、除く範囲をユーザーに確認する
5. **確かめる**: 違反を含む例と正しい例を一時ファイルに書き、lintが前者だけを検出することを実行して確かめ、一時ファイルを消す。次にrepository全体へ1回実行し、既存の違反の件数を数える。既存の違反があれば、触ったファイルで直すことになるので、`severity: error` のままにするか、`warning` (報告だけで止めない) にするかをユーザーに選んでもらう
6. **文書を更新する**: repositoryの文書 (`CLAUDE.md`、`AGENTS.md`、README、Git管理のADR) は変えない。localのlintは他の人には見えず、`.mjun/` のパスを書くと開けない参照が残るからである。localの文書 (`.mjun/steering/`、ローカルのADR) は、規約の文章を残したまま、lintの場所を添える。ローカルのADRには `Enforced by: .mjun/lint/rules/<id>.yml` の行を足す
7. **報告する**: 規約ごとの表で示す。列は判定、lintのファイル、確かめた結果 (違反例を検出し、正しい例を検出しなかったか)、既存の違反の件数、選んだseverityである。部分の規約が拾わない範囲と、不可の規約とその理由も書く

## 作成済みのlintを直す・消す

`.mjun/lint/` のruleとscriptを読み、`note` や先頭のコメントの出典で対象を探す。直したら手順5で確かめ直す。出典の規約が消えた、または変わったlintは、ユーザーに確認してから直すか消す。消したlintをローカルのADRの `Enforced by:` が指していれば、行は消さずに、ADRを `deprecated` にするかをユーザーに確認する。
