# Group Loop

Phase 3.0 (実装準備と必要な事前検査) とPhase 3.1 (実装とレビュー) をgroupごとに繰り返す手順と、Run Logの形式。role、受け渡しファイル、検査の扱いは [SKILL.md](../SKILL.md) のPhase 3にある。

## Run Log

`tasks.md` 末尾の `## Run Log` に、groupごとに1行を追記する (resumeでは既存行を残して足す)。briefを起点にしたdoc modeでは、briefの末尾の `## Run Log` に追記する。種類ごとの結果を、後で振り返れるようにするためである。それ以外のdoc modeでは残さない。後で原因を分析する材料なので、周回数、差し戻しの証拠種別、reviewer起動前の差し戻し回数 (`precheck=`)、debuggerの分類を残す。証拠種別は、a (失敗コマンドの出力)、b (file:line + 引用)、mismatch (承認後の親の確認がreviewerの判定と食い違った) のいずれか。groupから外れてblockedになったtaskは別行にする。

```text
- skeleton: APPLIED
- T-001: verifier=none | checks=IMPLEMENTER | rounds=1 | result=done
- T-006: verifier=T-006 (期待値を独立して確定) | checks=READY (3) | rounds=2 | reject=[a, b] | debug=LOGIC_ERROR→RETRY_TASK | result=done
- T-002,T-003,T-004: verifier=none | checks=IMPLEMENTER | rounds=1 | precheck=1 | result=done
- T-005: verifier=T-005 (ユーザーが事前検査を指定) | checks=REVIEW_ONLY (3) | rounds=1 | result=done
- feature: refactor=DONE | validation=GO | base-sync=CLEAN
```

## Phase 3.0: 実装準備と必要な事前検査 (groupごと、実装前)

groupの各taskについて、成功の定義 (`TASK_BRIEF`) と、必要なら実装から独立した事前検査を揃える。

1. groupの各taskの `Blocked by` が、すべて `done` か同じgroupで先に並ぶtaskであることを確かめ直し、満たさないtaskは依存待ちへ戻す。spec modeでは、メインrepository側の `tasks.md` でgroupの各taskを `Status: in-progress` にする。taskを隔離するときに戻す先として、HEADと `git status --porcelain` を記録しておく
2. 親が各taskのAcceptance Criteria、Done when、Seam、既存の設計制約と検証コマンドを `TASK_BRIEF` にまとめ、groupの `brief.md` を書く。新しい設計や検査はここで作らない。verifierの使用条件 ([SKILL.md](../SKILL.md) のrole) に当たるtaskだけを選び、task IDと具体的な理由をRun Logの `verifier=` に残す。ふつうは `verifier=none` で、手順3を省く。対象があれば、対象taskと理由、formatterとlintの実行コマンドを起動promptに書いてverifierを起動する
3. verifierの `## Check Report` の `- STATUS:` をパースする。どのSTATUSでも、`READY` のtaskは次のように採用する。verifierの `TASK_BRIEF` をそのtaskのBriefに反映し、`CHECK_FILES` を検査ファイル全体と `PROTECTED_CHECK_FILES` に加える。`CHECK_COMMANDS` と `CHECK_BASELINES` は保持し、下の採用確認を行う
   - 採用確認: 事前検査は実装の正しさを決める基準になるので、検査自身が正しいことを先に確かめる。`CHECK_BASELINES` の種別と根拠をAcceptance Criterionと対象コードに照らし、`CHECK_COMMANDS` を `run_checks.sh` で実行する。未充足の振る舞いを確かめる検査が失敗 (RED) し、回帰検査が成功 (GREEN) すればよい (REDの検査は `FAIL` と出る)。種別や根拠の欠落・不適切、または期待と違う結果があれば、検査名と証拠を添えてverifierに1回だけ直させる。正しい回帰検査を、失敗させるために作り直させない。`CHECK_LINT` のformatterが `NOT_RUN` なら、親がそれを `CHECK_FILES` に実行し、失敗すればその出力を添えて1回だけ作り直させる。確認できたら `<run-dir>/protected.sha256` を書き出し ([SKILL.md](../SKILL.md) の検査ファイルの扱い)、検査一覧 (task / Acceptance Criterion → コマンド、種別、RED / GREEN) をユーザーに示す。承認は取らない。人間はここで「この検査が通れば完了」を確認する
   - `CHECKS_READY`: 上の採用確認だけを行う
   - `CANNOT_VERIFY`: `CANNOT_VERIFY` のtaskについて `METHOD` と `MISSING` を記録し、そのtaskだけを担当するfresh verifierに、試した方法と不足を渡して未試行の方法を選ばせる。初回を含めて2回まで試す。検査にできたらgroupへ合流させる。2回とも駄目なら、そのtaskをreview-onlyとしてgroupに残す。implementerにはAcceptance Criteriaをそのまま成功の定義として渡し、reviewerには `REVIEW_ONLY` として全criterionを `file:line` で照合させる。review-onlyのtaskが1件でもあれば、Phase 3.3の判定は `GO` ではなく `MANUAL_VERIFY_REQUIRED` になる。検査づくりが難航しても、verifierを待たずに複数groupをまとめて実装する進め方へ切り替えない
   - `TASK_TOO_LARGE`: spec modeでは、このgroupでverifierが作った `CHECK_FILES` を [recovery.md](recovery.md) の隔離の規則で取り除き、`TOO_LARGE` のtask IDと `SPLIT_PROPOSAL` (分割の材料。そのまま採用しない) を文脈に `mjun-to-tasks` で再分解させ、Phase 1の手順4からキューとgroupを組み直す。doc modeでは、`SPLIT_PROPOSAL` を自分で確かめて会話内のキューを直す。条件は、分割後のACの和集合が元のACと等しいこと、Boundaryが元taskの責務内に収まること、依存が循環しないことである。満たせば元taskを未使用IDの分割taskに置き換え、元taskの `Blocked by` を分割後の全root taskへ、元taskに依存していたtaskの依存を全terminal taskへ付け替え、分割後のtaskだけを担当するverifierでPhase 3.0を続ける (上限を超える分は次のgroupへ送る)。どちらのmodeでも、条件を満たさない、または再分解を2回しても大きすぎるtaskはblockedへ移してgroupから外す
4. Run Logに `checks=<IMPLEMENTER | READY (n) | REVIEW_ONLY (n) | TOO_LARGE>` を残す (verifierを使わなければ `IMPLEMENTER`。nはverifier対象のAcceptance Criteriaの件数)

## Phase 3.1: 実装とレビュー (groupごと)

groupの全taskを1つのimplementerに渡し、親の検査とreviewerを通った時点でcommitしてからdoneにする。groupは1つずつ直列に処理する。

1. groupの `brief.md` がverifierの結果 (先行groupの保護対象を含む) まで反映していることを確かめ、implementerを起動する
2. `## Status Report` の `- STATUS:` をパースする
   - `READY_FOR_REVIEW`: reviewerの時間を、親の検査で落ちる実装に使わない。次の順に確かめ、どこかで失敗したらreviewerを起動せずに同じimplementerを継続して直させる (原因がgroupの外にあれば `BLOCKED` で返させる)。この差し戻しは周回に数えず、回数を `precheck=` に残す。同じ項目で2回戻しても残るなら、`BLOCKED` と同じ原因調査へ進む。変更前から同じように失敗していた証拠がある項目と、Implementation Notesにある既知のflakyテストは除く
     1. `CHECKS_RUN` と `TESTS_RUN` に、FAILや完了しなかった実行 (hang、timeout、途中で止めたもの) が無い
     2. 報告の内容を採用できる。`CHECK_FILES` は検査・fixture・テストヘルパーだけでproduction codeを含まず、`CHECK_COMMANDS` はtask / Acceptance Criterionに対応している。事前検査のコマンドは残っている。採用済みコマンドを削除・変更していれば、Acceptance Criteriaに基づく理由があり、変更前後と理由をreviewerへ渡す。コマンドの無いcriterionのtaskと、implementerの `REVIEW_ONLY` は、review-onlyに加える。バグ修正では `REPRODUCTION` に証拠の段階と修正前後の出力があり、testより下の段階のtaskはreview-onlyに加わっている。不足はimplementerに1回だけ補わせ、それでも足りなければ `BLOCKED` と同じ原因調査へ進む。採用した内容で `brief.md` を書き直す
     3. 採用した `CHECK_COMMANDS` とgroupに関係する検証コマンドが、親の `run_checks.sh` (`<name>` は `<group>-r<周回>`) で通る。変更と無関係に見えるテストだけが落ちたら、そのテストを単独で2回まで実行し直す。単独では通り、失敗が変更ファイルを通らないと示せれば、flakyとしてImplementation Notesと `brief.md` に記録して先へ進む
     4. `check_mechanical.sh <worktree> HEAD` が通る。spec modeでは `--design <run-dir>/design.md` を付ける。`--exclude` には採用した `CHECK_FILES` を1行1パスで書いた `<run-dir>/<group>/check_files.txt` を、保護対象があれば `--protected <run-dir>/protected.sha256` を、`--out` には `<run-dir>/<group>/mechanical-r<周回>.md` を渡す。Change Outlineの外のパス (`OUTSIDE`) があっても、そのパスが担当taskのAcceptance Criteriaに必要で、specのOwns内なら、差し戻さない。親がメインrepository側の `design.md` のChange Outlineへそのパスを足し、`<run-dir>/design.md` を置き直して実行し直す。足したことはImplementation Notesに1行残す。必要性を示せない、またはOwns外なら差し戻す。`Skeleton stubs` はここでは失敗にしない。後のgroupが埋める骨組みの未実装は、残っていてよい

     すべて通れば、採用した検査一覧をユーザーに簡潔に示して手順3へ進む

   - `CHECK_DISPUTE`: `DISPUTE` の主張を該当taskのAcceptance Criteriaと照らして親が裁定する。検査が誤っていれば、verifierに `DISPUTE` を渡して1回だけ作り直させ (Phase 3.0と同じ採用確認をして、ハッシュを記録し直す)、更新後の検査と `CHECK_BASELINES` を添えてimplementerを継続する。検査が正しければ、裁定理由を添えてimplementerを継続する。裁定は同じtaskで1回まで
   - `NEEDS_CONTEXT`: `MISSING` の情報を用意して1回だけimplementerを継続する。それでも解決しなければ中止し、Phase 1と同じ形でユーザーに質問する
   - `BLOCKED`: Phase 3.1'のdebuggerへ進む
3. reviewerを起動する。起動promptには、親の検査結果 (手順2の `summary.md` のパス)、親の機械的な確認の結果 (手順2の `mechanical-r<周回>.md` のパス)、採用済みコマンドの変更前後と理由 (あれば)、implementerのStatus Report (参照用)、周回 (`ROUND`) を書く。2周目以降は前回の `FINDINGS` と `REMEDIATION` も渡す
4. `## Review Verdict` の `- VERDICT:` をパースする
   - `APPROVED`: reviewerの判定を親が裏付ける。手順2と同じコマンドを `run_checks.sh` で実行し直す (reviewerはworktreeを変えないので、通常はすべて `CACHED (PASS)`)。`check_mechanical.sh` を手順2と同じ引数で実行し直し、`MECHANICAL_RESULTS` に `NOT_RUN` があればその確認も親が行う。`AC_RESULTS` がgroupの全Acceptance Criteriaを覆い、すべて充足であることを確かめ、review-onlyのcriterionは各 `file:line` を読んで主張と一致することを確かめる。どれか1つでも通らなければ (コマンドの失敗、機械的な確認の失敗、ACの不足や主張との食い違い)、親が自分で直さず、その証拠を添えて `REJECTED` と同じ差し戻しを行い、`reject=` に `mismatch` を残す
     - すべて通ったら、worktreeでgroupの変更 (検査ファイルを含む) をcommitしてから、`tasks.md` のgroupの各taskを `Status: done` にする。commitはConventional Commits形式で、groupのtaskのタイトルを要約したmessageにし、ID検査を `log HEAD~1..HEAD` で実行する (検出されたら `git commit --amend` で直す)。commitする差分が無ければ、前回の実行でcommit済みとみなしてstatusだけを更新する。この順序で「done = commit済み」が常に成り立ち、中断してもdoneのtaskのコードは失われない。Issueには書き込まない
     - `NOTES` と検査一覧はPhase 3.2と3.3のために保持する。implementerを終了し、Run Logに周回数、証拠種別、結果を残して次のgroupへ進む
   - `REJECTED`: 同じimplementerを継続し、`REMEDIATION` と `FINDINGS` (証拠aのコマンド出力を含む) を渡す。直した後の `READY_FOR_REVIEW` は手順2から処理する。継続できない環境では、新しいimplementerに、前回の方針の要約1行 (`EVIDENCE` と `FILES_CHANGED` から親が作る) を「駄目だった方針」として渡し、worktreeに残る前回の変更を `git diff` で確かめてから直させる。周回は親がgroupごとに数え、REJECTEDを受けるたびに `rounds=` を更新してから次を決める。差し戻しは同じgroupで2周までとし、その後もREJECTEDならPhase 3.1'のdebuggerへ進む。前回と同じ指摘 (同じAcceptance Criterionに同じ根拠) や同じ失敗出力が繰り返されたとき、reviewerの指摘が検査やspecの誤りを示すときは、周回によらずすぐdebuggerへ進む。指摘が毎回新しい、残り1件、という理由で3周目に進まない。修正が同じ機構で新しい回帰を生み続けるなら、局所修正ではなくroot causeの見直しが要る
5. group横断で役立つ発見は、`tasks.md` 末尾の `## Implementation Notes` へ1行で残し、以降のgroupの `brief.md` に含める

中断後に再実行すると、Phase 1が完了taskを飛ばして未完了taskだけでgroupを組み直す。未完了taskの検査はcommitされていないので、Phase 3.0からやり直す。
