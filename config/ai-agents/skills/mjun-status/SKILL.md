---
name: mjun-status
description: >-
  `.mjun/specs/` のLocal specの進捗 (contract承認、task完了、実装branch、投影先Issue) を索引なしで導出して一覧・詳細表示するSkill。
  ファイルへの書き込みは行わない。
  ユーザーが「specの状況を見せて」「進行中のspecを一覧して」「このspecはどこまで進んだ?」のように依頼したら使うこと。
  specの作成・磨き上げ・実装・task分解には使わない。
allowed-tools: Read, Glob, Grep, Bash(zsh:*), Bash(git rev-parse:*), Bash(gh issue view:*), Bash(gh pr list:*), Bash(ls:*), Bash(cat:*)
---

# mjun-status

`.mjun/specs/<slug>/` 配下のファイルと git の状態だけから、各specの現在地を導出して表示するSkill。索引ファイルや状態フィールドを新設せず、毎回内容から判定する。表示だけを行い、spec・tasks・git・GitHubのいずれにも書き込まない。

## Arguments

- `source` (任意): `.mjun/specs/<slug>` のパス、またはGitHub Issue番号 (`#123` / `123`)。指定時はそのspecの詳細を表示する。未指定時はactiveなspec全件の一覧を表示する
- `--all` (任意): 一覧に `status: done` のspecも含める

## 手順

### 1. 対象の確定

1. `git rev-parse --show-toplevel` でrepository rootを特定し、`scripts/mjun_status_scan.sh` を実行する。`NO_SPECS` が返れば「specなし」と報告して終了する

   ```bash
   zsh "<skill-dir>/scripts/mjun_status_scan.sh" "<repo-root>"       # activeなspecだけ
   zsh "<skill-dir>/scripts/mjun_status_scan.sh" "<repo-root>" --all # doneのspecも含める
   ```

2. 対象specを決める
   - `source` なし: scriptの出力全件 (`--all` 指定時は `--all` を付けて実行する)
   - `.mjun/specs/<slug>` のパス: `--all` で実行し、そのslugのブロックだけを対象にする (`status` を問わない)
   - Issue番号: 出力の `source:` が `#<number>` と一致するactiveなspec。複数ヒットした場合は全件を対象に警告付きで表示する。activeに無ければ `--all` の出力からも検索し、見つかれば「実装済み」として表示する。どちらにも無ければ「未取り込み」と報告して終了する

### 2. 各specの読み取り

scriptはspecごとに `## <slug>` ブロックを出力する。`status` / `approval`、タイトル、`Source`、phase、Requirements / Acceptance Criteriaの有無、Dependencies (`spec: <slug>`)、design / research / prototypeの有無、decisions件数とtentativeの一覧、Implementation Branchとそのlocal branch・worktreeの有無、task statusの集計、blocked taskの原因と再開条件、Implementation Notesの件数、Run Logの行は、この出力から取る (再パースしない)。

scriptが出さない次の項目だけを自分で読む。存在しないファイルは「なし」として扱い、エラーにしない。

| 読むもの                    | 取り出す項目                                                                                                                                                                                                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `spec.md`                   | `## Boundaries` の Owns / Public Contracts Affected (spec間の警告に使う)。詳細表示では `### Revalidation Triggers` の本文                                                                                                      |
| `design.md`                 | `## Change Outline` のmodule / directory一覧 (spec間の警告に使う)                                                                                                                                                              |
| `decisions.md` / `tasks.md` | 詳細表示のみ: 全decisionの D番号 / タイトル / Status、全taskの T番号 / タイトル / Status / Blocked by                                                                                                                          |
| GitHub (任意)               | `Source: #N` があれば `gh issue view <N> --json state,url`、Implementation Branchがあれば `gh pr list --head <branch> --state all --json number,state,url --limit 1`。`gh` が失敗した場合は該当項目を `unknown` にして続行する |

### 3. phaseの導出

保存されたphaseは存在しないため、scriptが次の順に判定する (先に一致した行を採用する)。

| phase          | 条件                                                                                                                                                  |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `done`         | `status: done`                                                                                                                                        |
| `drafting`     | `approval: pending` (または `approval` 無し)                                                                                                          |
| `approved`     | `approval: approved` かつ `tasks.md` に `Implementation Branch` が無い                                                                                |
| `implementing` | `Implementation Branch` があり、`done` 以外のtaskが残っている                                                                                         |
| `delivering`   | `Implementation Branch` があり、全taskが `done` (配送が完了していればspecは `done` になっているはずなので、PR作成失敗か `--no-pr` で止まっている状態) |

phaseに応じた「次に必要なこと」を1行で添える。skill名や手順ではなく、状態として書く。

- `drafting`: contractの承認待ち。tentativeがあれば件数を添える
- `approved`: 実装を開始できる。tentativeが残っていれば「要確認 n件の解消が先」、Dependenciesの `spec: <slug>` が `done` でなければ「spec <slug> の完了が先」とする
- `implementing`: 実装の再開 (branch名、残りtask数、blocked task数)。実行可能taskが無ければ、blocked taskの再開条件の充足が必要と表示する
- `delivering`: 配送 (PR) が未完了。branch名と、PRがあればそのURL
- `done`: なし

### 4. 警告の検出

内容の矛盾や取り残しを検出し、該当specの行に付ける。

- tentativeのdecisionが残っている (`approved` 以降のphaseでは特に強調する)
- `approval: pending` なのに `Implementation Branch` がある (実装開始後にcontractが再磨き上げ中)
- `Implementation Branch` のlocal branchが存在しない (次回の実装は新規branchとして始まる)
- `Implementation Branch` のworktreeが `.tmp/<repo-name>-worktrees/` に残っている (前回の実行が後始末されていない)
- `Source: #N` のIssueが `CLOSED` なのに `status: active`
- 同じ `Source: #N` を持つactiveなspecが複数ある
- `spec.md` に `## Requirements` または `## Acceptance Criteria` が無い
- `status: active` なのに `spec.md` が無い、またはfrontmatterに `status` が無い (壊れたspec)
- 他のactiveなspecとOwnsが重なる、Public Contracts Affectedが同じ公開interfaceを指す、または `design.md` のChange Outlineのdirectoryが重なる (両方のspecに付ける)
- Dependenciesの `spec: <slug>` が指すspecが存在しない、または `done` でない (実装を開始できない)

spec間の警告は、`source` 指定時もactiveなspec全件の `spec.md` と `design.md` を読んで判定する。

### 5. 出力

ユーザーの言語で、チャットにだけ出力する。ファイルは作らない。

**一覧 (`source` なし)**: specごとに1行の表。列は slug / タイトル / approval / phase / tasks (done数 / 総数とblocked数。`tasks.md` が無ければ `-`) / branch または PR / 次に必要なこと。表の下に警告を spec ごとにまとめて列挙する。specが0件なら「activeなspecはありません」とだけ報告する。

```text
| slug | title | approval | phase | tasks | branch / PR | next |
| --- | --- | --- | --- | --- | --- | --- |
| add-status-skill | mjun-status skillの追加 | approved | implementing | 2/4 | feat/12-add-status-skill | 実装の再開 (残り2 task) |

警告:
- add-status-skill: tentative 1件 (D-003)
```

**詳細 (`source` あり)**: 上記1行に加えて次を出す。

- Source: Issue番号、state、URL (あれば)
- Decisions: D番号 / タイトル / Status の一覧 (tentativeを先頭に)
- Tasks: T番号 / タイトル / Status / Blocked by の一覧と、blocked taskの直接原因・再開条件、Implementation Notesの件数
- Run Log: `## Run Log` の行をそのまま (収束しなかったtaskの原因分析に使う)
- 付随ファイル: design.md / research/ / prototype/ の有無
- Revalidation Triggers: `spec.md` の `### Revalidation Triggers` の本文 (あれば。前提が崩れていないかを人間が見直すための再掲)
- 警告: 該当するものすべて

## 制約

- 読み取り専用。`spec.md` / `tasks.md` / git / GitHub を変更しない。worktreeやbranchの削除も行わない (警告として報告するに留める)
- `gh` は補助情報のためだけに使う。認証失敗やネットワーク失敗では該当項目を `unknown` にして続行し、実行を止めない
- 索引や状態ファイルを作らない。導出結果をキャッシュしない
