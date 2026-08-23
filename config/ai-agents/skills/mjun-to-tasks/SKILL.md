---
name: mjun-to-tasks
description: >-
  spec (GitHub Issueまたは `.mjun/specs/` のLocal spec) を、単独で検証可能なvertical sliceのtaskへ分解するSkill。
  通常はmjun-specifyが承認後に自動で連結する。ユーザーが「taskに分解して」「分解をやり直して」と依頼したときや、
  specの変更後に再分解したいときに単体で使うこと。実装そのもの、およびspec本文の作成・修正には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(cat:*), Bash(ls:*), Bash(mktemp:*)
---

# mjun-to-tasks

specをtaskへ分解し、Local specでは `tasks.md`、GitHub modeではIssue本文のchecklistとして永続化するSkillです。分解はAgent-ownedの作業として承認なしで行います (child Issueの作成だけは承認を取る)。

GitHub操作は必ず `gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

## Arguments

- `source` (必須): 分解対象。GitHub Issue番号 (`#123` / `123`) または `.mjun/specs/<slug>` のLocal specディレクトリ
- `--child-issues` (任意): GitHub modeで、checklistの代わりにtaskごとのchild Issueを作成する。作成前に必ずユーザーの承認を取る
- `--dry-run` (任意): 分解結果の提示までで停止し、tasks.md・Issue・child Issueへの書き込みを一切行わない

呼び出し元 (mjun-specifyなど) から調査済みの文脈 (requirements、boundary、変更対象の見当) を渡された場合はそれを使い、specの読み直しを最小にする。

### mode判定

1. sourceがIssue番号またはGitHub URL → GitHub mode
2. sourceが `.mjun/specs/<slug>` のパス → Local mode
3. 判定できない場合は中止してユーザーに確認する

## 分解規則

- **vertical slice**: 各taskは、DB・API・UIのようなlayer別ではなく、単独で検証・デモできるend-to-end behaviorにする。horizontal layerのtaskを作らない
- **大きさ**: 1 taskは1つのfresh contextで実装しきれる大きさにする。収まらないtaskは分割する
- **属性**: 各taskにBoundary (specのOwns内のどの責務か)、Blocked by (先に完了が必要なtask)、Acceptance Criteria (機械的に判定できるcheckbox) を付ける
- **wide refactorの例外**: 1つの機械的変更のblast radiusがコードベース全体へ及ぶ場合だけvertical sliceの例外とし、expand (新形を旧形の隣へ追加) → migrate (呼び出し側を段階移行) → contract (旧形を削除) の順のtaskへ分解する
- **依存検査**: Blocked byのグラフにcycleが無いことを確認する。cycleがあればtaskの切り方を見直す
- **単一task**: 分解しても1 taskにしかならない場合は、task artifactを作らず「spec全体を1 taskとして実装可能」と報告して終了する

## Task形式

```markdown
## T-001: <単独で検証可能な振る舞いを表すタイトル>

- Status: ready
- Boundary: <責務名>
- Blocked by: none | T-NNN

### Acceptance Criteria

- [ ] <観察可能な振る舞い>
```

- `Status` は `ready | in-progress | done`。分解時はすべて `ready` とする
- 実装時のresumeと進捗管理に使われるため、この形式を崩さない

## 手順

1. sourceを読む (GitHub: `gh issue view` で本文、Local: `spec.md` と、あれば `design.md`)。Requirements・Boundaries・Acceptance Criteriaが読み取れない場合は中止し、specを先に整えるよう案内する
2. 分解規則に従ってtask一覧を作る
3. 依存グラフ (Blocked by) を確認し、実装順に並べる
4. 分解結果 (task一覧・依存関係・単一taskの場合はその旨) を提示する。`--dry-run` はここで終了する
5. 永続化する
   - **Local mode**: `.mjun/specs/<slug>/tasks.md` へTask形式で書き込む。末尾に空の `## Implementation Notes` セクションを置く。既存のtasks.mdがある場合は、doneのtaskを保持したまま未着手部分を置き換える
   - **GitHub mode (デフォルト)**: Issue本文の `## Tasks` セクションへ `- [ ] T-001: <タイトル>` 形式のchecklistとして書き込み、各taskの詳細 (Boundary / Blocked by / Acceptance Criteria) を同セクションに続ける。本文の書き換えは一時ファイル経由 (`gh issue edit <number> --body-file <tmpfile>`) で行う
   - **GitHub mode (`--child-issues`)**: 作成するchild Issueの一覧 (タイトル・本文案) を提示してユーザーの承認を得てから、taskごとにIssueを作成し、親Issueの `## Tasks` へ `- [ ] #<child番号>` を列挙する。task statusはchild Issueのopen/closedで管理される
6. 結果を報告する: task数、依存関係、書き込み先。呼び出し元がいる場合はtask一覧を返す
