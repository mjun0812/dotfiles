---
name: mjun-implement
description: >-
  承認済みのspec (`.mjun/specs/` のLocal spec、GitHub Issue番号、または単発の設計doc) や、mjun-startが書いたbrief (`.mjun/briefs/`) を起点に、task group単位の実装からAcceptance Criteriaの照合、commit、必要ならPR作成までを一気通貫で行うSkill。
  ユーザーが「#Nを実装して」「このspecを実装して」「実装してPRまで」のように依頼したら使うこと。
  specの作成・磨き上げ・承認や、未取り込みIssueの取り込みには使わない。
  spec・brief・設計docのどれも無い作業の依頼にも使わない (mjun-startが作業の種類を振り分ける)。
  呼び出し元から作業指示を渡された実装担当 (SubAgentやorchestratorのworker) は、指示がこのSkillの実行を明示しているときだけ使い、それ以外はその指示に従う。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(shasum:*), Bash(zsh:*), AskUserQuestion, Skill(git-commit), Skill(github-pr-create), Skill(github-issue-create), Skill(mjun-to-tasks), Skill(mjun-start)
---

# mjun-implement

承認済みのspecを、task groupごとの実装・レビュー・commitを経て、選ばれた方法 (PR、local commit、fast-forward merge) で届けるSkill。
メイン会話 (以下、親) は、検査、worktree、SubAgentへの受け渡し、進捗の永続化、結果の検証、片付けを担う。実装 (Phase 3) はSubAgentに任せ、commitとPR作成 (Phase 4) は `git-commit` skillと `github-pr-create` skillに任せる。

全Phaseを通して、次のことを守る。

- SubAgentの完了主張を検証の代わりにしない。判定は、親が `run_checks.sh` で実行した検査、reviewerの判定、親自身の照合の結果だけで行う。報告をそのまま信じると、検証を経ていない変更がcommitされる
- repositoryに残るもの (コード、コメント、テスト名、ファイル名) とGitHubへ出すもの (commit message、PRのタイトルと本文) に、spec内部の識別子 (task ID、AC番号、Requirement番号、`.mjun/` のパス、`spec.md` / `tasks.md`) を書かない。specはrepositoryに無い内部文書で、番号は再分解で変わる。`zsh <skill-dir>/scripts/check_internal_ids.sh` (以下、ID検査) で機械的に確かめ、検出されたら振る舞いや目的を表す言葉に書き換える
- 実装をcontractのBoundariesとOut of Scopeの外へ広げない。contractに無い追加要求を受けても `spec.md` を書き換えて実装に入らず、現在のgroupを終えた時点で止めて、specの磨き直し (承認を含む) が先に必要であることを案内する。contractは人間が承認した範囲であり、実装側で広げると、承認を経ていない変更が入る
- task計画の作り直しは `mjun-to-tasks` に任せる。分解規則はこのskillに持たない

## Arguments

- `source` (必須): 実装対象。GitHub Issue番号 (`#123` / `123`)、`.mjun/specs/<slug>` のLocal specディレクトリ、`.mjun/briefs/<slug>.md` のbrief、または単発Markdownのパス
- `--pr` / `--no-pr` / `--merge` (任意): 実装をPRとして届けるか、local commitまでで終えるか、base branchへfast-forward mergeして届けるか。いずれも未指定なら、worktree作成前に確認する (長時間の自律実装の最後で確認待ちにしない)

### source種別

- `.mjun/specs/<slug>` のディレクトリ、またはその配下のファイルパス → spec mode
- Issue番号またはGitHub URL → 取り込み済みspecへの逆引き (下記) を経てspec mode
- `.mjun/briefs/<slug>.md` → doc mode。mjun-startがバグ修正・refactoring・性能改善のために書いたbriefで、frontmatterの `kind` (`bug` / `refactor` / `perf`) によって、Phase 3でimplementerとreviewerに渡す観点が変わる
- その他のMarkdownパス → doc mode。ファイル全文 (frontmatterを除く) を起点とする
- spec・brief・設計docのどれも無い作業の依頼を渡されたら、依頼内容を添えてmjun-startへ渡し、このskillを終える。作業の種類によって進め方の重さが違うので、振り分けはmjun-startが持つ

spec modeでは、specディレクトリ配下の `spec.md`、`design.md`、`tasks.md` を読む。specの判断は `design.md` の `## Decisions` にある。どちらのmodeでも、ADR (置き場所は [共通記録規則](../mjun-steering/references/glossary_and_adr.md#置き場所の決め方) で決まる `docs/adr/` か `.mjun/steering/adr/`) があれば [共通記録規則](../mjun-steering/references/glossary_and_adr.md) に従って有効なものを読む。`## Decisions` に `ADR: 要作成 (ADR-NNNN を覆す)` の判断があれば、覆されるADRは有効なADRとして扱わない (supersededの追記はPhase 3.2で行う)。taskに関係する判断とADRは、Phase 3の受け渡しファイルでSubAgentへ渡す。

### Issue番号の逆引き

Issueの取り込みと磨き上げはspec作成側の仕事であり、Issueが直接実装できる品質かをこのskillで判断しない。

1. activeなspec (`status: active`) から `Source: #<number>` を持つものを探す。見つかればそれを対象にする (複数あれば一覧を示して選んでもらう)
2. 無ければ、Issue番号を添えてmjun-startへ渡し、このskillを終える。`status: done` のspecは作業を終えた使い捨ての文書で、残っていても参照しない (ユーザーが手で削除する)。mjun-startが、新規機能ならmjun-specifyでの取り込みへ、バグ修正などならbriefを書いてこのskillへ戻す

Local specの参照と更新は、メインrepositoryの絶対パスで行う。`.mjun/` はgit管理外なので、新規のworktreeには存在しない。Phase 2でworktree内に `.mjun` へのsymlinkを張り、相対パスでも同じファイルを指すようにする。

## Task

### Phase 1: 内容検査とtaskキュー構築

実装に入ってよいかを確かめ、taskキューとgroupを組み、どこまで進めるか (PR作成 / commit / base branchへのmerge) を決める。

1. 状況を集める
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner`。ghが使えなければ `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranchをbaseとする
   - source本文、現在のbranch、`git worktree list --porcelain`
   - メインrepositoryのroot (`<repo-root>`): `git rev-parse --path-format=absolute --git-common-dir` の親ディレクトリ。起動場所がworktreeでもメインのcheckoutを指す
2. 出力言語は、repositoryの既存のPR・commit message・READMEに合わせる (判別できなければ英語)。specや依頼の言語には合わせない。コメント、commit、PRに使う
3. 内容検査。次のどれかに当たれば止める。実装依頼そのものを承認の代わりにしない。spec modeでは先に `zsh <skill-dir>/../mjun-to-tasks/scripts/check_spec_format.sh <spec-dir>` で形式を検査し、指摘を次のように振り分ける。tentativeとAC件数の指摘は、下の該当項目と手順4で扱う。taskの形式の指摘 (見出し、フィールド、Statusの語彙、Blocked byの実在と循環) は、指摘を文脈に `mjun-to-tasks` で書き直させてから検査し直す。書き直しは1回までとし、それでも残れば指摘を示して中止する。`spec.md` と `design.md` の形式の指摘は、specの磨き直しが要ると案内して中止する
   - spec modeで、`spec.md` が `approval: approved` でない、または `design.md` か `tasks.md` が無い。中止して、contractの承認、実装設計の作成、`mjun-to-tasks` での分解のうち足りないものを案内する
   - doc modeで、Goal、受け入れ基準、実装方針など、方針の判断に要る情報が欠けている。コードを読めば分かる事実は自分で調べる。方針を推測で補わず、欠けている項目を具体的に挙げて中止する。briefでは、種類ごとの節、`完了条件`、`範囲` がそろっていれば足りる (実装方針はimplementerが決める)。spec modeのcontractの十分性は承認で確定済みなので、ここで判定し直さない
   - `## Decisions` (doc modeでは本文の要確認の記載) に `Status: tentative` が残っている。承認前に解消されるはずのものなので、一覧を示して進めてよいかをユーザーに確認する。続行が選ばれたら、該当decisionの `Status:` 行を消して `Owner: human` にする。再実行のたびに同じ箇所で止まらないためである
   - `Source: #N` を持つspecで、`gh issue view <N> --json state,body,comments` が取り込み後の変化を示す。closedなら実装済みの可能性を警告して続行を確認する。新しいコメントや本文の変更があれば内容を示し、specへ反映するかを確認する。反映するなら `approval: pending` へ戻してから反映し、更新後のcontractの承認を得て `approved` に戻す。承認されなければ中止する
   - `Source: #N` を持つbriefで、Issueがclosedになっている。実装済みの可能性を警告して続行を確認する
   - spec modeで、BoundariesのDependenciesにある `spec: <slug>` のspecが `status: active` のまま残っている。先にそのspecの実装を終える必要があると案内して中止する。`status: done` か、存在しない (作業を終えた後に手で削除された) specは、依存を満たしたものとして扱い、そう判断したことを実装方針と一緒に示す
4. taskキューを組む
   - spec modeでは `tasks.md` をキューにする。`Status: done` のtaskは完了扱いで飛ばす (resume)。`Status: blocked` のtaskは、`Resume when` が満たされたと確認できたものだけ `ready` に戻す
   - Acceptance Criteriaが8件を超えるtask (手順3の形式検査が件数で指摘する) は `mjun-to-tasks` の粒度を外れている。そのtask IDを文脈として `mjun-to-tasks` で再分解させ、読み直したキューを使う
   - 全taskが `done` でも終了しない。記録済みbranchからresumeし、Phase 3.3とPhase 4をやり直す
   - doc modeでは [mjun-to-tasks の分解規則](../mjun-to-tasks/SKILL.md#分解規則) とTask形式で会話内のキューを作る。`tasks.md` は作らない
   - 依存順 (Blocked by) に並べる。実行できるのは、`Blocked by` の全taskが `done` か、同じgroupで先に並ぶtaskだけである。blocked taskに依存するtaskは依存待ちに残す
   - groupに区切る。groupごとにverifier・implementer・reviewer・検査・commitの固定コストがかかるので、上限まで詰める。上限はtask 8件、Acceptance Criteria合計24件 (implementerが1つのfresh contextで扱える大きさ) とし、キューの先頭から加えて上限を超えるときだけ次のgroupを始める。BoundaryやModuleの違いは区切る理由にしない
5. どこまで進めるかが未指定なら、AskUserQuestion (使えなければテキストの選択肢) で確認する。GitHub remoteが無ければ `--no-pr` と `--merge` の2択にする。`## Decisions` に `ADR: 要作成` があり、ADRの置き場所が未決定 ([置き場所の決め方](../mjun-steering/references/glossary_and_adr.md#置き場所の決め方)) なら、置き場所も同じ確認で聞く。自律実行の途中で確認待ちにしないためである
6. 実装方針とgroup区切り付きのtask一覧を簡潔に示し、確認を取らずにPhase 2へ進む

### Phase 2: worktreeの作成

起動場所が、呼び出し元 (orchestratorなど) がこのtaskのために用意したworktreeなら、それを使う。次をすべて満たすときがそれに当たる。

- linked worktreeである (`git rev-parse --git-dir` と `--git-common-dir` が異なる)
- checkoutしているbranchがbase branchではない
- `git status --porcelain` が空である
- spec modeの `tasks.md` に `Implementation Branch:` が無いか、そのbranchと同じである

この場合は手順4の `.mjun` のsymlinkと手順5・6だけを行う。満たさなければ手順1から行う。

1. branch名候補: `<type>/<slug>` (specかbriefが `Source: #N` を持てば `<type>/<N>-<slug>`)。`<type>` はConventional Commitsの種別 (briefの `kind` が `bug` なら `fix`、`refactor` なら `refactor`、`perf` なら `perf`。判別できなければ `feat`)、`<slug>` はタイトルのkebab-case (英数字とハイフン、40文字以内)
2. resumeの判定: spec modeの `tasks.md` に `Implementation Branch: <branch-name>` があり、そのlocal branchが存在すれば、それを使う。記録されたbranchが無ければ記録を破棄して新規として続ける。新規ではbranch名の衝突を末尾の `-2`, `-3` で避ける。doc modeは常に新規とする
3. worktreeのパス: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>` (衝突したら末尾に `-2`, `-3`)
4. worktreeを用意する
   - resumeでは、そのbranchをcheckout済みのworktreeがあれば再利用する (PR作成に失敗して残したもの)。未commit変更が残っていれば中止して報告する。無ければ `git worktree add <worktree-path> <branch-name>`
   - 新規では `git worktree add -b <branch-name> <worktree-path> <base-branch>` (最新のdefault branchから)
   - 作成に失敗したら中止する
   - `<worktree-path>/.mjun` が無ければ `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る。無いと、worktree内から相対パスで行った `tasks.md` の更新が失われる
5. spec modeでは、`tasks.md` のtask内容を変えずに、先頭へ `Implementation Branch: <branch-name>` を設定し、`## Implementation Notes` と `## Run Log` が無ければ末尾に足す
6. branch名、worktreeパス、base branchを覚えておく (Phase 6で使う)

### Phase 3: 実装

実装はSubAgentが行い、受け渡しは親が構造化ブロックをパースして仲介する。

role:

- implementer ([templates/implementer-prompt.md](templates/implementer-prompt.md)): groupの全taskを実装し、必要な検査を作って実行し、`## Status Report` を返す。TDDは強制しない。バグ修正だけは、修正前後の証拠 (再現テスト、届かなければ実物での観察か計測) を取る
- reviewer ([templates/reviewer-prompt.md](templates/reviewer-prompt.md)): 親の検査結果と実際のコードで、全Acceptance Criterion、保護された検査ファイルの不変、実在性、Boundaryを敵対的に確かめ、`## Review Verdict` を返す
- verifier ([templates/verifier-prompt.md](templates/verifier-prompt.md)): 検査を実装より先に、独立して設計する必要があるtaskだけを担当し、`## Check Report` を返す。使うのは、ユーザーかspecが独立した事前検査を指定しているときか、期待値や検証手段を実装から独立に確定すべき具体的な理由を親が示せるときである。「バグ修正」「複雑なロジック」という分類だけでは使わない
- debugger ([templates/debugger-prompt.md](templates/debugger-prompt.md)): 差し戻しが収束しないとき、またはBLOCKEDのときに、root causeを分類して `## Debug Report` を返す
- refactorer ([templates/refactorer-prompt.md](templates/refactorer-prompt.md)): 全task完了後、reviewerのNOTESとtask間の重複を、全検査greenのまま整理して `## Refactor Report` を返す

verifier、reviewer、debugger、refactorerは毎回新しく起動する (fresh context)。implementerはgroupごとに1回起動し、同じgroupの差し戻し・裁定・情報の補充は同じimplementerを継続して (SendMessageなど) 行う。継続できない環境では新しく起動し、失敗した試行の経緯は渡さず、`REMEDIATION` など修正に要る情報と、前回の方針の要約1行だけを渡す。

SubAgentを起動するたびに、roleに応じたmodelとeffortを [references/subagent.md](references/subagent.md) に従って指定する。この指定は環境のグローバル指示のモデル指針より優先する。

#### 受け渡しファイル

SubAgentへの文脈は、親が書いたファイルのパスで渡す。LLMは入力を読むより出力を書くほうがずっと遅く、テンプレートやcontractを起動のたびにpromptへ書き写すと、その時間がすべて待ちになる。

- 受け渡しディレクトリ `<run-dir>` は `<repo-root>/.mjun/runs/<branch-name>/` (Git管理外) とする。最初のSubAgentを起動する前に作り、`cp` で次を置く
  - 使うroleのテンプレート (`<skill-dir>/templates/<role>-prompt.md`) と、全roleに共通の約束 `<skill-dir>/templates/common.md`
  - contract (spec modeでは `spec.md`、doc modeではsourceのMarkdown) を `contract.md` として
  - spec modeでは `design.md`。親が `design.md` を更新したら置き直す
  - briefなら、`kind` に対応する観点 `<skill-dir>/templates/kind-<kind>.md`。spec modeでも、バグ修正のtaskを含むgroupでは `kind-bug.md` を置く。種類ごとに重視する確かめ方 (バグ修正の再現と原因、refactoringの振る舞い不変、性能改善の計測) を、implementerとreviewerにそろえて渡すためである
- groupごとに `<run-dir>/<group>/brief.md` を書く。中身は、groupの各task (ID、説明、Boundary、Done when、Seam、Blocked by、Acceptance Criteria)、Phase 1の実装方針、`TASK_BRIEF`、採用済みの `CHECK_FILES` / `CHECK_COMMANDS`、`PROTECTED_CHECK_FILES` とハッシュ、事前検査の `CHECK_BASELINES`、review-onlyのtask、関係するdecisionと有効なADR、`design.md` で読むべきセクション名、groupに関係する検証コマンド、Implementation Notes (既知のflakyテストを含む)。検査の一覧などが変わったら、次のSubAgentを起動する前に書き直す
- `design.md` で読むべきセクションは、groupのtaskのBoundaryに対応するModules、Seamに対応するInterfaces & Seams、それらを通るData Flow、Test Strategy、Change Outlineの全体とする。対応を判断できないセクションは含める
- 起動promptは次の形にする。ファイルの内容は書き写さず、本文にはそのroleだけに渡すものを書く

  ```text
  mjun-implementの<role>として作業する。役割と手順は <run-dir>/<role>-prompt.md、全roleに共通の約束は <run-dir>/common.md に従う。
  - worktree: <worktreeの絶対パス> (base: <base branch>、branch: <作業branch>)
  - contract: <run-dir>/contract.md
  - 実装設計: <run-dir>/design.md (spec modeのみ)
  - 種類の観点: <run-dir>/kind-<kind>.md (置いた場合だけ。implementerとreviewer)
  - group: <run-dir>/<group>/brief.md
  <このroleへの差分: 対象task、周回、前回のFINDINGSとREMEDIATION、親の検査結果のパスなど>
  ```

- SubAgentには `<run-dir>` のファイルとworktreeだけを読ませ、`.mjun/specs/` は読ませない。specの中で渡す範囲を親が決めるためである

#### 検証コマンドと検査

実装を始める前に、repositoryの正規の検証コマンドを `TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` / `SMOKE_COMMANDS` として洗い出す。`.mjun/steering/`、manifest、タスクランナー、CI設定、READMEを見て、repositoryの自動化が既に使っているものを優先する。`SMOKE_COMMANDS` (起動して最初の利用可能な状態に達することを確かめるもの) は宣言されているものだけを使い、無ければ空にする。

親が実行する検査は、すべて `zsh <skill-dir>/scripts/run_checks.sh <worktree> <run-dir> <name> <commands-file>` で行う (`<name>` は `G2-r1` のような実行ごとの名前、`<commands-file>` は1行1コマンドのファイル)。

- scriptはworktreeの内容の指紋 (commitしても変わらない) ごとに成功を記録し、同じ内容で成功済みのコマンドは実行せず `CACHED (PASS)` と返す。だから同じコマンドを後の手順で何度渡しても、内容が変わっていなければ時間はかからない
- SubAgentには要約 (`summary.md`) とログのパスを渡し、出力を書き写さない。親は失敗したコマンドのログだけを読む
- `FAIL (worktreeを書き換えた)` は、formatterの自動修正やlockfileの更新などで内容が変わったことを示す。失敗と同じに扱う
- toolのtimeoutに収まらない見込みのコマンドは、commands-fileを分けて実行する

検査ファイルは次のように扱う。

- `CHECK_FILES` は採用した検査ファイル全体、`CHECK_COMMANDS` はAcceptance Criterionごとの検証コマンドを指す
- verifierが書いたファイルだけを `PROTECTED_CHECK_FILES` とし、verifier以外には変更させない。親は作成直後に `shasum -a 256` でハッシュを記録し、reviewerと親が照合する。実装から独立に決めた期待値を、実装側の都合で書き換えさせないためである
- それ以外の検査はimplementerが作成・修正してよく、妥当性はreviewerがAcceptance Criteriaから判定する
- 後続groupで検査を直すときも同じで、保護対象はverifier経由で直してハッシュを記録し直す。期待値を実装に合わせて弱めず、変えたファイル・コマンドと理由をRun Logに残す

#### Phase 3の間の約束

- SubAgent共通の約束 (再委譲しない、途中経過を送らない、検証コマンドを前面で実行する、commitしないなど) は [templates/common.md](templates/common.md) にある。追加の委譲は親だけが判断する
- commitはgroupの承認ごとに親が行う (Phase 3.1)。pushとPR作成はPhase 4まで行わない
- `git reset --hard` などの破壊的リセットをしない。未commitの成果や他のgroupの変更を失うからである。例外は、Phase 3.2で整理の変更だけを戻す場合である
- 複数groupを同じworktreeで並列に実装しない。どのgroupの未commit変更かを区別できず、保護された検査ファイルのハッシュ照合も成り立たない
- 構造化値が無い、または曖昧なときは、作業したSubAgentを継続して1回だけ再要求する。継続できない環境では、そのroleを最初からやり直す (作業していないagentにブロックだけを書かせると捏造になる)
- SubAgentの報告で `NOT_RUN` の項目は、親が該当コマンドを実行して埋める。推測で埋めない
- ユーザーの指示で手順の一部を変えるときも、role、テンプレート、構造化ブロック、回数の上限はそのまま使う。親が構造化ブロックをパースして動くので、独自の役割名や報告形式を作ると、親が結果を読み取れない
- CIのrunなど数分以上かかる外部の完了待ちは、完了まで戻らない待機コマンドを1本だけ実行して待つ。短い間隔の再確認や、待機の張り直しを繰り返さない

#### Phase 3以降の手順

必要になった時点で次を読む。読んでいない手順を記憶で補わない。

- [references/subagent.md](references/subagent.md): roleごとのmodelとeffort、implementerの昇格条件。最初のSubAgentを起動する前に読む
- [references/group-loop.md](references/group-loop.md): Phase 3.0 (実装準備と必要な事前検査)、Phase 3.1 (実装とレビュー)、Run Logの形式。最初のgroupを始める前に読む
- [references/recovery.md](references/recovery.md): taskの隔離とblocked、Phase 3.1' (debuggerによる原因調査)。次のどれかのときに読む: implementerが `BLOCKED` を返した / 差し戻しが2周に達した / taskをblockedへ移す / task計画を直す
- [references/validation-and-delivery.md](references/validation-and-delivery.md): Phase 3.2 (ADRと整理)、Phase 3.3 (feature単位の検証)、Phase 4 (commitとPR作成・merge)、Phase 5 (結果の表示)、Phase 6 (worktreeクリーンアップ)。実行可能なtaskが尽きたときに読む

完了 (`COMPLETE`) は、全taskが `done` で、Phase 3.3の判定が `GO` または `MANUAL_VERIFY_REQUIRED` である状態を指す。そのうえで選ばれたところまで進め、Phase 5の結果を示し、Phase 6で片付ける。doneでないtaskが残るときは `PARTIAL` として、Phase 5とPhase 6だけを行う。エラーやユーザーの中止で途中終了するときも、Phase 6は必ず行う。
