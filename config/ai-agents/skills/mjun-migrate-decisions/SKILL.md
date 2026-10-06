---
name: mjun-migrate-decisions
description: >-
  既存プロジェクトの旧形式の決定記録 `decisions.md` (`.mjun/steering/decisions.md` または `docs/adr/decisions.md`) を、
  1決定 = 1ファイル (`NNNN-<slug>.md`) の新形式へ分割し、spec・steering・用語集のD番号参照を新番号へ書き換えるSkill。
  ユーザーが「decisions.mdを新形式に移行して」「決定記録を1件1ファイルに分けて」と依頼したら使うこと。
  新しい判断の記録や、`.mjun/` からGit管理 (`docs/adr/`) への保存先の移行には使わない。
allowed-tools: Read, Edit, Glob, Grep, AskUserQuestion, Bash(git:*), Bash(python3:*), Bash(mktemp:*), Bash(rg:*), Bash(rm:*), Bash(cat:*), Bash(ls:*)
---

# mjun-migrate-decisions

旧形式の `decisions.md` (1ファイルに `## D-NNN: <タイトル>` のentryを並べた形式) を、新形式の決定記録へ機械的に移す。判断の内容は変えず、ファイルの分割・番号の付け替え・参照の書き換えだけを行う。

## 新形式

| 移行元                        | 移行先                |
| ----------------------------- | --------------------- |
| `.mjun/steering/decisions.md` | `.mjun/steering/adr/` |
| `docs/adr/decisions.md`       | `docs/adr/` (Git管理) |

- 1決定 = 1ファイル。ファイル名は4桁ゼロ埋めの番号と、タイトルを英小文字・数字・ハイフンで要約したslug (例: `0007-use-event-sourcing.md`)
- H1は `# D-NNNN: <タイトル>` で、番号はファイル名と一致させる。本文の箇条書き (Date / Scope / Kind / Source / Owner / Status / Decision / Alternatives / Rationale / Evidence) は旧entryのまま
- 番号は旧D番号をそのまま4桁にする (`D-001` → `D-0001`)。移行先に別形式の既存ADR (`0001-record-architecture-decisions.md` など) があり番号が衝突するentryだけ、移行先の最大番号 + 1から振り直す
- specの `Decisions:`、`superseded by`、本文中のD番号も新番号で書く

## 手順

### 1. 計画を作る

1. `git rev-parse --show-toplevel` でrepository rootを特定する。`git rev-parse --git-dir` と `git rev-parse --git-common-dir` が異なる (linked worktreeにいる) 場合は、メインrepositoryの作業ツリーで実行し直すよう報告して終了する。`.mjun/` はgit管理外で、worktreeからは正しく扱えないため
2. 計画ファイルを一時パスに作り、scriptで計画を出す

   ```bash
   plan=$(mktemp -t mjun-decisions-plan)
   python3 "<skill-dir>/scripts/migrate_decisions.py" plan "<repo-root>" "$plan"
   ```

3. 出力を確認する
   - `ERROR: decisions.md が見つからない` → 「移行対象なし」と報告して終了する
   - `ERROR: decisions.md が2箇所にある` → 旧形式での `.mjun/` からGit管理への移行が途中で止まっている。両ファイルのentryの差分 (D番号とタイトル) を示し、どちらを正とするかの整理を人間に依頼して終了する。どちらかを勝手に削除しない
   - `ERROR: D番号が重複している` → 重複しているentryを示して終了する。どちらを残すかは判断内容の問題なので人間が決める
   - `unparsed:` に行がある → `## D-NNN:` のentryに属さない内容 (独自の節や注記) で、移行先へ移らない。行を示し、AskUserQuestionで「中止して手動で整理する」「該当行を移行せず続行し、移行元は削除せず残す」を選んでもらう
   - `renumbered:` に行がある → 既存ADRとの衝突で番号が変わるentryとして、後の報告に含める

### 2. slugを決める

計画ファイルはTSV (`旧D番号` `新番号` `slug` `タイトル`) で、slug列が空になっている。各行のタイトルから、内容を表す英語の短いslug (英小文字・数字・ハイフン、3〜6語程度) を決めてslug列へ書き込む。旧D番号・新番号・タイトルの列は変えない。

### 3. 適用する

```bash
python3 "<skill-dir>/scripts/migrate_decisions.py" apply "<repo-root>" "$plan"
```

scriptは次を行う。移行元の `decisions.md` は削除しない。

- 移行先へentryファイルを作る (既存ファイルと番号が衝突する場合は何も書かずにエラーで止まる)
- entry本文、`.mjun/` 配下の全Markdown (spec.md・design.md・tasks.md・research・steering)、repo直下の `CONTEXT.md` の旧D番号を新番号へ置き換える
- `superseded by` の参照先の実在と、書き換えたファイルに旧形式のD番号 (`D-` + 1〜3桁) が残っていないことを検査し、`problems:` に出す

`ERROR` で止まった場合は内容に従って計画を直し、再実行する。計画の不整合と番号の衝突は書き込み前に検査するため、これらのエラーではファイルは作られていない。

### 4. 残りの参照を直す

1. `problems:` の各行を確認する。旧形式のD番号が残っている場合は、そのファイルを読み、判断記録への参照なら新番号へ直す。無関係な文字列なら残す
2. repository全体で旧ファイルへの参照を探す。`.mjun/` はgitignore対象でrgの通常検索から外れるため、別に `--no-ignore` で検索する

   ```bash
   pattern='decisions\.md|(^|[^\w-])D-[0-9]{1,3}([^0-9]|$)'
   rg -n --hidden -g '!.git' "$pattern" "<repo-root>"
   rg -n --no-ignore --hidden "$pattern" "<repo-root>/.mjun"
   ```

   - `.mjun/` 配下と `CONTEXT.md` の `decisions.md` へのリンクやアンカーは、該当する新しいentryファイルへのリンクに直す
   - それ以外のGit管理ファイル (READMEやdocsなど) にある参照は、一覧を示してから直す。コードやテストに判断記録の番号が埋め込まれている場合は、勝手に直さず人間に確認する
   - 移行元の `decisions.md` 自身の行は対象外

3. GitHub Issue本文の `## Decision Log` など、repository外にある旧D番号は書き換えない。報告に含める

### 5. 検証して移行元を削除する

1. 移行先の `NNNN-*.md` のうち `# D-NNNN:` で始まるファイルの数が、計画の行数と一致することを確かめる。新しいファイルを2〜3件Readし、旧entryの本文 (D番号以外) と一致していることを確認する
2. 移行元を削除する。手順1でunparsed行を残す選択をした場合は削除しない
   - `.mjun/steering/decisions.md`: `rm` で削除する
   - `docs/adr/decisions.md`: Git管理下なら `git rm`、未追跡なら `rm` で削除し、作成したentryファイルを `git add` する。commit・pushは依頼された場合だけ行う
3. 計画ファイル (`$plan`) を削除する

## 報告

- 移行元と移行先、移行したentry数
- 番号を振り直したentry (`D-001 → D-0003` の形式。無ければ「なし」)
- 参照を書き換えたファイルの一覧
- 移行しなかった内容 (unparsed行と、移行元を残したかどうか)
- 手で直した参照、人間の確認待ちの参照、repository外に残る旧D番号
- Git管理の移行先では、stageしたファイルと未commitであること

## Safety

- 判断の本文 (Decision / Rationale / Evidenceなど) を要約・修正しない。変わるのはH1とD番号だけ
- 移行先の既存ファイルを上書き・削除しない
- 検証が済むまで移行元を削除しない。途中で失敗・中断した場合は移行元を残したまま、作成済みのentryファイルと書き換えたファイルを報告する
