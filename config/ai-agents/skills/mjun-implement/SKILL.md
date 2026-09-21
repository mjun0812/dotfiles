---
name: mjun-implement
description: >-
  承認済みのspec (`.mjun/specs/` のLocal spec、GitHub Issue番号、または単発の設計doc) を起点に、task group単位の実装からAcceptance Criteriaの照合、commit、必要ならPR作成までを一気通貫で行うSkill。
  ユーザーが「#Nを実装して」「このspecを実装して」「実装してPRまで」のように依頼したら使うこと。
  specの作成・磨き上げ・承認や、未取り込みIssueの取り込みには使わない。
  specも設計docも無く、会話の中で決めた小規模な変更にも使わない (直接実装する)。
  呼び出し元からworktree・commit方針・報告形式を指定した作業指示を渡された実装担当としても使わない (その指示に従う)。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(shasum:*), AskUserQuestion, Skill(git-commit), Skill(github-pr-create)
---

# mjun-implement

specを起点に、内容検査 → 実装 → commit → (必要なら) PR作成までを進めるSkill。
メイン会話が担うのは、検査、worktree作成、SubAgentへの引き継ぎ、進捗の永続化、結果検証、クリーンアップであり、**実装 (Phase 3) はSubAgentに委譲し、commitとPR作成 (Phase 4) は `git-commit` skillと `github-pr-create` skillに連結する**。

## Arguments

- `source` (必須): 実装対象。GitHub Issue番号 (`#123` / `123`)、`.mjun/specs/<slug>` のLocal specディレクトリ、または単発Markdownのパス
- `--pr` / `--no-pr` / `--merge` (任意): 実装をPRとして届けるか、local commitまでで終えるか、base branchへfast-forward mergeして届けるか。**いずれも未指定の場合は、worktree作成前に確認する** (長時間の自律実装の最後で確認待ちにしない)

### source種別

sourceの形からmodeを決める。

1. `.mjun/specs/<slug>` のディレクトリ、またはその配下のファイルパス → **spec mode**
2. Issue番号またはGitHub URL → 取り込み済みspecへの逆引き (下記) を経て **spec mode**
3. その他のMarkdownパス → **doc mode**。ファイル全文を起点とする (frontmatterがあれば除く)

spec modeでは、specディレクトリ配下の `spec.md` と `design.md` (いずれも必須)、あれば `tasks.md` をReadする。共通の `decisions.md` (Git管理へ移行済みなら `docs/adr/decisions.md`、それ以外は `.mjun/steering/decisions.md`) からspec.mdの `Decisions:` が参照するentryとprojectのacceptedな判断を読む。StatusとScopeは [共通記録規則](../mjun-steering/references/glossary_and_adr.md) に従い、参照先の欠落・重複ID・supersededの参照はspecの修正へ戻す。taskに関係する判断の内容をSubAgentへ渡す (SubAgentに `.mjun/` を読ませない)。

doc modeでも共通の決定記録があればprojectのacceptedな判断を読み、関係する内容をSubAgentへ渡す。判断記録が存在せず参照も無い場合は、読み取りだけのために空ファイルを作らない。

### Issue番号の逆引き

Issueの取り込みと磨き上げはspec作成側の仕事であり、Issueが直行で実装できる品質かの判断をこのskillで肩代わりしない。

1. activeなspec (`status: active`) から `Source: #<number>` を持つspecを検索する。見つかればそれを対象にする (複数ヒットした場合は一覧を提示して選んでもらう)
2. activeに無ければ、doneのspecからも `Source: #<number>` を検索する。見つかれば「実装済みのspec (`<path>`) がある。再開する場合は `status` を `active` へ戻すか、Issueを取り込み直す」と案内して中止する
3. どちらにも無ければ中止し、Issueを先にLocal specへ取り込んで磨き上げる必要があることを案内する

**Local specの参照と更新は、常にメインrepositoryの絶対パスで行う。** `.mjun/` はgit管理外のため新規のworktreeやPR checkoutには存在しない。Phase 2でworktree内にメインrepositoryの `.mjun/` へのsymlinkを張り、worktree内のcwdから相対パスで参照しても同じファイルを指すようにする。SubAgentへはspecの内容をプロンプトに合成して渡し、`.mjun/` パスを読ませない。

## Task

### Phase 1: 内容検査とtaskキュー構築

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner` (Local spec / doc modeでghが失敗する場合は `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
   - source本文 (source種別に従う)
   - 現在のbranch: `git branch --show-current`、既存worktree: `git worktree list --porcelain`
2. 出力言語をrepositoryの慣習から決める: 既存のPR・commit message・READMEの言語に合わせ、判別できなければ英語とする。specや依頼の言語には合わせない。コメント、commit、PR作成に使う
3. **内容検査**:
   1. **contract承認とdesign.md** (spec modeのみ): `spec.md` のfrontmatterが `approval: approved` か確認する。値が無い、または `pending` の場合は中止し、contractの承認が先に必要であることを案内する。実装依頼そのものをcontract承認の代わりにしない。`design.md` が無い場合も中止し、実装設計の作成が先に必要であることを案内する
   2. **情報の充足**: Goal、受け入れ基準、実装方針など、実装に必要な情報が揃っているか。コードを読めば確認できる事実は自分で解決する。仕様や方針の判断に必要な情報が欠けている場合は中止し、欠落情報を項目立てて具体的に伝え、specを詰め直す必要があることを案内する。方針を推測で補って実装に進まない
   3. **要確認の残留**: 共通記録のうち対象specの `Decisions:` が参照するentry (doc modeでは本文の要確認記載) に `tentative` (要確認) の暫定決定が残っていないか。spec作成側が承認前にtentativeを解消するため、ここで残っているのは承認後に共通記録の参照entryが編集された場合などに限る。残っていれば一覧を提示し、このまま進めてよいかをユーザーに確認する。続行が選ばれた場合は、該当decisionの `Status:` を `accepted`、`Owner:` を `human` へ更新し、Evidenceに確認日と根拠を追記してから進む (確認済みの決定として記録し、再実行時に同じtentativeで止まらない)
   4. **Issueとの乖離**: `Source: #N` を持つspecでは `gh issue view <N> --json state,body,comments` で最新を取得する。Issueが**closedなら実装済みの可能性を警告**して続行を確認する。取り込みと投影の後に付いた新しいコメントや本文の変更があれば内容を提示し、specへ反映してから進むか、このまま進むかを確認する。反映する場合は `approval: pending` へ戻してから反映し、更新後のcontractを提示して承認を得て `approved` へ更新してから進む。承認されなければ中止し、specの磨き直しが必要であることを案内する
   5. **spec間依存** (spec modeのみ): BoundariesのDependenciesに `spec: <slug>` の行があれば `.mjun/specs/<slug>/spec.md` を読み、`status: done` を確認する。specが存在しない、またはdoneでない場合は中止し、先に該当specの配送が必要であることを案内する
4. **taskキューを構築する**:
   - specに `tasks.md` がある場合は、それをキューとして採用する。`Status: done` のtaskは**完了扱いでスキップする** (中断後のresume)。`Status: blocked` のtaskは `Resume when` が現在満たされたと確認できた場合だけ `ready` へ戻し、それ以外はblocked一覧へ残す
   - 採用したtaskのうちAcceptance Criteriaが4件以上のものは、verifierが `TOO_LARGE` と判定する基準に当たる。Phase 3.0を待たず、ここで下の分解規則により分割し、Phase 3.0の `TASK_TOO_LARGE` と同じ検査 (ACの和集合が元taskと等しい、BoundaryがOwns内、依存が循環しない) を通してからキューを置き換える (大きすぎるtaskをverifierへ渡すと、検査の作成に失敗してから分割することになる)。粒度の基準の免除をユーザーに求めて、そのまま進めない
   - 全taskが `done` の場合も終了せず、記録済みbranchからresumeしてPhase 3.2の最終検証とPhase 4の配送を再実行する
   - spec modeで `tasks.md` が無い場合は、独立に検証可能な振る舞いが複数あれば1 task 1振る舞いのvertical sliceへ分解し、それ以外はspec全体を `T-001` とする。分解の判定は次の規則で行う: 各taskのAcceptance Criteriaを1つの失敗コマンドでredにできる (できなければ分割)、Boundaryは specのOwnsのうち1つ (2つ以上に触るなら `Boundary: <責務A>, <責務B> (integration)` と明示して先行taskの後に置く)、型・設定・配線などの前提は先行taskにしてBlocked byで結ぶ、各taskに `Done when:` (完了時に観察できること) と `Seam:` (検証する公開インターフェース) を1行ずつ付ける、ACが4件以上になるtaskは分割する。ここでは会話内に保持し、Phase 2のworktree作成後に `tasks.md` へ書く
   - doc modeでは同じ基準で会話内のキューを作り、Local specの `tasks.md` は作らない
   - 各taskの受け入れ基準、Boundary (specにBoundariesがある場合)、Done when、Seamを確認し、依存順 (Blocked by) に並べる。`Blocked by` の全taskが `done` のtaskだけを実行可能とし、blocked taskに依存するtaskは実行せず依存待ち一覧へ残す
   - **task groupへ区切る**: groupがPhase 3.0〜3.1の単位 (verifier、implementer、reviewer、commit) になる。依存順に並べたキューを先頭から走査し、現在のgroupのいずれかのtaskとspecのOwnsの同じ責務 (Boundary) に属するtaskは現在のgroupへ加え、属さなければ新しいgroupを始める (Boundariesが無い場合はSeamが同じ公開interfaceかで判定する)。1 groupはtask 5件・Acceptance Criteria合計12件を上限の目安とし、超える場合は依存順で区切る (verifierとimplementerが1つのfresh contextで扱える大きさ)。groupは依存順に直列で処理するため、先行groupのtaskは処理時点でdoneになっている。単一taskのgroupも同じ手順で扱う
5. `--pr` / `--no-pr` / `--merge` が未指定なら、ここでAskUserQuestionにより配送方法を確認する (使えない環境では選択肢をテキストで提示する)。手順1の `gh repo view` が失敗した (GitHub remoteが無い) 場合はPRを作れないため、`--no-pr` と `--merge` の2択で確認する
6. 実装方針とtask一覧 (group区切り付き) を**簡潔に**提示し、確認を取らずPhase 2へ進む

### Phase 2: worktreeの作成

1. **branch名候補を決定する**: 形式は `<type>/<slug>` (specが `Source: #N` を持つ場合は `<type>/<N>-<slug>`)。`<type>` はConventional Commitsの種別 (`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`)、`<slug>` はタイトルからkebab-case (英数字とハイフン、40文字以内)
2. **resumeの判定**: spec modeの `tasks.md` に `Implementation Branch: <branch-name>` があり、そのlocal branchが存在すれば、taskのstatusにかかわらず前回実行のbranchとして使う。記録されたlocal branchが存在しない場合は、記録を破棄して新規実行として続行する (branch削除後の自己修復)。記録が無い場合は新規実行とし、branch名候補が既存branchと衝突すれば末尾に `-2`, `-3` を付けて回避する。doc modeは常に新規実行とする
3. **worktreeのパス**: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
4. **worktree作成**:
   - resumeの場合は、Phase 1で取得した `git worktree list --porcelain` から `<branch-name>` をcheckout済みのworktreeを探す。見つかればそのパスを採用し、worktree作成をスキップする (PR作成失敗時に保持したworktreeの再利用)。未commit変更が残っている場合は中止して報告する。見つからなければ `git worktree add <worktree-path> <branch-name>` で既存branchをcheckoutする
   - 新規の場合は `git worktree add -b <branch-name> <worktree-path> <base-branch>` (`<base-branch>` は最新のdefault branch)
   - 作成失敗時は中止してエラーを伝える
   - 作成後 (resumeで既存worktreeを採用した場合も)、`<worktree-path>/.mjun` が無ければ `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る。`.mjun/` はgit管理外でworktreeに無いため、symlinkが無いとworktree内のcwdから相対パスで行った `tasks.md` などの更新が失われる
5. 新規実行のspec modeでは、worktree作成成功後にPhase 1のtaskキューを `tasks.md` へ書き、先頭へ `Implementation Branch: <branch-name>`、末尾へ `## Implementation Notes` と `## Run Log` を置く。既存の `tasks.md` がある場合はtask内容を変えず、先頭の `Implementation Branch:` を設定し、`## Run Log` が無ければ末尾に追加する
6. branch名、worktreeパス、base branch名を記録する (クリーンアップで使う)

### Phase 3: 実装

実装はSubAgentで行う。受け渡しはすべてメイン会話が構造化ブロックをパースして仲介する。プロンプトはskill内のテンプレートにgroup (Phase 1で区切ったtask group) の文脈を合成して作る。
verifier、reviewer、debugger、refactorerは毎回新規に起動する (fresh context)。implementerはgroupごとに1回起動し、同じgroupの差し戻し・裁定・不足情報の補充は**同じimplementerを継続して** (send_message / resume等) 行う。継続できない環境では新規に起動し、失敗した試行の履歴は含めず `REMEDIATION` など修正に必要な情報と、前回の方針の要約1行だけを渡す。

役割は5つある。

- **verifier** ([templates/verifier-prompt.md](templates/verifier-prompt.md)): 実装の前に、groupの各taskのAcceptance Criteriaを「今は失敗する実行可能な検査」に落とし、検査ファイルをformatterとlintに通してから、Task Briefと一緒に `## Check Report` を返す。検査がimplementerの成功の定義になる
- **implementer** ([templates/implementer-prompt.md](templates/implementer-prompt.md)): groupの全taskについてverifierの検査をgreenにする実装と検証を担い、`## Status Report` を返す
- **reviewer** ([templates/reviewer-prompt.md](templates/reviewer-prompt.md)): 検査の実行結果、検査ファイルの不変、実在性、Boundaryを中心に敵対的に検証し、`## Review Verdict` を返す
- **debugger** ([templates/debugger-prompt.md](templates/debugger-prompt.md)): 差し戻しが収束しない、またはBLOCKEDのときに、fresh contextでroot causeを分類し `## Debug Report` を返す
- **refactorer** ([templates/refactorer-prompt.md](templates/refactorer-prompt.md)): 全task完了後、reviewerのNOTESとtask間の重複を全検査greenのまま整理し、`## Refactor Report` を返す

`design.md` は、groupに関係する部分だけをSubAgentへ渡す (全文を毎回渡すと、後半のgroupでSubAgentのcontextを圧迫する)。groupのtaskのBoundaryに対応するModules、Seamに対応するInterfaces & Seams、それらを通るData Flow、Test Strategy、Change Outlineの全体を含め、対応を判断できないセクションは全文を渡す。以下ではこれを「`design.md` の該当部分」と呼ぶ。

SubAgentのmodel選択は、環境のグローバル指示 (CLAUDE.md, AGENTS.md等) のモデル指針を最優先する。指針が無ければメイン会話と同等のモデルをデフォルトとし、定型的で機械的な作業に限りimplementerに軽量モデルを指定してよい。verifierとreviewerにはimplementerと同等以上のモデルを使う (出力が親の状態遷移に直接使われるため)。モデル指針が作業の性質でmodelを選ぶ形の場合は、role名ではなくgroupの作業の性質に当てはめ、すべてのroleを最上位のモデルに寄せない。

実装を始める前に、リポジトリから正規の検証コマンドを洗い出し、`TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` / `SMOKE_COMMANDS` として保持する。探索順は `.mjun/steering/` の記述 → manifest類 → タスクランナー → CI設定 → README。リポジトリの自動化が既に使っているコマンドを優先する。`SMOKE_COMMANDS` (起動して最初の利用可能な状態に達することを確かめるコマンド) は宣言されているものだけを使い、無ければ空のままにしてPhase 3.2でverifierの検査から代用する。

Phase 3の間の制約:

- verifier、implementer、reviewer、debugger、refactorerはleaf roleとし、SubAgentを起動せず、担当作業を別Agentへ再移譲しない。自分で完了できない場合はrole固有の構造化結果で親へ返し、追加の委譲は親だけが判断する
- ループ内で `git reset --hard` 等の破壊的リセットを行わない (例外はPhase 3.3で整理の変更だけを戻す場合のみ)
- pushとPR作成はPhase 4まで行わない。commitはgroup承認ごとにメイン会話が行う (Phase 3.1)。SubAgentにはcommitさせない
- SubAgentの完了主張を検証の代わりにしない。判定は構造化フィールドと、検査・reviewer・最終検証の実行結果だけで行う
- 構造化値が無い、または曖昧なときの再要求は、作業したSubAgentを継続して行う (SendMessage等)。継続できない環境では、ブロックだけを別のSubAgentに求めず、そのroleを最初からやり直す (作業していないagentが返すブロックは捏造になる)
- SubAgentの報告で `NOT_RUN` の項目は、親が該当コマンドを実行して埋める。推測で埋めない
- verifierが書いた検査ファイル (`CHECK_FILES`) はverifier以外に変更させない。親は検査の作成直後にファイルのハッシュ (`shasum -a 256`) を記録し、reviewerがそれと照合する。検査を直す必要が生じた場合はverifierに作り直させ、ハッシュを更新する。後続groupの意図した変更で先行groupの検査が壊れた場合も同じ経路を使う: 壊れた検査と原因の変更を添えてverifierに該当検査だけを更新させ (期待値の根拠はAcceptance Criteriaのまま、前提だけを直す)、ハッシュを更新してRun Logに記録する。implementerには直させない
- ユーザーの指示で手順の一部を変える場合も、role、テンプレート、構造化ブロック、回数の上限はそのまま使い、独自の役割名や報告形式を作らない。複数groupを同じworktreeで並列に実装しない (Phase 3.1)
- 実行中にcontractに無い追加要求を受けた場合は、`spec.md` を直接書き換えて実装に入らない。現在のgroupを終えた時点で止め、specの磨き直し (承認を含む) が先に必要であることを案内する
- CIのrunなど数分以上かかる外部の完了待ちは、完了まで戻らない待機コマンドを1本だけ実行して待つ。短い間隔の再確認や、時間切れごとの待機の張り直しを繰り返さない

#### Phase 3以降の手順

Phase 3以降の手順は、必要になった時点で次のファイルを読む。読んでいない手順を記憶で補わない。

- [references/group-loop.md](references/group-loop.md): Phase 3.0 (検査の作成) とPhase 3.1 (実装とレビュー)、Run Logの形式。最初のgroupを始める前に読む
- [references/recovery.md](references/recovery.md): taskの隔離とblocked、Phase 3.1' (debuggerによる原因調査)。implementerが `BLOCKED` を返した、差し戻しが2周に達した、taskをblockedへ移す、task計画を直す、のいずれかのときに読む
- [references/validation-and-delivery.md](references/validation-and-delivery.md): Phase 3.2 (feature単位の検証)、Phase 3.3 (整理)、Phase 4 (commitと配送)、Phase 5 (結果の表示)、Phase 6 (worktreeクリーンアップ)。実行可能なtaskが尽きたときに読む

完了の定義: 全taskが `done` で、Phase 3.2の判定が `GO` または `MANUAL_VERIFY_REQUIRED` になり、選ばれた配送方法で届け、Phase 5の結果を表示し、Phase 6でworktreeを片付けた状態 (`COMPLETE`)。doneでないtaskが残る場合は `PARTIAL` として、Phase 5とPhase 6だけを行う。エラーやユーザーの中止で途中終了する場合も、Phase 6は必ず実行する。
