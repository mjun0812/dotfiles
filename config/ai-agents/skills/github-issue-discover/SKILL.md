---
name: github-issue-discover
description: 現在のリポジトリをスキャンしてissue化すべき事項を自動発見し、既存issueとの重複を除いた上でユーザーに承認を取って一括起票するSkill。ドキュメント・ToDoリスト・コード内TODOコメント・CI/設定の不整合・テスト不足・コード品質上の問題を横断的に探す。ユーザーが「issueを洗い出して」「TODOを起票して」「リポジトリの宿題をissue化」「未対応事項をissueにして」のように依頼したら必ずこのSkillを使うこと。
allowed-tools: Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(rg:*), Bash(grep:*), Bash(wc:*), Bash(head:*), Bash(tail:*), Read, Glob, Grep, AskUserQuestion, Skill(github-issue-create)
---

# GitHub Issue Discover

リポジトリを横断的にスキャンしてissue候補を抽出し、既存issueと重複しないものをユーザー承認の上で一括起票する。

## Arguments

- `language`: issueタイトル/本文の言語。デフォルト: `ja`
- `--scope <list>`: スキャン範囲を絞る。カンマ区切りで `docs,todos,ci,tests,code` から選ぶ。未指定なら全範囲
- `--max <N>`: 提示する候補の最大数。デフォルト: `15`（一度に多すぎると承認作業が重い）
- `--dry-run`: 候補抽出と提示までで停止し、issueは作成しない

## Why this skill exists

リポジトリには「READMEの未着手項目」「TODOコメント」「テスト不足」「設定の古さ」など、誰も起票していないが本来issueにすべき事項が潜んでいる。人手で洗い出すのは骨が折れるため、機械的にスキャンして候補化し、人は採否の判断だけを行う、という分業にする。

このskillの責務は **発見と提示** であって、自動で全件作成することではない。雑なissueを大量に作るのは負債でしかないので、ユーザー承認を必ず挟む。

## Phases

### Phase 0: 前提情報の収集

並列で以下を取得する。

- リポジトリ: `gh repo view --json name,owner --jq '.owner.login + "/" + .name'`
- デフォルトブランチ: `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's@^origin/@@'`
- 既存ラベル: `gh label list --limit 100 --json name --jq '[.[].name] | join(",")'`
- Issueテンプレート有無: `ls .github/ISSUE_TEMPLATE/ 2>/dev/null || echo "none"`

**既存issueの取得（重複排除に使う）**:

```bash
gh issue list --state all --limit 300 --json number,title,state,body,labels
```

300件で足りない大きなリポジトリなら `--limit 1000` まで上げる。タイトル + 本文先頭200字程度をまとめてメモリに置き、後段の重複判定に使う。

### Phase 1: スキャン対象の決定

`--scope` 未指定なら全フェーズを実行。指定があれば該当フェーズのみ。各フェーズの結果は内部リストに `{kind, title_draft, body_draft, evidence, suggested_label, suggested_template}` の形で蓄積する。

スキャンは順次でも並列でもよい。重要なのは **証拠（evidence）を必ず残す** こと。後の重複判定や本文生成で「どのファイルのどの行を根拠にこの候補を出したか」を参照する。

### Phase 2A: ドキュメント / ToDoリストのスキャン

最優先のソース。READMEや`doc/`、`docs/` 配下のMarkdown、`TODO.md` / `ROADMAP.md` / `CHANGELOG.md` などに、未着手項目が明示されていることが多い。

調べる場所（存在するものだけ読む）:

- `README.md`, `README*.md`
- `TODO.md`, `TODO`, `ROADMAP.md`, `ROADMAP`
- `CHANGELOG.md`（"Unreleased" セクションに着手予定が書かれていることがある）
- `doc/`, `docs/`, `documentation/` 配下の Markdown
- `CONTRIBUTING.md`（未整備項目が書かれていることがある）

抽出パターン:

- 未チェックのチェックボックス: `- [ ] ...` 行
- 「TBD」「未実装」「TODO:」「FIXME:」「あとで」「後で」「今後」「将来」「予定」を含む見出しや行
- 「Known Issues」「Limitations」「制限事項」「既知の問題」セクション内の各項目

Globで対象ファイルを絞り込み、Grep / `rg` でパターンを抽出する。例:

```bash
rg -n --no-heading -e '^- \[ \] ' -e 'TBD|未実装|TODO:|FIXME:|あとで|後で' \
  README.md doc/ docs/ TODO.md ROADMAP.md CHANGELOG.md 2>/dev/null
```

各ヒットについて、前後数行のコンテキストもReadで取得し、何のタスクかを把握してissueタイトル/本文の下書きを作る。チェックボックスの周辺見出しは大きな手がかり。

### Phase 2B: コード内 TODO / FIXME / XXX / HACK コメント

ソースコード内の未対応コメントを拾う。

```bash
rg -n --no-heading -i -e '\bTODO\b' -e '\bFIXME\b' -e '\bXXX\b' -e '\bHACK\b' \
  -g '!{node_modules,.git,dist,build,vendor,.next,.venv,target}' \
  --type-add 'src:*.{py,ts,tsx,js,jsx,go,rs,rb,java,kt,swift,c,cc,cpp,h,hpp,sh,zsh,bash,lua,php}' \
  -t src
```

各ヒットを単独のissueにすると爆発するので、**集約戦略** を取る:

- 同じファイルに複数あるなら1件のissueに束ねる（タイトル例: `<file>: 内部TODOコメントの整理 (N件)`）
- 同じ機能領域（同一ディレクトリ）に複数散らばっているなら領域単位で1件
- 1件だけなら個別にissue化してよい

「コメントを消すだけ」のような瑣末なものは候補に入れない。中身が「やるべき作業」を示しているもののみ採用する。

### Phase 2C: コード品質上の問題（広く読む）

ユーザーから「コード自体もできるだけ読んで問題点を探す」要望あり。ただし全ファイルを精読するのは現実的でないので、以下の **シグナルベース** で絞り込む。

候補にしてよいもの:

- **エラー処理の欠落**: `try` 無しの危険な操作、 `except: pass` / `catch (_) {}` のような握りつぶし
- **巨大関数 / 巨大ファイル**: 1ファイル500行超、1関数100行超は分割候補
- **重複コード**: 明らかに同一ロジックが3箇所以上
- **ハードコードされた値**: 設定化すべきURL、シークレットらしき文字列（漏洩懸念があれば最優先）
- **未使用コード**: import済みで参照されていないシンボル、コメントアウトされたまま放置のブロック
- **依存関係の警告**: `npm audit` / `pip-audit` / `cargo audit` 等が走るなら一度実行して脆弱性を拾う

シークレット漏洩の疑いがある場合は **最優先かつ慎重に**。issue本文に該当箇所の生の値を書かず、ファイルパスと行番号のみ記す。ラベル `security` を提案。

候補にしないもの:

- 単なるスタイル違反（lintツールの仕事）
- 主観的な「もっと綺麗に書ける」（明確な問題でない限り）
- 既にコメントで「あえてこうしている」と説明があるもの

### Phase 2D: CI / 設定ファイルの不整合

調査対象:

- `.github/workflows/*.yml` の `uses:` 行に古いaction（v1系、v2系のまま）
- `actions/checkout`, `actions/setup-*`, `actions/cache` 等のメジャーバージョン
- `Dockerfile` の古いベースイメージ（EOL OS など分かるもの）
- `package.json` / `pyproject.toml` 等で `engines` や `python_requires` がEOLバージョン
- `.github/dependabot.yml` の不在（依存更新のフローがない）
- `.gitignore` に明らかな漏れ（`.env` が無視されていない等）

候補生成例:

- `actions/checkout@v3 → v4 への更新` （ファイル: `.github/workflows/ci.yml`）
- `Python 3.8 サポート終了に伴う最低バージョン引き上げ`

### Phase 2E: テスト不足箇所

精度を出しにくい領域なので **明確なギャップだけ** を拾う:

- ソースに対応するテストファイルが0件のモジュール（`src/foo.py` に対し `tests/` 配下に `foo` 関連テストがない等）
- テストカバレッジレポートがリポジトリにあれば、極端に低いファイルを抽出
- `pytest`/`jest` などの設定はあるが `tests/` ディレクトリが空 or 1ファイルしかない

ファイル単位で「テスト追加: `<module>`」のissueを提案。テンプレートは `test.md` を選ぶ。

### Phase 3: 重複排除

各候補について、Phase 0で取得した既存issue（open + closed）と突き合わせる。

判定ルール（OR条件、いずれか満たせば「重複」とみなす）:

- タイトルの正規化文字列が一致する（小文字化、記号除去、トリム後）
- タイトルの主要キーワード3つ以上が既存issueタイトルに含まれる
- 候補のevidence（ファイルパス + 行番号 or ファイルパス + キーワード）が既存issueの本文に含まれる

迷ったら重複扱いで除外する。誤ってissueを増やす方が、誤って漏らすより負債が大きい。除外した候補は最終レポートで「既存と重複のため除外」として件数だけ報告する。

### Phase 4: 候補の優先度付けと下書き作成

残った候補に kind ごとの優先度を付ける（高い順）:

1. セキュリティ関連（シークレット漏洩、脆弱性）
2. ドキュメントに明示された未着手項目
3. CIや依存の更新（壊れる前に）
4. コード品質の重大な問題
5. テスト不足
6. TODO/FIXMEコメント

`--max` を超える場合は優先度の低いものから打ち切る。打ち切られた件数も最終レポートに含める。

各候補について **タイトル下書き** と **kind → テンプレ名** のマッピングを作る:

- **タイトル**: 動詞始まりで具体的に。`update X`, `remove Y`, `add tests for Z`, `bugfix: ...` のように行動が伝わる形
- **テンプレマッピング**（Phase 6 で `github-issue-create --template <name>` に渡す値）:
  - ドキュメントの未着手項目 / コード品質改善 / リファクタ → `task`
  - 新機能の提案 → `feature_request`
  - 不具合・脆弱性・既知のバグ → `bug_report`
  - テスト追加 → `test`
- **本文の素材**: 背景・目的・参考情報（ファイルパス + 行番号、引用文）を整理しておく。テンプレへの流し込みは Phase 6 で `github-issue-create` 側に任せる
- **ラベル候補**: kind に合うものを Phase 0 の既存ラベル一覧から選ぶ（`enhancement`, `bug`, `documentation`, `test`, `security` など、実在するもののみ）。テンプレ自身が持つデフォルトラベルは `github-issue-create` が自動付与するので、ここでは「追加したいラベル」だけ控える

本文の整形（テンプレ選択、セクション割り当て、フロントマター除去）は重複実装を避けるため `github-issue-create` に委譲する。このskill側では下書き素材だけ用意する。

### Phase 5: ユーザーへの一覧提示と承認

整形済み候補を **Markdown一覧** で提示する。各候補に番号、kind、タイトル、根拠（ファイル:行）の1行サマリを付ける。

```
## issue候補 (N件)

1. [task] update CI: actions/checkout@v3 → v4
   .github/workflows/ci.yml:12
2. [task] doc/architecture.md の未着手項目: 監視設計の追記
   doc/architecture.md:45
3. [test] tests/test_parser.py が無い (parser.py に対応するテスト不在)
   src/parser.py
...
```

詳細本文を見たい候補があるかをユーザーに聞く前に、まず一覧だけ見てもらい採否を決めてもらう。多数の候補がある場合は1メッセージにすべて出す（途中で切らない）。

採否の取得方法は **多段** で行う:

1. 「全件作成 / 個別選択 / 全件キャンセル / 詳細を見たい候補がある」を AskUserQuestion で聞く
2. 「個別選択」が選ばれた場合、4件以下なら AskUserQuestion の multiSelect で直接、5件以上なら「除外したい番号をカンマ区切りで」とテキストで返してもらう（"Other" 入力を使う）
3. 「詳細を見たい候補がある」が選ばれたら、その番号を聞き、本文ドラフトを表示してから再度採否を聞く

`--dry-run` 指定時は Phase 5 の一覧提示で停止し、ユーザーに「ドライランです。実際に作成するには `--dry-run` を外して再実行してください」と伝えて終了。

### Phase 6: 一括作成（github-issue-create に委譲）

承認された候補は **`github-issue-create` skill を Skill ツール経由で並列に呼び出して作成する**。本skill側で `gh issue create` を直接叩かない。テンプレ選択・本文整形・フロントマター除去は元skillが既に持っているロジックなので二重に持たない。

各候補について以下のように呼ぶ:

```
Skill(github-issue-create) args="ja --template <task|feature_request|bug_report|test> --title <タイトル> --body <本文素材> --no-confirm [--label <name> ...]"
```

引数の作り方:

- `ja` / `en`: discover の `language` 引数を素通しする
- `--template <name>`: Phase 4 で決めたテンプレ名（`task` / `feature_request` / `bug_report` / `test`）
- `--title <s>`: Phase 4 で作ったタイトル下書き
- `--body <s>`: Phase 4 で集めた背景・目的・参考情報を改行区切りでまとめた **下書きテキスト**。これを `github-issue-create` がテンプレに沿って整形してくれる
- `--no-confirm`: Phase 5 で既にユーザー承認を取っているので最終確認はスキップする
- `--label <name>`: Phase 4 で決めた追加ラベル。複数指定する場合は `--label foo --label bar` のように繰り返す

#### 並列実行のガイドライン

承認された候補は同一メッセージ内で **複数の `Skill(github-issue-create)` 呼び出しを並列発行** して一気に作成する。各候補は独立しているので並列でレースは起きない。

- **バッチサイズ**: 1メッセージあたり最大 **5〜10件** を目安に並列発行する。これより多いとメインコンテキストへの結果流入が一度に重くなるため
- **件数が多い場合**: 候補が10件を超えるなら、 5〜10件のバッチに分けて、バッチ単位で順に流す（バッチ内は並列、バッチ間はシリアル）
- **rate limit**: GitHub のコンテンツ作成系 secondary rate limit は1分あたり概ね80件が目安。20件程度のバッチを連続発行する程度なら問題にはならない。100件規模を一気に作る用途では使わない
- **エラーハンドリング**: 1件が失敗しても他の並列呼び出しには影響しない。失敗した候補のエラー内容と、成功した候補の URL を Phase 7 レポートで集計する

すべての `Skill(github-issue-create)` 呼び出しから返ってきた issue URL を記録して、Phase 7 のレポートに使う。

### Phase 7: 最終レポート

```
## 完了

作成: N件
- #123 update CI: actions/checkout@v3 → v4 — <url>
- #124 ...

スキップ: M件（既存issueと重複）
キャンセル: K件（ユーザー却下）
打ち切り: L件（--max 超過、優先度低）

総候補数: N+M+K+L 件
```

URLはMarkdownリンクではなく素のURL（クリックできる端末向け）で提示する。

## Failure modes に注意

- **gh認証なし**: `gh auth status` で確認し、未認証なら作業前に停止して案内する
- **public repoでないと困る**: シークレット候補をissueにする時、private repoかを確認する。public repoなら本文に証拠を貼る前にもう一段ユーザーに確認を取る
- **巨大リポジトリ**: スキャン時間が長くなる。`--scope docs` などで絞ることをユーザーに案内する
- **monorepo**: ファイル数が多くノイズが増える。優先度高のもの（security / docs明示）に絞る方が現実的

## 既存skillとの関係

- `github-issue-create`: 1件ずつ対話的に作るskill。本skillは **発見** と **重複排除** と **一括承認** が責務で、実際の作成（テンプレ選択 / 本文整形 / `gh issue create`）は `github-issue-create` に委譲する。委譲モード（`--title` / `--body` / `--template` / `--no-confirm`）で呼び出すことで、対話を省略しつつ既存ロジックを再利用する
- `github-fix-ci`: CI失敗の修正。本skillはCI設定の **未来の問題** を予防的にissue化する点で異なる
