# Group Loop

Phase 3.0 (実装準備と必要な事前検査) とPhase 3.1 (実装とレビュー) をgroupごとに繰り返す手順と、Run Logの形式。role、制約、`design.md` の該当部分の定義は [SKILL.md](../SKILL.md) のPhase 3にある。

## Run Log

`tasks.md` 末尾の `## Run Log` に、groupごとに1行で追記する (中断後のresumeでは既存行を保持し、新しい行を足す)。原因分析の材料にするため、周回数と差し戻しの証拠種別、debuggerの分類を残す。証拠種別は a (失敗コマンドの出力)、b (file:line + 引用)、mismatch (reviewerの `MECHANICAL_RESULTS` と親の再実行が食い違った) のいずれか。groupから外れてblockedになったtaskは別行にする。

```text
- T-001: verifier=none | checks=IMPLEMENTER | rounds=1 | result=done
- T-006: verifier=T-006 (期待値を独立して確定) | checks=READY (3) | rounds=2 | reject=[a, b] | debug=LOGIC_ERROR→RETRY_TASK | result=done
- T-002,T-003,T-004: verifier=none | checks=IMPLEMENTER | rounds=1 | result=done
- T-005: verifier=T-005 (ユーザーが事前検査を指定) | checks=REVIEW_ONLY (3) | rounds=1 | result=done
- feature: validation=GO | refactor=DONE | base-sync=CLEAN
```

## Phase 3.0: 実装準備と必要な事前検査 (groupごと、実装前)

groupの順に、groupごとに次を行ってからPhase 3.1へ進む。

1. **task statusの更新**: groupの各taskの `Blocked by` がすべて `done` であることを確かめ直し、満たさないtaskはgroupから外して依存待ちへ戻す。その後、`tasks.md` のgroupの各taskを `Status: in-progress` へ更新する (spec modeのみ。メインrepo側のパスで)
2. **Task Briefとverifier対象の選択**: 親が各taskのAcceptance Criteria、Done when、Seam、既存の設計制約・検証コマンドを整理して `TASK_BRIEF` にする。新たな設計や検査の作成はここで行わない。[SKILL.md](../SKILL.md) のverifierの使用条件を満たすtaskだけを選び、task IDと具体的な理由をRun Logの `verifier=` に記録する。通常は `verifier=none` として、手順3を省く。対象があれば、そのtaskだけの文脈と使用理由を、worktreeの絶対パス、contract、`design.md` の該当部分、acceptedな判断、検証コマンドとformatter / lintの実行コマンド、Implementation Notesとともにverifierへ渡す。他のtaskはimplementerが検査を用意する
3. **verifierのSTATUSの処理** (対象taskがある場合だけ): `## Check Report` の `- STATUS:` だけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する。以下のどの経路でも、採用したverifierの `TASK_BRIEF` を対象taskのBriefへ反映し、その `CHECK_FILES` を検査ファイル全体と `PROTECTED_CHECK_FILES` に登録する。事前検査の `CHECK_COMMANDS` と `CHECK_BASELINES` を保持する。
   - `CHECKS_READY` → `CHECK_BASELINES` の各検査の種別・根拠をAcceptance Criterionと対象コードに照らして確認し、`CHECK_COMMANDS` をworktreeで実行する (親が直接、またはSubAgentに実行を依頼して出力を受け取る)。**未充足の振る舞いの検査は失敗 (RED)、既存の振る舞いを守る回帰検査は成功 (GREEN)** することを確認する。種別・根拠が欠ける、不適切、または実行結果が期待と違う場合は、検査名と証拠を添えてverifierに1回だけ修正させる。正しい回帰検査を失敗させるために作り直させない。`CHECK_LINT` が `NOT_RUN` のformatterがあれば親が `CHECK_FILES` に対して実行し、失敗すればその出力を添えてverifierに1回だけ作り直させる (lintは実装前にcompileできない検査には実行できないため、verifierの規約確認に委ねる)。確認後、`CHECK_FILES` のハッシュを記録し、検査一覧 (task / Acceptance Criterion → コマンド、種別、RED / GREENの結果) をユーザーに提示して採用する (承認は取らない。人間が「この検査が通れば完了」を見る場所)
   - `CANNOT_VERIFY` → `TASKS` で `READY` のtaskの検査は上と同じ手順で採用し (種別に応じたRED / GREENの確認、ハッシュ記録)、`CANNOT_VERIFY` のtaskだけを処理する。`METHOD` と `MISSING` を記録し、試した方法と不足を、該当taskだけを担当するfresh verifierへ渡して、未試行の別方法を選ばせる。初回を含め最大2回まで試す。`CHECKS_READY` になれば検査をgroupへ合流させる。2回とも検査化できなければ、そのtaskを**review-only**としてgroupに残す: implementerにはAcceptance Criteriaをそのまま成功の定義として渡し、reviewerには該当taskを `REVIEW_ONLY` として渡して全Acceptance Criterionを `file:line` で照合させる。review-onlyのtaskが1件でもあれば、Phase 3.2の判定を `GO` にせず `MANUAL_VERIFY_REQUIRED` とする。検査の作成が難航していることを理由に、verifierを待たず複数groupをまとめて実装する進め方へ切り替えない
   - `TASK_TOO_LARGE` → `READY` のtaskの検査は上と同じ手順で採用し、`TOO_LARGE` のtaskごとに `SPLIT_PROPOSAL` を検査する。分割後taskのACの和集合が元taskのACと等しく、Boundaryが元taskとspecのOwns内、Seamがdesignに存在し、依存関係が循環しない場合は、元taskを次の未使用IDを持つ分割taskへ置き換える。元taskの `Blocked by` は分割後のすべてのroot taskへ継承し、元taskに依存していた後続taskは完了に必要なすべてのterminal taskへ付け替える。分割後のtaskは元のgroupに入れ (上限の目安を超える分は次のgroupへ送る)、分割後のtaskだけを担当するverifierでPhase 3.0を続ける。条件を満たさない、または2回の再分解でも大きすぎる場合はそのtaskをblockedへ移してgroupから外す
4. Run Logに `checks=<IMPLEMENTER | READY (n) | REVIEW_ONLY (n) | TOO_LARGE>` を記録する (verifierを使わなければIMPLEMENTER。nはverifier対象のAcceptance Criteriaの件数)

## Phase 3.1: 実装とレビュー (groupごと)

**1 group = 1イテレーション**で直列に処理する。groupの全taskを1つのimplementerに渡す。groupは同じworktreeを共有し、承認ごとに親がcommitして `PROTECTED_CHECK_FILES` のハッシュを照合するため、複数groupを並列に実装すると未commit変更とハッシュの照合が混ざる。

1. **implementerの起動**: テンプレートに以下を合成して起動する
   - worktreeの絶対パス、base branch名と作業branch名
   - specのタイトルと本文の要約と、**contract (Requirements / Boundaries / Acceptance Criteria / Out of Scope)**
   - `design.md` の該当部分 (spec modeのみ。実装設計) と、適用対象のacceptedな判断 (ADRを含む) (あれば)
   - `TASK_BRIEF`、採用済みの `CHECK_FILES` / `CHECK_COMMANDS`、`PROTECTED_CHECK_FILES` (変更禁止)、事前検査の `CHECK_BASELINES` (あれば)。review-onlyのtaskがあれば、そのtask IDとAcceptance Criteria。当該groupの事前検査が無ければ、その一覧は空でよい。先行groupの保護対象は引き続き渡す
   - 担当groupの各taskの説明、Boundary、Done when、Seam、Blocked by、Phase 1で決めた実装方針
   - groupに関係する検証コマンド
   - これまでのImplementation Notes (あれば)
2. **STATUSの処理**: `## Status Report` の `- STATUS:` フィールドだけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する
   - `READY_FOR_REVIEW` → implementerの `CHECK_FILES` がrepository規約に沿った検査・fixture・テストヘルパーであり、production codeを含まないことを確認して検査ファイル全体へ加える。`CHECK_COMMANDS` をtask / Acceptance Criterionへ対応づけて採用する。事前検査のコマンドは維持し、採用済みコマンドの削除・変更はAcceptance Criteriaに基づく理由を確認し、変更前後と理由をreviewerへ渡す。implementerの `REVIEW_ONLY` を保持し、コマンドが無いcriterionのtaskもreview-onlyへ加える。バグ修正では `REPRODUCTION` に修正前の失敗と修正後の成功の証拠があることも確認する。不足があればそのimplementerに1回だけ補充させ、解消しなければ `BLOCKED` と同じ原因調査へ進む。採用した検査一覧をユーザーに簡潔に示し、3へ進む
   - `CHECK_DISPUTE` → 親が `DISPUTE` の主張を該当taskのAcceptance Criteriaと照らして裁定する。検査が誤っていればverifierに `DISPUTE` を渡して1回だけ作り直させ (Phase 3.0と同じ種別・根拠・実行結果の確認とハッシュ更新を行う)、更新後の検査と `CHECK_BASELINES` を添えてimplementerを継続する。検査が正しければ裁定理由を添えてimplementerを継続する。裁定は同一taskで1回まで
   - `NEEDS_CONTEXT` → `MISSING` の不足情報を用意して1回だけimplementerを継続する。解決しなければ中止し、Phase 1と同じ形式でユーザーに質問する
   - `BLOCKED` → Phase 3.1'のdebuggerへ進む
3. **reviewerの起動**: テンプレートに、groupの各taskの文脈と全Acceptance Criteria、contract、`TASK_BRIEF`、`design.md` の該当部分 (spec modeのみ)、適用対象のacceptedな判断 (ADRを含む) (あれば)、`CHECK_COMMANDS`、`CHECK_FILES`、`PROTECTED_CHECK_FILES` とそのハッシュ、採用済みコマンドの変更前後と理由 (あれば)、review-onlyのtask (あれば)、Implementation Notesにある既知のflakyテスト (あれば)、groupに関係する検証コマンド、implementerのStatus Report (参照用)、周回 (`ROUND`) を合成して起動する。2周目以降は前回の `FINDINGS` と `REMEDIATION` も渡す (reviewerは前回指摘の解消を先に判定し、新規のREJECT根拠を検査の失敗・回帰・保護された検査ファイルの改変・実在性・Boundary違反・Acceptance Criterionの未充足に限る)
4. **VERDICTの処理**: `## Review Verdict` の `- VERDICT:` フィールドだけをパースする
   - `APPROVED` → 親がworktreeで全 `CHECK_COMMANDS` を実行し、`PROTECTED_CHECK_FILES` のハッシュを照合する (reviewerの `MECHANICAL_RESULTS` を検証の代わりにしない。`MECHANICAL_RESULTS` に `NOT_RUN` の項目があればそのコマンドも実行する)。`AC_RESULTS` がgroupの全Acceptance Criteriaを覆い、全項目が充足であることを確認する。review-onlyのcriterionは、各 `file:line` が実在して主張と一致することも親がReadして確かめる。reviewerが `FLAKY` と報告したテストは、親も単独で再実行して確かめ、Implementation Notesに既知のflakyテストとして記録する。1つでも失敗、または不一致なら、その証拠を添えて `REJECTED` と同じ差し戻しを行い、Run Logの `reject=` に `mismatch` を記録する。すべて通れば group完了。**先にworktree内でそのgroupの変更 (検査ファイルを含む) をcommitし** (Conventional Commits形式で、groupのtaskのタイトルを要約したメッセージ)、成功後に `tasks.md` のgroupの各taskを `Status: done` へ更新する (Issueへは書き込まない)。commit対象の差分が無い場合は、前回実行でcommit済みとみなしてstatus更新だけを行う。この順序により「done = commit済み」が常に成り立ち、中断してもコードが失われない。`NOTES` と全taskの検査一覧は最終検証のために保持する。implementerを終了し、Run Logに周回数、差し戻しの証拠種別、結果を記録し、次のgroupへ進む
   - `REJECTED` で根拠がChange Outline外のパスだけの場合: そのパスが担当groupのtaskのAcceptance Criteriaに必要で、かつspecのOwns内なら、親がメインrepo側の `design.md` のChange Outlineへそのdirectoryを追記し、Implementation Notesに1行残してreviewerだけを再起動する (差し戻しの周回に数えない)。Owns外、または必要性を示せない場合は次の通常の差し戻しとする
   - `REJECTED` → 同じimplementerを継続する。渡すのは `REMEDIATION`、`FINDINGS`、reviewerが実行して失敗したコマンドの生の出力 (`MECHANICAL_RESULTS` と `FINDINGS` の証拠 (a))。継続できない環境では新規に起動し、前回のimplementerが取った方針の要約1行 (`EVIDENCE` と `FILES_CHANGED` から親が作る。「駄目だった方針」として渡す) を加え、worktreeに残る前回の未commit変更を `git diff` で確認させてから直させる。同一groupの差し戻しは**最大2周**とし、2周後もREJECTEDならPhase 3.1'のdebuggerへ進む。周回は親がgroupごとに数え、REJECTEDを受けるたびにRun Logの `rounds=` を更新してから次の行動を決める。指摘が毎回新しい、または残り1件であることを理由に3周目の継続をしない (修正が同じ機構で新しい回帰を生み続けるときは、局所修正ではなくroot causeの見直しが要る)
5. **知見の伝播**: group横断で有用な発見は、`tasks.md` 末尾の `## Implementation Notes` へ1行で永続化し、以降のverifierとimplementerのプロンプトに含める

中断後に再実行された場合は、Phase 1のキュー構築が完了taskをスキップし、未完了taskだけでgroupを区切り直すため、未完了taskから再開される。未完了taskの検査はcommitされていないため、Phase 3.0からやり直す。
