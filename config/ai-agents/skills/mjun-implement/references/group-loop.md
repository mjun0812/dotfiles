# Group Loop

Phase 3.0 (実装準備)とPhase 3.1 (実装とレビュー)をgroupごとに繰り返す手順と、Run Logの形式。role、受け渡しファイル、検査の扱いは [SKILL.md](../SKILL.md)のPhase 3にある。

## Run Log

`tasks.md` 末尾の `## Run Log` に、groupごとに1行を追記する (resumeでは既存行を残して足す)。briefを起点にしたdoc modeでは、briefの末尾の `## Run Log` に追記する。種類ごとの結果を、後で振り返れるようにするためである。それ以外のdoc modeでは残さない。後で原因を分析する材料なので、周回数、差し戻しの証拠種別、reviewer起動前の差し戻し回数 (`precheck=`)、debuggerの分類を残す。証拠種別は、a (失敗コマンドの出力)、b (file:line + 引用)、mismatch (承認後の親の確認がreviewerの判定と食い違った) のいずれか。groupから外れてblockedになったtaskは別行にする。

```text
- skeleton: APPLIED
- T-001: rounds=1 | result=done
- T-006: rounds=2 | reject=[a, b] | debug=LOGIC_ERROR→RETRY_TASK | result=done
- T-002,T-003,T-004: rounds=1 | precheck=1 | result=done
- T-005: review-only=3 | rounds=1 | result=done
- feature: refactor=DONE | verify=PASS 12, FAIL 0, INCONCLUSIVE 1 | validation=MANUAL_VERIFY_REQUIRED | base-sync=CLEAN
```

## Phase 3.0: 実装準備(groupごと、実装前)

groupの各taskについて、成功の定義(`TASK_BRIEF`)を揃える。

1. groupの各taskの `Blocked by` が、すべて `done` か同じgroupで先に並ぶtaskであることを確かめ直し、満たさないtaskは依存待ちへ戻す。spec modeでは、メインrepository側の `tasks.md` でgroupの各taskを `Status: in-progress` にする。taskを隔離するときに戻す先として、HEADと `git status --porcelain` を記録しておく
2. 親が各taskのAcceptance Criteria、Done when、Seam、既存の設計制約と検証コマンドを `TASK_BRIEF` にまとめ、groupの `brief.md` を書く。新しい設計や検査はここで作らない

## Phase 3.1: 実装とレビュー (groupごと)

groupの全taskを1つのimplementerに渡し、親の検査とreviewerを通った時点でcommitしてからdoneにする。groupは1つずつ直列に処理する。

1. groupの `brief.md` が先行groupで採用した検査まで反映していることを確かめ、implementerを起動する
2. `## Status Report` の `- STATUS:` をパースする
   - `READY_FOR_REVIEW`: reviewerの時間を、親の検査で落ちる実装に使わない。次の順に確かめ、どこかで失敗したらreviewerを起動せずに同じimplementerを継続して直させる (原因がgroupの外にあれば `BLOCKED` で返させる)。この差し戻しは周回に数えず、回数を `precheck=` に残す。同じ項目で2回戻しても残るなら、`BLOCKED` と同じ原因調査へ進む。変更前から同じように失敗していた証拠がある項目と、Implementation Notesにある既知のflakyテストは除く
     1. `CHECKS_RUN` と `TESTS_RUN` に、FAILや完了しなかった実行 (hang、timeout、途中で止めたもの) が無い
     2. 報告の内容を採用できる。`CHECK_FILES` は検査・fixture・テストヘルパーだけでproduction codeを含まず、`CHECK_COMMANDS` はtask / Acceptance Criterionに対応している。採用済みコマンドを削除・変更していれば、Acceptance Criteriaに基づく理由があり、変更前後と理由をreviewerへ渡す。コマンドの無いcriterionのtaskと、implementerの `REVIEW_ONLY` は、review-onlyに加える。バグ修正では `REPRODUCTION` に証拠の段階と修正前後の出力があり、testより下の段階のtaskはreview-onlyに加わっている。不足はimplementerに1回だけ補わせ、それでも足りなければ `BLOCKED` と同じ原因調査へ進む。採用した内容で `brief.md` を書き直す
     3. 採用した `CHECK_COMMANDS` とgroupに関係する検証コマンドが、親の `run_checks.sh` (`<name>` は `<group>-r<周回>`) で通る。変更と無関係に見えるテストだけが落ちたら、そのテストを単独で2回まで実行し直す。単独では通り、失敗が変更ファイルを通らないと示せれば、flakyとしてImplementation Notesと `brief.md` に記録して先へ進む
     4. `check_mechanical.sh <worktree> HEAD` が通る。spec modeでは `--design <run-dir>/design.md` を付ける。`--exclude` には採用した `CHECK_FILES` を1行1パスで書いた `<run-dir>/<group>/check_files.txt` を、`--out` には `<run-dir>/<group>/mechanical-r<周回>.md` を渡す。Change Outlineの外のパス(`OUTSIDE`)があっても、そのパスが担当taskのAcceptance Criteriaに必要で、specのOwns内なら、差し戻さない。親がメインrepository側の `design.md` のChange Outlineへそのパスを足し、`<run-dir>/design.md` を置き直して実行し直す。足したことはImplementation Notesに1行残す。必要性を示せない、またはOwns外なら差し戻す。`Skeleton stubs` はここでは失敗にしない。後のgroupが埋める骨組みの未実装は、残っていてよい

     すべて通れば、採用した検査一覧をユーザーに簡潔に示して手順3へ進む

   - `NEEDS_CONTEXT`: `MISSING` の情報を用意して1回だけimplementerを継続する。それでも解決しなければ中止し、Phase 1と同じ形でユーザーに質問する
   - `BLOCKED`: Phase 3.1'のdebuggerへ進む
3. reviewerを起動する。起動promptには、親の検査結果 (手順2の `summary.md` のパス)、親の機械的な確認の結果 (手順2の `mechanical-r<周回>.md` のパス)、採用済みコマンドの変更前後と理由 (あれば)、implementerのStatus Report (参照用)、周回 (`ROUND`) を書く。2周目以降は前回の `FINDINGS` と `REMEDIATION` も渡す
4. `## Review Verdict` の `- VERDICT:` をパースする
   - `APPROVED`: reviewerの判定を親が裏付ける。手順2と同じコマンドを `run_checks.sh` で実行し直す(reviewerはworktreeを変えないので、通常はすべて `CACHED (PASS)`)。`check_mechanical.sh` を手順2と同じ引数で実行し直し、`MECHANICAL_RESULTS` に `NOT_RUN` があればその確認も親が行う。`AC_RESULTS` がgroupの全Acceptance Criteriaを覆い、すべて充足であることを確かめ、review-onlyのcriterionは各 `file:line` を読んで主張と一致することを確かめる。review-onlyのtaskがあれば、Run Logに `review-only=<criterionの件数>` を残す。どれか1つでも通らなければ(コマンドの失敗、機械的な確認の失敗、ACの不足や主張との食い違い)、親が自分で直さず、その証拠を添えて `REJECTED` と同じ差し戻しを行い、`reject=` に `mismatch` を残す
     - すべて通ったら、worktreeでgroupの変更 (検査ファイルを含む) をcommitしてから、`tasks.md` のgroupの各taskを `Status: done` にする。commitはConventional Commits形式で、groupのtaskのタイトルを要約したmessageにし、ID検査を `log HEAD~1..HEAD` で実行する (検出されたら `git commit --amend` で直す)。commitする差分が無ければ、前回の実行でcommit済みとみなしてstatusだけを更新する。この順序で「done = commit済み」が常に成り立ち、中断してもdoneのtaskのコードは失われない。Issueには書き込まない
     - `NOTES` と検査一覧はPhase 3.2と3.3のために保持する。implementerを終了し、Run Logに周回数、証拠種別、結果を残して次のgroupへ進む
   - `REJECTED`: 同じimplementerを継続し、`REMEDIATION` と `FINDINGS` (証拠aのコマンド出力を含む) を渡す。直した後の `READY_FOR_REVIEW` は手順2から処理する。継続できない環境では、新しいimplementerに、前回の方針の要約1行 (`EVIDENCE` と `FILES_CHANGED` から親が作る) を「駄目だった方針」として渡し、worktreeに残る前回の変更を `git diff` で確かめてから直させる。周回は親がgroupごとに数え、REJECTEDを受けるたびに `rounds=` を更新してから次を決める。差し戻しは同じgroupで2周までとし、その後もREJECTEDならPhase 3.1'のdebuggerへ進む。前回と同じ指摘 (同じAcceptance Criterionに同じ根拠) や同じ失敗出力が繰り返されたとき、reviewerの指摘が検査やspecの誤りを示すときは、周回によらずすぐdebuggerへ進む。指摘が毎回新しい、残り1件、という理由で3周目に進まない。修正が同じ機構で新しい回帰を生み続けるなら、局所修正ではなくroot causeの見直しが要る
5. group横断で役立つ発見は、`tasks.md` 末尾の `## Implementation Notes` へ1行で残し、以降のgroupの `brief.md` に含める
6. reviewerの `FINDINGS` と `NOTES` に、lintにできそうな書き方の指摘があれば、候補として貯める。対象は、規約か原則を引用した指摘のうち、このtaskに限らず起こり、コードの形(構文、名前、行)を見れば判定できるものである。Acceptance Criterionの未充足、設計、テストの中身への指摘は足さない。`zsh <skill-dir>/../mjun-rule-lint/scripts/backlog.sh list <repo-root>` で同じ種類のkeyがあるかを見てから、`zsh <skill-dir>/../mjun-rule-lint/scripts/backlog.sh add <repo-root> <key> <引用された規約か原則> <file:line> <指摘の1行>` で足す。`<repo-root>` はメインrepositoryである。`<key>` は種類を表すkebab-caseの名前で、同じ種類には既存のkeyを使う。件数はkeyごとに数えるからである。同じkeyで同じ場所の指摘はscriptが足さないので、差し戻しの後に同じ箇所へ出た指摘を親が除く必要は無い。lintにすれば、同じ指摘をreviewerが繰り返さなくても、作業のたびに検出できる。ただし1回の指摘から作ると例外の多いlintが増えるので、ここでは貯めるだけにし、2回たまったものをPhase 5で知らせる

中断後に再実行すると、Phase 1が完了taskを飛ばして未完了taskだけでgroupを組み直す。未完了taskの検査はcommitされていないので、Phase 3.0からやり直す。
