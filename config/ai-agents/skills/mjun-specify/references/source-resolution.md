# Source Resolution

spec、Issue、状態の対応。専用のindexや同期状態ファイルは持たず、毎回ここに書いた方法で導出する。状態を二重に持つと、どちらが正しいかで食い違うためである。

## Localが正、GitHubは投影

specの実体は常に `.mjun/specs/<slug>/` である。GitHub Issueは取り込みと投影のアダプタで、作業中は読み書きしない。

```text
取り込み: Issue → .mjun/specs/<slug>/ へspec化 (このskillだけが行う)
作業:     spec作成・task分解・実装のどの段階でもLocalのspec文書とADRを読み書きする
投影:     承認後、判断シートとACを Issue本文 (作成者が自分でなければ投影コメント) へ反映 (Sourceを持つspecのみ)
完了:     worktreeで実装 → PR (SourceがあればCloses #N)
```

task分解に未取り込みのIssue番号が渡された場合は、中止してこのskillでの取り込みを案内する。実装 (`mjun-implement`) に渡された場合は、`mjun-start` が作業の種類を振り分ける。取り込む側は、Issueが直接実装できる品質かを判断しない (spec作りに当たらない依頼は、Phase 0の振り分けで `mjun-start` へ渡す)。

## Local specの配置

```text
.mjun/specs/<slug>/
├── spec.md          # 必須。実装者が従うcontract (人間は判断シートで承認する)
├── design.md        # 必須。contract内の実装設計。承認前に書く
├── tasks.md         # taskと実装状態。承認後に作り、単一taskでも持つ
├── prototype/       # artifact自体を一次資料として残す場合だけ
└── research/        # 外部調査が発生した場合だけ
```

- `<slug>` は内容を表す英語kebab-case。既存slugと衝突すれば末尾に `-2`, `-3` を付ける
- `spec.md` だけから始めてよい
- `tasks.md` のtaskの `Status` と、resume先の `Implementation Branch` は実装側が管理する

## ライフサイクル状態 (`status`)

specは作業中だけ使う文書である。作成・取り込み時に `status: active` を書き、PR作成などを終えた時点で実装側が `status: done` へ更新する。その後も残す価値があるものは、コードとテスト、ADR、用語集、Issue、PR、commitに移っている。そのため `status: done` のspecは、どのskillも逆引き・一覧・比較・依存の判定に使わず、ユーザーが手で削除する。残っていても削除されていても、skillの挙動は変わらない。一覧と進行中spec間の比較は `active` だけを対象にし、明示的にパスを渡されたspecはstatusを問わず読む。放棄したspecは手で削除する。

## Contract承認状態 (`approval`)

実装側は `approval: approved` 以外のspecを受け付けない (spec外の単発Markdownを起点にする実装は対象外)。そのため `approved` にしてよいのは、Phase 5で人間が「反映する」を選んだときだけである。

activeなspecの一覧は次で導出する。

```bash
grep -l "^status: active" .mjun/specs/*/spec.md   # activeなspecの列挙
grep -m1 "^# " <spec.md>                          # H1タイトル
grep -m1 "^Source: " <spec.md>                    # 投影先 (あれば)
```

## spec間の依存と境界

複数のspecが同時にactiveになり、別々の会話で並行して実装される前提で扱う。

- 他のactive specの成果に依存するspecは、BoundariesのDependenciesに `spec: <slug>` の行を書く。実装側はそのspecが `status: active` のあいだ実装を始めない (doneになるか、作業を終えた後に削除されたら始める)
- 境界の重なり (Ownsの重なり、Public Contracts Affectedが同じ公開interfaceを指す、`design.md` のChange Outlineのdirectoryの重なり) は、spec作成時の調査とspec reviewで見つける。並行実装で衝突するので、どちらのspecが所有するか、分割・統合するかは人間が決める (Human-owned)

## `Source:` 行

GitHub Issueから取り込んだspec (または投影先Issueを作ったspec) は、`spec.md` のH1直下に投影先への参照を1行持つ。無いspecは純Local (投影しない) である。

```markdown
# <Title>

Source: #123

## Context
```

Issue番号からspecを逆引きするときは、activeなspecから `Source: #<N>` を検索する。

- 複数ヒットすれば一覧を示して選んでもらい、選ばれなかった方の整理 (統合または削除) を促す
- activeに無ければ未取り込みとして扱う。doneのspecは検索しない

`Source:` を持つspecは、contract承認後に [issue-projection.md](issue-projection.md) に従ってIssueへ投影する。投影先は、作成者が自分なら本文、自分でなければ投影コメントである。

## git管理外であることの影響

`.mjun/` はグローバルgitignoreによりgit管理外である。

- worktreeは `.mjun/` を含まない。skillが作るworktreeには作成直後に `<repo-root>/.mjun` へのsymlinkを張り、worktree内からspec文書を参照・更新するときはメインrepositoryの絶対パスを使う
- specは内部文書である。PR本文・PRタイトル・commit messageなど外部向けの出力では `.mjun/` 配下のパスやspecの存在に触れず、specの参照にはGitHub Issue (`Closes #N`) だけを使う。外部の読み手は参照先を開けない
- repo直下の `CONTEXT.md` はgit管理下にあり、worktreeにも存在する
