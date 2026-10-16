---
name: mjun-implement
description: >-
  承認済みのspec (`.mjun/specs/` のLocal spec、GitHub Issue番号、または単発の設計doc) を起点に、task group単位の実装からAcceptance Criteriaの照合、commit、必要ならPR作成までを一気通貫で行うSkill。
  ユーザーが「#Nを実装して」「このspecを実装して」「実装してPRまで」のように依頼したら使うこと。
  specの作成・磨き上げ・承認や、未取り込みIssueの取り込みには使わない。
  specも設計docも無く、会話の中で決めた小規模な変更にも使わない (直接実装する)。
  呼び出し元から作業指示を渡された実装担当 (SubAgentやorchestratorのworker) は、指示がこのSkillの実行を明示しているときだけ使い、それ以外はその指示に従う。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(shasum:*), Bash(zsh:*), AskUserQuestion, Skill(git-commit), Skill(github-pr-create), Skill(mjun-to-tasks)
---

# mjun-implement

specを起点に、内容検査 → 実装 → commit → (必要なら) PR作成までを進めるSkill。
メイン会話が担うのは、検査、worktree作成、SubAgentへの引き継ぎ、進捗の永続化、結果検証、クリーンアップであり、**実装 (Phase 3) はSubAgentに委譲し、commitとPR作成 (Phase 4) は `git-commit` skillと `github-pr-create` skillに連結する**。

repositoryに残るもの (コード、コメント、テスト名、関数名、ファイル名) とGitHubへ出すもの (commit message、PRのタイトルと本文) に、spec内部の識別子 (task ID、AC番号、Requirement番号、`.mjun/` のパス、`spec.md` / `tasks.md`) を書かない。手順の中で `zsh <skill-dir>/scripts/check_internal_ids.sh` (以下、ID検査) を実行して機械的に確かめ、検出されたら振る舞いや目的を表す言葉に書き換える。
spec modeのtaskはspec作成側が `tasks.md` に決めたものを実行し、実装中に分かった事実で再分解が必要になった場合も `mjun-to-tasks` に連結する (分解規則をこのskillに持たない)。

## Arguments

- `source` (必須): 実装対象。GitHub Issue番号 (`#123` / `123`)、`.mjun/specs/<slug>` のLocal specディレクトリ、または単発Markdownのパス
- `--pr` / `--no-pr` / `--merge` (任意): 実装をPRとして届けるか、local commitまでで終えるか、base branchへfast-forward mergeして届けるか。**いずれも未指定の場合は、worktree作成前に確認する** (長時間の自律実装の最後で確認待ちにしない)

### source種別

sourceの形からmodeを決める。

1. `.mjun/specs/<slug>` のディレクトリ、またはその配下のファイルパス → **spec mode**
2. Issue番号またはGitHub URL → 取り込み済みspecへの逆引き (下記) を経て **spec mode**
3. その他のMarkdownパス → **doc mode**。ファイル全文を起点とする (frontmatterがあれば除く)

spec modeでは、specディレクトリ配下の `spec.md`、`design.md`、`tasks.md` (いずれも必須) をReadする。specの判断は `design.md` の `## Decisions` にある。ADR (Git管理へ移行済みなら `docs/adr/`、それ以外は `.mjun/steering/adr/`) があれば [共通記録規則](../mjun-steering/references/glossary_and_adr.md) に従って有効なものを読む。`## Decisions` に `ADR: 要作成 (ADR-NNNN を覆す)` の判断があれば、覆されるADRは有効なADRとして扱わない (supersededの追記は最終検証の前に行う)。taskに関係する判断の内容は、Phase 3の受け渡しファイルでSubAgentへ渡す (SubAgentに `.mjun/specs/` を読ませない)。

doc modeでもADRがあれば有効なものを読み、関係する内容をSubAgentへ渡す。

### Issue番号の逆引き

Issueの取り込みと磨き上げはspec作成側の仕事であり、Issueが直行で実装できる品質かの判断をこのskillで肩代わりしない。

1. activeなspec (`status: active`) から `Source: #<number>` を持つspecを検索する。見つかればそれを対象にする (複数ヒットした場合は一覧を提示して選んでもらう)
2. activeに無ければ、doneのspecからも `Source: #<number>` を検索する。見つかれば「実装済みのspec (`<path>`) がある。再開する場合は `status` を `active` へ戻すか、Issueを取り込み直す」と案内して中止する
3. どちらにも無ければ中止し、Issueを先にLocal specへ取り込んで磨き上げる必要があることを案内する

**Local specの参照と更新は、常にメインrepositoryの絶対パスで行う。** `.mjun/` はgit管理外のため新規のworktreeやPR checkoutには存在しない。Phase 2でworktree内にメインrepositoryの `.mjun/` へのsymlinkを張り、worktree内のcwdから相対パスで参照しても同じファイルを指すようにする。SubAgentへはspecの内容をPhase 3の受け渡しファイル (`.mjun/runs/` 配下) へ写して渡し、`.mjun/specs/` を読ませない。

## Task

### Phase 1: 内容検査とtaskキュー構築

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner` (Local spec / doc modeでghが失敗する場合は `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
   - source本文 (source種別に従う)
   - 現在のbranch: `git branch --show-current`、既存worktree: `git worktree list --porcelain`
   - メインrepositoryのroot (`<repo-root>`): `git rev-parse --path-format=absolute --git-common-dir` の親ディレクトリ。起動場所がworktreeの中でもメインのcheckoutを指す
2. 出力言語をrepositoryの慣習から決める: 既存のPR・commit message・READMEの言語に合わせ、判別できなければ英語とする。specや依頼の言語には合わせない。コメント、commit、PR作成に使う
3. **内容検査**:
   1. **contract承認とdesign.md** (spec modeのみ): `spec.md` のfrontmatterが `approval: approved` か確認する。値が無い、または `pending` の場合は中止し、contractの承認が先に必要であることを案内する。実装依頼そのものをcontract承認の代わりにしない。`design.md` が無い場合も中止し、実装設計の作成が先に必要であることを案内する。`tasks.md` が無い場合も中止し、`mjun-to-tasks` でtaskへ分解する必要があることを案内する (このskillでは分解しない)
   2. **情報の充足** (doc modeのみ): Goal、受け入れ基準、実装方針など、実装に必要な情報が揃っているか。コードを読めば確認できる事実は自分で解決する。仕様や方針の判断に必要な情報が欠けている場合は中止し、欠落情報を項目立てて具体的に伝え、specを詰め直す必要があることを案内する。方針を推測で補って実装に進まない。spec modeではcontractの十分性をspec作成側のレビューと承認で確定済みとし、ここで判定し直さない
   3. **要確認の残留**: `design.md` の `## Decisions` (doc modeでは本文の要確認記載) に `Status: tentative` (要確認) の暫定決定が残っていないか。spec作成側が承認前にtentativeを解消するため、ここで残っているのは承認後に `design.md` が編集された場合などに限る。残っていれば一覧を提示し、このまま進めてよいかをユーザーに確認する。続行が選ばれた場合は、該当decisionの `Status:` 行を消して `Owner: human` にしてから進む (再実行時に同じtentativeで止まらない)
   4. **Issueとの乖離**: `Source: #N` を持つspecでは `gh issue view <N> --json state,body,comments` で最新を取得する。Issueが**closedなら実装済みの可能性を警告**して続行を確認する。取り込みと投影の後に付いた新しいコメントや本文の変更があれば内容を提示し、specへ反映してから進むか、このまま進むかを確認する。反映する場合は `approval: pending` へ戻してから反映し、更新後のcontractを提示して承認を得て `approved` へ更新してから進む。承認されなければ中止し、specの磨き直しが必要であることを案内する
   5. **spec間依存** (spec modeのみ): BoundariesのDependenciesに `spec: <slug>` の行があれば `.mjun/specs/<slug>/spec.md` を読み、`status: done` を確認する。specが存在しない、またはdoneでない場合は中止し、先に該当specの配送が必要であることを案内する
4. **taskキューを構築する**:
   - spec modeでは `tasks.md` をキューとして採用する。`Status: done` のtaskは**完了扱いでスキップする** (中断後のresume)。`Status: blocked` のtaskは `Resume when` が現在満たされたと確認できた場合だけ `ready` へ戻し、それ以外はblocked一覧へ残す
   - 採用したtaskのうちAcceptance Criteriaが8件を超えるものは、`mjun-to-tasks` の粒度の基準を外れている。Phase 3.0を待たず、該当taskのIDを文脈として `mjun-to-tasks` を連結して `tasks.md` を再分解させ、再分解後の `tasks.md` をキューとして読み直す。粒度の基準の免除をユーザーに求めて、そのまま進めない
   - 全taskが `done` の場合も終了せず、記録済みbranchからresumeしてPhase 3.3の最終検証とPhase 4の配送を再実行する
   - doc modeでは [mjun-to-tasks の分解規則](../mjun-to-tasks/SKILL.md#分解規則) とTask形式に従って会話内のキューを作り、Local specの `tasks.md` は作らない
   - 各taskの受け入れ基準、Boundary (specにBoundariesがある場合)、Done when、Seamを確認し、依存順 (Blocked by) に並べる。`Blocked by` の全taskが `done` か、同じgroupで先に並ぶtaskであるtaskだけを実行可能とし、blocked taskに依存するtaskは実行せず依存待ち一覧へ残す
   - **task groupへ区切る**: groupがPhase 3.0〜3.1の単位 (implementer、reviewer、commit。必要なtaskだけ先にverifierを使う) となる。groupはverifier・implementer・reviewer・検証・commitの固定コストを毎回伴うため、上限まで詰める。依存順に並べたキューを先頭から走査して現在のgroupへ加え、加えるとtask 8件またはAcceptance Criteria合計24件を超えるときだけ新しいgroupを始める (implementerが1つのfresh contextで扱える大きさ)。BoundaryやModuleが違うことは、groupを区切る理由にしない。groupは依存順に直列で処理するため、先行groupのtaskは処理時点でdoneになっている。単一taskのgroupも同じ手順で扱う
5. `--pr` / `--no-pr` / `--merge` が未指定なら、ここでAskUserQuestionにより配送方法を確認する (使えない環境では選択肢をテキストで提示する)。手順1の `gh repo view` が失敗した (GitHub remoteが無い) 場合はPRを作れないため、`--no-pr` と `--merge` の2択で確認する
6. 実装方針とtask一覧 (group区切り付き) を**簡潔に**提示し、確認を取らずPhase 2へ進む

### Phase 2: worktreeの作成

**起動場所のworktreeを採用する場合**: 次をすべて満たすときは、起動場所のworktreeとそのbranchをこの実行のworktreeとbranchとして採用する。orchestratorなどの呼び出し元が、このtask用に用意したworktreeである。

- 起動場所がlinked worktreeである (`git rev-parse --git-dir` と `git rev-parse --git-common-dir` が異なる)
- checkoutしているbranchがbase branchではない
- `git status --porcelain` が空である
- spec modeの `tasks.md` に `Implementation Branch:` が無いか、そのbranchと同じである

採用したら手順1〜3と手順4のworktree作成を省き、手順4の `.mjun` のsymlinkと手順5・6を行う。条件を満たさなければ、起動場所に関係なく手順1から行う。

1. **branch名候補を決定する**: 形式は `<type>/<slug>` (specが `Source: #N` を持つ場合は `<type>/<N>-<slug>`)。`<type>` はConventional Commitsの種別 (`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`)、`<slug>` はタイトルからkebab-case (英数字とハイフン、40文字以内)
2. **resumeの判定**: spec modeの `tasks.md` に `Implementation Branch: <branch-name>` があり、そのlocal branchが存在すれば、taskのstatusにかかわらず前回実行のbranchとして使う。記録されたlocal branchが存在しない場合は、記録を破棄して新規実行として続行する (branch削除後の自己修復)。記録が無い場合は新規実行とし、branch名候補が既存branchと衝突すれば末尾に `-2`, `-3` を付けて回避する。doc modeは常に新規実行とする
3. **worktreeのパス**: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
4. **worktree作成**:
   - resumeの場合は、Phase 1で取得した `git worktree list --porcelain` から `<branch-name>` をcheckout済みのworktreeを探す。見つかればそのパスを採用し、worktree作成をスキップする (PR作成失敗時に保持したworktreeの再利用)。未commit変更が残っている場合は中止して報告する。見つからなければ `git worktree add <worktree-path> <branch-name>` で既存branchをcheckoutする
   - 新規の場合は `git worktree add -b <branch-name> <worktree-path> <base-branch>` (`<base-branch>` は最新のdefault branch)
   - 作成失敗時は中止してエラーを伝える
   - 作成後 (resumeで既存worktreeを採用した場合も)、`<worktree-path>/.mjun` が無ければ `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る。`.mjun/` はgit管理外でworktreeに無いため、symlinkが無いとworktree内のcwdから相対パスで行った `tasks.md` などの更新が失われる
5. spec modeでは、worktree作成成功後に `tasks.md` のtask内容を変えず、先頭の `Implementation Branch: <branch-name>` を設定し、`## Implementation Notes` と `## Run Log` が無ければ末尾に追加する
6. branch名、worktreeパス、base branch名を記録する (クリーンアップで使う)

### Phase 3: 実装

実装はSubAgentで行う。受け渡しはすべてメイン会話が構造化ブロックをパースして仲介する。SubAgentへの文脈は、下の「受け渡しファイル」で渡す。
verifier、reviewer、debugger、refactorerは毎回新規に起動する (fresh context)。implementerはgroupごとに1回起動し、同じgroupの差し戻し・裁定・不足情報の補充は**同じimplementerを継続して** (send_message / resume等) 行う。継続できない環境では新規に起動し、失敗した試行の履歴は含めず `REMEDIATION` など修正に必要な情報と、前回の方針の要約1行だけを渡す。

役割は5つある。

- **implementer** ([templates/implementer-prompt.md](templates/implementer-prompt.md)): groupの全taskの実装と必要な検査の作成・実行を担い、`## Status Report` を返す。通常は実装後に検証してよく、TDDを強制しない。バグ修正では修正前に再現テストを書いて失敗を確認し、修正後に通す
- **reviewer** ([templates/reviewer-prompt.md](templates/reviewer-prompt.md)): 全Acceptance Criterionを実装と検査に照合し、検査の実行結果、保護された検査ファイルの不変、実在性、Boundaryを敵対的に検証して `## Review Verdict` を返す
- **verifier** ([templates/verifier-prompt.md](templates/verifier-prompt.md)): 検査を先に独立して設計する必要があるtaskだけを担当する。ユーザー・specが独立した事前検査を指定しているか、期待値や検証手段を実装から独立に確定する必要について親が具体的な理由を示せる場合に使う。バグ修正や複雑なロジックという分類だけでは起動しない。対象taskの未充足の振る舞いはRED、回帰検査はGREENで採用し、種別・根拠・実行結果を記録する。検査ファイルをformatterとlintに通してから、Task Briefと一緒に `## Check Report` を返す
- **debugger** ([templates/debugger-prompt.md](templates/debugger-prompt.md)): 差し戻しが収束しない、またはBLOCKEDのときに、fresh contextでroot causeを分類し `## Debug Report` を返す
- **refactorer** ([templates/refactorer-prompt.md](templates/refactorer-prompt.md)): 全task完了後、reviewerのNOTESとtask間の重複を全検査greenのまま整理し、`## Refactor Report` を返す

### 受け渡しファイル

SubAgentへの文脈は、親が書いたファイルで渡す。LLMは入力を読むより出力を書くほうがずっと遅く、テンプレートやcontractを起動のたびにpromptへ書き写すと、その時間がすべて待ちになる。

- 受け渡しディレクトリ (`<run-dir>`) は `<repo-root>/.mjun/runs/<branch-name>/` とする (Git管理外)。最初のSubAgentを起動する前に作り、使うroleのテンプレート (`<skill-dir>/templates/<role>-prompt.md`) と、contract (spec modeでは `spec.md`、doc modeではsourceのMarkdown) を `contract.md` として `cp` で置く。spec modeでは `design.md` も置き、親が `design.md` を更新したら置き直す
- groupごとに `<run-dir>/<group>/brief.md` を1回だけ書く。中身は、groupの各task (ID、説明、Boundary、Done when、Seam、Blocked by、Acceptance Criteria)、Phase 1の実装方針、`TASK_BRIEF`、採用済みの `CHECK_FILES` / `CHECK_COMMANDS`、`PROTECTED_CHECK_FILES` とハッシュ、事前検査の `CHECK_BASELINES`、review-onlyのtask、関係するdecisionと有効なADR、`design.md` の該当部分のセクション名、groupに関係する検証コマンド、Implementation Notes (既知のflakyテストを含む) とする。検査の一覧などが変わったら、次のSubAgentを起動する前に更新する
- `design.md` の該当部分は、groupのtaskのBoundaryに対応するModules、Seamに対応するInterfaces & Seams、それらを通るData Flow、Test Strategy、Change Outlineの全体とする。対応を判断できないセクションは全体を含める
- 起動promptは次の形にする。ファイルの内容は書き写さず、本文にはそのroleにだけ渡すものを書く

  ```text
  mjun-implementの<role>として作業する。役割と手順は <run-dir>/<role>-prompt.md に従う。
  - worktree: <worktreeの絶対パス> (base: <base branch>、branch: <作業branch>)
  - contract: <run-dir>/contract.md
  - 実装設計: <run-dir>/design.md (spec modeのみ)
  - group: <run-dir>/<group>/brief.md
  <このroleへの差分: 対象task、周回、前回のFINDINGSとREMEDIATION、親の検査結果のパスなど>
  ```

- SubAgentには、`<run-dir>` のファイルとworktreeだけを読ませる。`.mjun/specs/` は読ませない

SubAgentを起動するたびに、roleに応じたmodelとeffortを [references/subagent.md](references/subagent.md) に従って指定する。この指定は環境のグローバル指示のモデル指針より優先する。

実装を始める前に、リポジトリから正規の検証コマンドを洗い出し、`TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` / `SMOKE_COMMANDS` として保持する。探索順は `.mjun/steering/` の記述 → manifest類 → タスクランナー → CI設定 → README。リポジトリの自動化が既に使っているコマンドを優先する。`SMOKE_COMMANDS` (起動して最初の利用可能な状態に達することを確かめるコマンド) は宣言されているものだけを使い、無ければ空のままにしてPhase 3.3で各taskの検査から代用する。

Phase 3の間の制約:

- verifier、implementer、reviewer、debugger、refactorerはleaf roleとし、SubAgentを起動せず、担当作業を別Agentへ再移譲しない。自分で完了できない場合はrole固有の構造化結果で親へ返し、追加の委譲は親だけが判断する
- ループ内で `git reset --hard` 等の破壊的リセットを行わない (例外はPhase 3.2で整理の変更だけを戻す場合のみ)
- pushとPR作成はPhase 4まで行わない。commitはgroup承認ごとにメイン会話が行う (Phase 3.1)。SubAgentにはcommitさせない
- SubAgentの完了主張を検証の代わりにしない。判定は構造化フィールドと、検査・reviewer・最終検証の実行結果だけで行う
- 構造化値が無い、または曖昧なときの再要求は、作業したSubAgentを継続して行う (SendMessage等)。継続できない環境では、ブロックだけを別のSubAgentに求めず、そのroleを最初からやり直す (作業していないagentが返すブロックは捏造になる)
- SubAgentの報告で `NOT_RUN` の項目は、親が該当コマンドを実行して埋める。推測で埋めない
- 親が実行する検査は、すべて `zsh <skill-dir>/scripts/run_checks.sh <worktree> <run-dir> <name> <commands-file>` で行う (`<name>` は `G2-r1` のような実行ごとの名前、`<commands-file>` は1行1コマンドのファイル)。scriptはworktreeの内容の指紋 (commitしても変わらない) ごとに成功を記録し、同じ内容で成功済みのコマンドは実行せず `CACHED (PASS)` と返す。SubAgentには要約 (`summary.md`) とログのパスを渡し、出力を書き写さない。親は失敗したコマンドのログだけを読む。`FAIL (worktreeを書き換えた)` は、検査がformatterの自動修正やlockfileの更新などの変更を生んだことを示すので、失敗と同じに扱う。toolのtimeoutに収まらない見込みのコマンドは、commands-fileを分けて別々に実行する
- `CHECK_FILES` は採用した検査ファイル全体、`CHECK_COMMANDS` はAcceptance Criterionごとの検証コマンドとする。verifierが書いたファイルだけを `PROTECTED_CHECK_FILES` に登録し、verifier以外に変更させない。親はその作成直後にハッシュ (`shasum -a 256`) を記録し、reviewerが照合する。implementerは保護対象以外の検査を作成・修正でき、変更の妥当性はreviewerがAcceptance Criteriaから判定する。後続groupで検査を直す場合も、保護対象はverifier経由で更新してハッシュを記録し、それ以外はimplementerが直してreviewerが確認する。期待値を実装に合わせて弱めず、更新したファイル・コマンドと理由をRun Logに記録する
- ユーザーの指示で手順の一部を変える場合も、role、テンプレート、構造化ブロック、回数の上限はそのまま使い、独自の役割名や報告形式を作らない。複数groupを同じworktreeで並列に実装しない (Phase 3.1)
- 実行中にcontractに無い追加要求を受けた場合は、`spec.md` を直接書き換えて実装に入らない。現在のgroupを終えた時点で止め、specの磨き直し (承認を含む) が先に必要であることを案内する
- CIのrunなど数分以上かかる外部の完了待ちは、完了まで戻らない待機コマンドを1本だけ実行して待つ。短い間隔の再確認や、時間切れごとの待機の張り直しを繰り返さない

#### Phase 3以降の手順

Phase 3以降の手順は、必要になった時点で次のファイルを読む。読んでいない手順を記憶で補わない。

- [references/subagent.md](references/subagent.md): roleごとのSubAgentのmodelとeffort、implementerの昇格条件。最初のSubAgentを起動する前に読む
- [references/group-loop.md](references/group-loop.md): Phase 3.0 (実装準備と必要な事前検査) とPhase 3.1 (実装とレビュー)、Run Logの形式。最初のgroupを始める前に読む
- [references/recovery.md](references/recovery.md): taskの隔離とblocked、Phase 3.1' (debuggerによる原因調査)。implementerが `BLOCKED` を返した、差し戻しが2周に達した、taskをblockedへ移す、task計画を直す、のいずれかのときに読む
- [references/validation-and-delivery.md](references/validation-and-delivery.md): Phase 3.2 (ADRと整理)、Phase 3.3 (feature単位の検証)、Phase 4 (commitと配送)、Phase 5 (結果の表示)、Phase 6 (worktreeクリーンアップ)。実行可能なtaskが尽きたときに読む

完了の定義 (`COMPLETE`): 全taskが `done` で、Phase 3.3の判定が `GO` または `MANUAL_VERIFY_REQUIRED` である。そのうえで選ばれた配送方法で届け、Phase 5の結果を表示し、Phase 6でworktreeを片付けた状態を指す。doneでないtaskが残る場合は `PARTIAL` として、Phase 5とPhase 6だけを行う。エラーやユーザーの中止で途中終了する場合も、Phase 6は必ず実行する。
