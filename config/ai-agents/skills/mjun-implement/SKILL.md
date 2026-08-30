---
name: mjun-implement
description: >-
  spec (`.mjun/specs/` のLocal spec、GitHub Issue番号、または単発の設計doc) を起点に「内容検査 → worktree作成 → task単位の実装 → Acceptance Criteria照合 → commit → 必要ならPR作成」を一気通貫で実行するSkill。
  正本は常にLocal specで、Issue番号は取り込み済みspec (mjun-specify経由) への逆引きとして扱う。未取り込みならmjun-specifyを案内する。
  実装はSubAgentに委譲し、commitとPR作成はgit-commitとgithub-pr-create skillに連結する。
  ユーザーが「#Nを実装して」「このspecを実装して」「実装してPRまで」のように依頼したら使うこと。
  specの作成や磨き上げには使わない。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash(gh:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(shasum:*), AskUserQuestion, Skill(git-commit), Skill(github-pr-create)
---

# mjun-implement

specを起点に、内容検査 → 実装 → commit → (必要なら) PR作成までを進めるSkill。
メイン会話が担うのは、検査、worktree作成、SubAgentへの引き継ぎ、進捗の永続化、結果検証、クリーンアップであり、**実装 (Phase 3) はSubAgentに委譲し、commitとPR作成 (Phase 4) は `git-commit` skillと `github-pr-create` skillに連結する**。
SubAgent機能が使えない環境では、SubAgentの作業をメイン会話内で同じ手順で順に実施する。

## Arguments

- `source` (必須): 実装対象。GitHub Issue番号 (`#123` / `123`)、`.mjun/specs/<slug>` のLocal specディレクトリ、または単発Markdownのパス
- `--pr` / `--no-pr` (任意): 実装をPRとして届けるか、local commitまでで終えるか。**どちらも未指定の場合は、worktree作成前に確認する** (長時間の自律実装の最後で確認待ちにしない)

### source種別

sourceの形からmodeを決める。

1. `.mjun/specs/<slug>` のディレクトリ、またはその配下のファイルパス → **spec mode**
2. Issue番号またはGitHub URL → 取り込み済みspecへの逆引き (下記) を経て **spec mode**
3. その他のMarkdownパス → **doc mode**。ファイル全文を起点とする (frontmatterがあれば除く)

spec modeでは、specディレクトリ配下の `spec.md` と `design.md` (いずれも必須)、あれば `decisions.md` と `tasks.md` をReadする。`.mjun/adr/*.md` (あれば) も読み、taskに関係するADRをSubAgentへ渡す (worktreeには `.mjun/` が無い)。

### Issue番号の逆引き

入口は常にmjun-specifyであり、Issueが直行で実装できる品質かの判断をこのskillで肩代わりしない。

1. activeなspec (`status: active`) から `Source: #<number>` を持つspecを検索する。見つかればそれを対象にする (複数ヒットした場合は一覧を提示して選んでもらう)
2. activeに無ければ、doneのspecからも `Source: #<number>` を検索する。見つかれば「実装済みのspec (`<path>`) がある。再開する場合は `status` を `active` へ戻すか、`mjun-specify #<number>` で取り込み直す」と案内して中止する
3. どちらにも無ければ中止し、`mjun-specify #<number>` での取り込みと磨き上げを案内する

**Local specの参照と更新は、常にメインrepositoryの絶対パスで行う。** `.mjun/` はgit管理外のためworktreeやPR checkoutには存在しない。SubAgentへはspecの内容をプロンプトに合成して渡し、worktree内の `.mjun/` パスを読ませない。

## Task

### Phase 1: 内容検査とtaskキュー構築

1. 以下を取得して状況を確認する:
   - リポジトリ情報: `gh repo view --json defaultBranchRef,nameWithOwner` (Local spec / doc modeでghが失敗する場合は `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
   - source本文 (source種別に従う)
   - 現在のbranch: `git branch --show-current`、既存worktree: `git worktree list --porcelain`
2. 出力言語をsourceの言語から決める (主に日本語なら日本語、それ以外または曖昧なら英語)。コメント、commit、PR作成に使う
3. **内容検査**:
   1. **contract承認とdesign.md** (spec modeのみ): `spec.md` のfrontmatterが `approval: approved` か確認する。値が無い、または `pending` の場合は中止し、`mjun-specify <source>` でcontractを承認するよう案内する。実装依頼そのものをcontract承認の代わりにしない。`design.md` が無い場合も中止し、`mjun-specify <source>` で設計を作成するよう案内する
   2. **情報の充足**: Goal、受け入れ基準、実装方針など、実装に必要な情報が揃っているか。コードを読めば確認できる事実は自分で解決する。仕様や方針の判断に必要な情報が欠けている場合は中止し、欠落情報を項目立てて具体的に伝え、`mjun-specify` でspecを詰めることを案内する。方針を推測で補って実装に進まない
   3. **要確認の残留**: decision log (`decisions.md`、または取り込んだspec本文の要確認記載) に `tentative` (要確認) の暫定決定が残っていないか。残っていれば一覧を提示し、このまま進めてよいかをユーザーに確認する。続行が選ばれた場合は、該当decisionの `Status:` を `accepted` へ更新してから進む (確認済みの決定として記録し、再実行時に同じtentativeで止まらない)
   4. **Issueとの乖離**: `Source: #N` を持つspecでは `gh issue view <N> --json state,body,comments` で最新を取得する。Issueが**closedなら実装済みの可能性を警告**して続行を確認する。取り込みと投影の後に付いた新しいコメントや本文の変更があれば内容を提示し、specへ反映してから進むか、このまま進むかを確認する。反映する場合は `approval: pending` へ戻してから反映し、更新後のcontractを提示して承認を得て `approved` へ更新してから進む。承認されなければ中止し、`mjun-specify <source>` での磨き直しを案内する
4. **taskキューを構築する**:
   - specに `tasks.md` がある場合は、それをキューとして採用する。`Status: done` のtaskは**完了扱いでスキップする** (中断後のresume)
   - 全taskが `done` の場合も終了せず、記録済みbranchからresumeしてPhase 3.2の最終検証とPhase 4の配送を再実行する
   - spec modeで `tasks.md` が無い場合は、独立に検証可能な振る舞いが複数あれば1 task 1振る舞いのvertical sliceへ分解し、それ以外はspec全体を `T-001` とする。分解の判定は次の規則で行う: 各taskのAcceptance Criteriaを1つの失敗コマンドでredにできる (できなければ分割)、Boundaryは specのOwnsのうち1つ (2つ以上に触るなら `Boundary: <責務A>, <責務B> (integration)` と明示して先行taskの後に置く)、型・設定・配線などの前提は先行taskにしてBlocked byで結ぶ、各taskに `Done when:` (完了時に観察できること) と `Seam:` (検証する公開インターフェース) を1行ずつ付ける、AC ≤ 3を目安とし超えるものは分割候補とする。ここでは会話内に保持し、Phase 2のworktree作成後に `tasks.md` へ書く
   - doc modeでは同じ基準で会話内のキューを作り、Local specの `tasks.md` は作らない
   - 各taskの受け入れ基準、Boundary (specにBoundariesがある場合)、Done when、Seamを確認し、依存順 (Blocked by) に並べる
5. `--pr` / `--no-pr` が未指定なら、ここでAskUserQuestionにより配送方法を確認する (使えない環境では選択肢をテキストで提示する)
6. 実装方針とtask一覧を**簡潔に**提示し、確認を取らずPhase 2へ進む

### Phase 2: worktreeの作成

1. **branch名候補を決定する**: 形式は `<type>/<slug>` (specが `Source: #N` を持つ場合は `<type>/<N>-<slug>`)。`<type>` はConventional Commitsの種別 (`fix`, `feat`, `docs`, `chore`, `refactor` 等。判別不能なら `feat`)、`<slug>` はタイトルからkebab-case (英数字とハイフン、40文字以内)
2. **resumeの判定**: spec modeの `tasks.md` に `Implementation Branch: <branch-name>` があり、そのlocal branchが存在すれば、taskのstatusにかかわらず前回実行のbranchとして使う。記録されたlocal branchが存在しない場合は、記録を破棄して新規実行として続行する (branch削除後の自己修復)。記録が無い場合は新規実行とし、branch名候補が既存branchと衝突すれば末尾に `-2`, `-3` を付けて回避する。doc modeは常に新規実行とする
3. **worktreeのパス**: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
4. **worktree作成**:
   - resumeの場合は、Phase 1で取得した `git worktree list --porcelain` から `<branch-name>` をcheckout済みのworktreeを探す。見つかればそのパスを採用し、worktree作成をスキップする (PR作成失敗時に保持したworktreeの再利用)。未commit変更が残っている場合は中止して報告する。見つからなければ `git worktree add <worktree-path> <branch-name>` で既存branchをcheckoutする
   - 新規の場合は `git worktree add -b <branch-name> <worktree-path> <base-branch>` (`<base-branch>` は最新のdefault branch)
   - 作成失敗時は中止してエラーを伝える
5. 新規実行のspec modeでは、worktree作成成功後にPhase 1のtaskキューを `tasks.md` へ書き、先頭へ `Implementation Branch: <branch-name>`、末尾へ `## Implementation Notes` と `## Run Log` を置く。既存の `tasks.md` がある場合はtask内容を変えず、先頭の `Implementation Branch:` を設定し、`## Run Log` が無ければ末尾に追加する
6. branch名、worktreeパス、base branch名を記録する (クリーンアップで使う)

### Phase 3: 実装

実装はSubAgentで行う。SubAgent同士は直接やり取りできないため、受け渡しはすべてメイン会話が構造化ブロックをパースして仲介する。プロンプトはskill内のテンプレートにtask文脈を合成して作る。
SubAgentは毎回新規に起動し、差し戻し時も前回のSubAgentを継続しない。失敗した試行の履歴はプロンプトに含めず、`REMEDIATION` など修正に必要な情報だけを渡す。

役割は5つある。

- **verifier** ([templates/verifier-prompt.md](templates/verifier-prompt.md)): 実装の前に、taskのAcceptance Criteriaを「今は失敗する実行可能な検査」に落とし、Task Briefと一緒に `## Check Report` を返す。検査がimplementerの成功の定義になる
- **implementer** ([templates/implementer-prompt.md](templates/implementer-prompt.md)): verifierの検査をgreenにする実装と検証を担い、`## Status Report` を返す
- **reviewer** ([templates/reviewer-prompt.md](templates/reviewer-prompt.md)): 検査の実行結果、検査ファイルの不変、実在性、Boundaryを中心に敵対的に検証し、`## Review Verdict` を返す
- **debugger** ([templates/debugger-prompt.md](templates/debugger-prompt.md)): 差し戻しが収束しない、またはBLOCKEDのときに、fresh contextでroot causeを分類し `## Debug Report` を返す
- **refactorer** ([templates/refactorer-prompt.md](templates/refactorer-prompt.md)): 全task完了後、reviewerのNOTESとtask間の重複を全検査greenのまま整理し、`## Refactor Report` を返す

SubAgentのmodel選択は、環境のグローバル指示 (CLAUDE.md, AGENTS.md等) のモデル指針を最優先する。指針が無ければメイン会話と同等のモデルをデフォルトとし、定型的で機械的な作業に限りimplementerに軽量モデルを指定してよい。reviewerにはimplementerと同等以上のモデルを使う。

実装を始める前に、リポジトリから正規の検証コマンドを洗い出し、`TEST_COMMANDS` / `LINT_COMMANDS` / `BUILD_COMMANDS` / `SMOKE_COMMANDS` として保持する。探索順は `.mjun/steering/` の記述 → manifest類 → タスクランナー → CI設定 → README。リポジトリの自動化が既に使っているコマンドを優先する。`SMOKE_COMMANDS` (起動して最初の利用可能な状態に達することを確かめるコマンド) は宣言されているものだけを使い、無ければ空のままにしてPhase 3.2でverifierの検査から代用する。

Phase 3の間の制約:

- ループ内で `git reset --hard` 等の破壊的リセットを行わない (例外はPhase 3.3で整理の変更だけを戻す場合のみ)
- pushとPR作成はPhase 4まで行わない。commitはtask承認ごとにメイン会話が行う (Phase 3.1)。SubAgentにはcommitさせない
- SubAgentの完了主張を検証の代わりにしない。判定は構造化フィールドと、検査・reviewer・最終検証の実行結果だけで行う
- verifierが書いた検査ファイル (`CHECK_FILES`) はverifier以外に変更させない。親は検査の作成直後にファイルのハッシュ (`shasum`) を記録し、reviewerがそれと照合する。検査を直す必要が生じた場合はverifierに作り直させ、ハッシュを更新する

#### Run Log

`tasks.md` 末尾の `## Run Log` に、taskごとに1行で追記する (中断後のresumeでは既存行を保持し、新しい行を足す)。原因分析の材料にするため、周回数と差し戻しの証拠種別、debuggerの分類を残す。

```text
- T-001: checks=READY (3) | rounds=2 | reject=[a, b] | debug=LOGIC_ERROR→RETRY_TASK | result=done
- feature: validation=GO | refactor=DONE
```

#### Phase 3.0: 検査の作成 (taskごと、実装前)

taskキューの順に、taskごとに次を行ってからPhase 3.1へ進む。

1. **task statusの更新**: `tasks.md` の該当taskを `Status: in-progress` へ更新する (spec modeのみ。メインrepo側のパスで)
2. **verifierの起動**: テンプレートに、worktreeの絶対パス、contract、`design.md` の全文 (spec modeのみ)、関係するADR (あれば)、担当task (説明、Acceptance Criteria、Boundary、Done when、Seam)、検証コマンド、Implementation Notesを合成して起動する
3. **STATUSの処理**: `## Check Report` の `- STATUS:` だけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する
   - `CHECKS_READY` → `CHECK_COMMANDS` をworktreeで実行し (親が直接、またはSubAgentに実行を依頼して出力を受け取る)、**すべて失敗する**ことを確認する。通ってしまう検査があれば、その検査名を添えてverifierに1回だけ作り直させる。確認後、`CHECK_FILES` のハッシュを記録し、検査一覧 (Acceptance Criterion → コマンド) をユーザーに提示してPhase 3.1へ進む (承認は取らない。人間が「この検査が通れば完了」を見る場所)
   - `CANNOT_VERIFY` → 中止する。`MISSING` (どんな検証手段があれば検査にできるか) を報告し、Acceptance Criteriaを検査に落とせる形へ書き直す必要があることを伝える (`mjun-specify <source>` で磨き直す)
   - `TASK_TOO_LARGE` → 中止する。`SPLIT_PROPOSAL` を報告し、`mjun-to-tasks <source>` で再分解するよう案内する
4. Run Logに `checks=<READY (n) | CANNOT_VERIFY | TOO_LARGE>` を記録する

#### Phase 3.1: 実装とレビュー (taskごと)

**1 task = 1イテレーション**で直列に処理する (`Blocked by` は順序の決定にだけ使い、並列実行しない)。複数taskを1つのSubAgentにまとめて渡さない。

1. **implementerの起動**: テンプレートに以下を合成して起動する
   - worktreeの絶対パス、base branch名と作業branch名
   - specのタイトルと本文の要約と、**contract (Requirements / Boundaries / Acceptance Criteria / Out of Scope)**
   - `design.md` の全文 (spec modeのみ。実装設計) と、関係するADR (あれば)
   - verifierの `TASK_BRIEF`、`CHECK_FILES` (変更禁止)、`CHECK_COMMANDS`
   - 担当taskの説明、Boundary、Done when、Seam、Phase 1で決めた実装方針
   - taskに関係する検証コマンド
   - これまでのImplementation Notes (あれば)
2. **STATUSの処理**: `## Status Report` の `- STATUS:` フィールドだけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する
   - `READY_FOR_REVIEW` → 3へ進む
   - `CHECK_DISPUTE` → 親が `DISPUTE` の主張を担当taskのAcceptance Criteriaと照らして裁定する。検査が誤っていればverifierに `DISPUTE` を渡して1回だけ作り直させ (RED確認とハッシュ更新を行う)、implementerを再起動する。検査が正しければ裁定理由を添えてimplementerを再起動する。裁定は同一taskで1回まで
   - `NEEDS_CONTEXT` → `MISSING` の不足情報を用意して1回だけ再起動する。解決しなければ中止し、Phase 1と同じ形式でユーザーに質問する
   - `BLOCKED` → Phase 3.1'のdebuggerへ進む
3. **reviewerの起動**: テンプレートに、task文脈、contract、`design.md` の全文 (spec modeのみ)、関係するADR (あれば)、`CHECK_COMMANDS`、`CHECK_FILES` と記録したハッシュ、検証コマンド、implementerのStatus Report (参照用)、周回 (`ROUND`) を合成して起動する。2周目以降は前回の `FINDINGS` と `REMEDIATION` も渡す (reviewerは前回指摘の解消を先に判定し、新規のREJECT根拠を検査の失敗・回帰・検査ファイルの改変・実在性・Boundary違反に限る)
4. **VERDICTの処理**: `## Review Verdict` の `- VERDICT:` フィールドだけをパースする
   - `APPROVED` → task完了。**先にworktree内でそのtaskの変更 (検査ファイルを含む) をcommitし** (Conventional Commits形式で、taskのタイトルを要約したメッセージ)、成功後に `tasks.md` の該当taskを `Status: done` へ更新する (Issueへは書き込まない)。commit対象の差分が無い場合は、前回実行でcommit済みとみなしてstatus更新だけを行う。この順序により「done = commit済み」が常に成り立ち、中断してもコードが失われない。`NOTES` はPhase 3.3のために保持する。Run Logに周回数、差し戻しの証拠種別、結果を記録し、次のtaskへ進む
   - `REJECTED` → implementerを再起動する。渡すのは `REMEDIATION`、`FINDINGS`、reviewerが実行して失敗したコマンドの生の出力 (`MECHANICAL_RESULTS` と `FINDINGS` の証拠 (a))、前回のimplementerが取った方針の要約1行 (`EVIDENCE` と `FILES_CHANGED` から親が作る。「駄目だった方針」として渡す)。worktreeには前回の試行の未commit変更が残っているので、implementerに `git diff` で確認させてから直させる。同一taskの差し戻しは**最大2周**とし、2周後もREJECTEDならPhase 3.1'のdebuggerへ進む
5. **知見の伝播**: task横断で有用な発見は、`tasks.md` 末尾の `## Implementation Notes` へ1行で永続化し、以降のverifierとimplementerのプロンプトに含める

中断後に再実行された場合は、Phase 1のキュー構築が完了taskをスキップするため、未完了taskから再開される。未完了taskの検査はcommitされていないため、Phase 3.0からやり直す。

#### Phase 3.1': 原因調査 (収束しないとき)

BLOCKED、または差し戻し2周後のREJECTEDで起動する。debuggerはfresh contextで動かし、失敗した試行の経緯は渡さない。

1. **debuggerの起動**: テンプレートに、失敗の内容 (`BLOCKER` または最後のreviewerの `FINDINGS` / `REMEDIATION`)、失敗したコマンドの生の出力、現在の `git diff`、verifierの `TASK_BRIEF` と `CHECK_COMMANDS`、contractの該当箇所、Implementation Notesを合成して起動する
2. **NEXT_ACTIONの処理**: `## Debug Report` の `- NEXT_ACTION:` だけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する
   - `RETRY_TASK` → `FIX_PLAN` と `NOTES` を渡して新しいimplementerを起動し、Phase 3.1の3以降を1周だけ行う
   - `FIX_CHECK` → 検査自体の誤り。`ROOT_CAUSE` を渡してverifierに作り直させ (RED確認とハッシュ更新を行う)、implementerを起動してPhase 3.1の3以降を1周だけ行う
   - `RETURN_TO_TASKS` → 中止し、`ROOT_CAUSE` と分割・順序の修正案を報告して `mjun-to-tasks <source>` を案内する
   - `RETURN_TO_SPEC` → 中止し、contractと現実の矛盾箇所を報告して `mjun-specify <source>` を案内する (specは変更しない)
   - `STOP_FOR_HUMAN` → 中止し、`ROOT_CAUSE` と `HUMAN_QUESTION` (1問、選択肢付き) を報告する
3. debuggerは同一taskで**最大2回**まで起動する。2回目の後も解決しなければ中止し、未解決の指摘、Acceptance Criterionごとの検査結果、試した仮説 (Debug Reportの要約) を報告する
4. `CATEGORY` と `NEXT_ACTION` をRun Logに、次のtaskにも効く知見をImplementation Notesに記録する

#### Phase 3.2: feature単位の検証

全task完了後に行う。各項目はSubAgentに依頼してよいが、判定は親が結果に基づいて行う。

1. **検証コマンドの実行**: TEST / LINT / BUILD 全体と `SMOKE_COMMANDS`。SMOKEが宣言されていない場合は、各taskの `CHECK_COMMANDS` のうちend-to-endに最も近いものを代用する。どちらも無ければ「実行時検証: 未実施」として扱う
2. **Acceptance Criteriaの照合**: specのAcceptance Criteria 1件ごとに、それを証明する検査 (`CHECK_COMMANDS`) と実装を対応づける。証明する検査が無いcriterionは、実装と検証結果から充足を判定し、判定できなければ未充足とする。specにAcceptance Criteriaが無いdoc modeでも、taskキューのAcceptance Criteriaは照合する
3. **task間の整合**: task同士が共有するinterface、データ形、エラー形式、設定が一致しているかをコードから確認する
4. **contract境界の照合**: branch全体の変更 (`git diff <base>..HEAD`) がspecのBoundaries (Owns / Does Not Own) とOut of Scopeに収まっているかを照合する。specにBoundariesもOut of Scopeも無い場合はスキップする

判定:

- 検証コマンドがすべて成功し、全criterionが充足し、task間が整合し、boundary違反が無い → `GO`。Phase 3.3へ進む
- 実行時検証だけが「未実施」で、他はすべて成功 → `MANUAL_VERIFY_REQUIRED`。Phase 3.3へ進むが、Phase 5の報告とPR本文の検証結果に未実施を明記する
- 検証コマンドの失敗、criterionの未充足、task間の不整合、またはboundary違反 → 内容を添えてimplementerに差し戻す (合わせて最大2周)。差し戻しは該当criterionを持つtaskの文脈で行い、全taskの `CHECK_COMMANDS` と `CHECK_FILES` のハッシュを渡す。**差し戻しで生じた修正は、Phase 3.1と同じreviewerの検査に合格してからPhase 3.3へ進む** (最終検証後の変更だけがboundary検査等を迂回する経路を作らない)。収束しなければ中止し、未充足のcriterionを明示して報告する

Run Logに `feature: validation=<GO | MANUAL_VERIFY_REQUIRED | NO-GO>` を記録する。

#### Phase 3.3: 整理 (refactor pass)

Phase 3.2の判定がGOまたはMANUAL_VERIFY_REQUIREDのあと、reviewerの `NOTES` が1件以上あるか、Phase 3.2でtask間の重複が見つかった場合に行う。どちらも無ければスキップする。

1. **refactorerの起動**: テンプレートに、worktreeの絶対パス、contractのBoundariesとOut of Scope、全taskの `NOTES`、全 `CHECK_COMMANDS` と `CHECK_FILES`、検証コマンドを合成して起動する
2. `## Refactor Report` の `- STATUS:` だけをパースする。`SKIPPED` なら何もしない。`DONE` ならreviewerを `ROUND: refactor` で起動し、全taskの `CHECK_COMMANDS` と `CHECK_FILES` のハッシュ、検証コマンド、contractのBoundariesを渡す (全検査の通過、検査ファイルの不変、Boundary、振る舞いの不変を検査する)
3. `APPROVED` → `refactor:` 種別のcommitを作る。`REJECTED` → refactorerの `FILES_CHANGED` だけを `git checkout -- <files>` で戻す (失うのは整理だけで、taskのcommitは影響を受けない)。再試行はしない
4. Run Logの `feature:` 行に `refactor=<DONE | SKIPPED | REJECTED>` を追記する

### Phase 4: commitと配送 (git-commit / github-pr-create に連結)

メイン会話が、作業ディレクトリをworktreeの絶対パスに切り替えた上で実行する。commit messageやPR本文などの外部向け出力には、`.mjun/` 配下のパスや内部spec文書を含めない (外部へ見せるspecの参照はGitHub Issue番号だけを使う)。

1. **`git-commit` skillでcommitを作成する**: 対象はPhase 3のtask commitに含まれていない残りの変更 (最終検証での修正など)。残変更が無ければスキップする
2. **`--no-pr` の場合**: ここで配送を終える。Phase 5へ進む
3. **`--pr` の場合、`github-pr-create` skillでPRを作成する**:
   - Phase 1で決めた出力言語を `language` として渡す
   - **specが `Source: #N` を持つ場合はそのIssue番号を `spec` として渡す** (PR本文の `Closes #N` に使われる)。純Local specでは渡さない (specは内部文書であり、PR本文で言及しない。Contract reviewには `github-pr-review` の `--spec` を使う)
   - push、PRタイトルと本文の生成、PR作成はすべて連結先skillが行う。手順を再実装しない
4. **結果を検証する**: 作成されたPRのURLと状態を `gh pr view <url> --json url,state` で確認する。`Source: #N` を持つspecでは本文に `Closes #N` が含まれるか確認し、無ければ `gh pr edit --body-file` で追記する。PR作成に失敗した場合はworktreeをクリーンアップせず、エラーを伝えて中止する
5. **specのstatusを更新する**: 配送の完了後 (`--pr` はPR作成成功後、`--no-pr` はcommit完了後)、specのfrontmatterを `status: done` へ更新する (doc modeではスキップ)。以降このspecは照合、逆引き、一覧の対象から外れる
6. **ADRを投影する** (spec modeのみ): `decisions.md` の `Status: accepted` のdecisionのうち、覆しにくい・文脈なしでは不可解・本物のtrade-offがあった、の3条件をすべて満たすものを `.mjun/adr/NNNN-<slug>.md` へ書く (形式と番号付けは [source-resolutionの用語集と決定記録](../mjun-specify/references/source-resolution.md#用語集と決定記録) に従い、`由来: <slug> / D-NNN` を添える)。既存ADRを覆すdecisionなら旧ADRを `superseded by NNNN` にする。3条件を満たすdecisionが無ければ何も書かない

### Phase 5: 結果の表示

- **Source**: Issue番号とタイトル / specパス
- **Branch**: 作成したbranch名
- **PR**: 作成したPRのURL (`--no-pr` の場合は「PRなし。branch `<name>` に成果があります」)
- **変更概要**: ファイル数、追加/削除行数 (`git diff --stat <base>..HEAD`)
- **task進捗**: 完了task数と、スキップした完了済みtask数 (resume時)
- **Checks**: taskごとの検査数と結果 (Phase 3.0で作成した検査がすべて通ったか)
- **AC coverage**: Acceptance Criteriaの充足状況 (充足数 / 総数と、各criterionの判定、証明した検査)
- **Validation**: Phase 3.2の判定 (GO / MANUAL_VERIFY_REQUIRED)。実行時検証が未実施ならその旨
- **Refactor**: Phase 3.3の結果 (DONE / SKIPPED / REJECTED) と、見送ったNOTES
- **Run Log**: 周回数と差し戻しの要約 (`tasks.md` の `## Run Log` から)
- **ADR**: 投影したADRのファイル名 (無ければ「なし」)

### Phase 6: worktreeクリーンアップ

- **`--pr` で成功した場合**: `git worktree remove --force <worktree-path>` → `git branch -D <branch-name>` (remote branchはPRのheadとして残る)
- **`--no-pr` で成功した場合**: worktreeだけを削除し、**local branchは削除しない**。merge / pushの判断はユーザーに委ねる
- **PR作成に失敗した場合**: worktreeとlocal branchを残して報告する (手動修復の余地を残す)
- **Phase 2〜5の途中でエラーまたはユーザーの中止により中断した場合**: この実行で新規作成したworktreeを削除し、commitが存在するならbranchを残してその旨を報告する。commitが無ければbranchも削除する。resumeで採用した既存worktreeとbranchは削除しない。未commitの検査 (Phase 3.0で作成し、taskがdoneに達していないもの) は失われ、resume時にPhase 3.0からやり直す
- クリーンアップに失敗した場合はユーザーに警告する
