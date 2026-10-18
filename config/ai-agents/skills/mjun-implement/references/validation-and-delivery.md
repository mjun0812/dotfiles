# Validation and Delivery

実行可能なtaskが尽きた後の手順: Phase 3.2 (ADRと整理)、Phase 3.3 (feature単位の検証)、Phase 4 (commitとPR作成・merge)、Phase 5 (結果の表示)、Phase 6 (worktreeクリーンアップ)。

全taskがdoneのときだけPhase 3.2〜4を行う。doneでないtaskが残るなら、specをactiveのまま `PARTIAL` としてPhase 5へ進む。

整理をfeature単位の検証より先に行い、feature全体の検証コマンドは最後の内容に対して1回だけ実行する。親の検査はすべて `run_checks.sh` で行うので、内容が変わっていなければ、後の手順に同じコマンドを渡しても成功済みのものは省かれる。

## Phase 3.2: ADRと整理

1. ADRを書く。対象は、spec modeの `design.md` の `## Decisions` で `ADR: 要作成` の判断と、どのmodeでも実装中に生じた、[ADRにする基準](../../mjun-steering/references/glossary_and_adr.md#adrにする基準) の3条件を満たす判断である。置き場は [置き場所の決め方](../../mjun-steering/references/glossary_and_adr.md#置き場所の決め方) に従い、Git管理なら作業中のworktreeの `docs/adr/`、ローカルならメインrepositoryの `.mjun/steering/adr/` とする。未決定のまま実装中に新しく3条件を満たす判断が生じたら、ADRを書かずに、その案をPhase 5で示して置き場所を聞く。既存ADRを覆すなら旧ADRに `Status: superseded by ADR-NNNN` を足す。spec modeでは、`design.md` (メインrepositoryの絶対パス) の `ADR:` 行を書いたADRの番号に置き換える。contractを変える判断なら、先にspecへ戻して再承認を得る。ADRを観察するAcceptance Criteriaは、Phase 3.3で確かめる。Phase 3.3の差し戻しで新たに3条件を満たす判断が生じたら、検証をやり直す前に同じように書く
2. 整理するかを決める。reviewerの `NOTES` が1件以上あれば手順3へ進む。無ければRun Logの `feature:` 行に `refactor=SKIPPED` を残してPhase 3.3へ進む。briefを起点にした場合 (バグ修正、refactoring、性能改善) は、`NOTES` があっても整理を省いて `refactor=SKIPPED` を残し、`NOTES` はPhase 5の報告とPR本文に回す。どれも変更を必要な範囲に留めることを重視する作業で、整理の変更を足すと、確かめた範囲の外に差分が広がるからである
3. refactorerを起動する。開始前に、worktreeのrootで全 `CHECK_FILES` の `shasum -a 256` を `<run-dir>/refactor/protected.sha256` へ書き出す。このpassでは、作成者によらず全検査ファイルを変更禁止とする (振る舞いを変えていないことを、検査の不変で示すため)。全taskの `NOTES`、全 `CHECK_COMMANDS` と `CHECK_FILES`、検証コマンドを `<run-dir>/refactor/brief.md` に書いて渡す
4. `## Refactor Report` の `- STATUS:` をパースする。`SKIPPED` なら何もしない。`DONE` なら、Phase 3.3の手順1と同じコマンド一式を親が `run_checks.sh` (`<name>` は `refactor`) で実行する。失敗があれば、手順5の `REJECTED` と同じく整理を戻す。すべて通れば、`check_mechanical.sh <worktree> HEAD --protected <run-dir>/refactor/protected.sha256 --out <run-dir>/refactor/mechanical.md` (spec modeでは `--design` も) を実行し、通らなければ同じく整理を戻す。通れば、reviewerを `ROUND: refactor` で起動する。起動promptには親の検査結果 (`summary.md` のパス) と機械的な確認の結果 (`mechanical.md` のパス) を書く
5. `APPROVED` なら `refactor:` 種別でcommitし、ID検査を `log HEAD~1..HEAD` で実行する (検出されたら `git commit --amend` で直す)。`REJECTED` なら、refactorerの `FILES_CHANGED` だけを `git checkout -- <files>` で戻す。失うのは整理だけで、taskのcommitには影響しない。再試行はしない。Run Logの `feature:` 行に `refactor=<DONE | SKIPPED | REJECTED>` を残す

## Phase 3.3: feature単位の検証

groupごとのレビューでは見えない、feature全体としての充足と整合を確かめる。検証コマンドの実行 (手順1) と機械的な確認 (手順5) は親が自分で行う。手順2〜4はSubAgentに調べさせてよいが、判定は親が結果に基づいて行う。

1. TEST / LINT / BUILD全体と `SMOKE_COMMANDS`、全taskの `CHECK_COMMANDS` を `run_checks.sh` (`<name>` は `feature`) で実行する。`SMOKE_COMMANDS` が無ければ、各taskの `CHECK_COMMANDS` のうちend-to-endに最も近いものを代わりに使い、それも無ければ「実行時検証: 未実施」とする。`design.md` のTest Strategyに実機の操作シナリオがあれば、親が実行できる手段 (UIなら `agent-browser` skill) で実行して結果を残し、実行できなかったものはPhase 5で手動確認の手順として示す。UIのシナリオでは、操作後の状態をスクリーンショットで、動きを確かめるものは動画で撮り、`<repo-root>/.mjun/evidence/<branch-name>/` に保存する。`<run-dir>` と違って片付けで消さないのは、人間がPR作成などの後にこの画像で目視するためである。`(目視)` のシナリオは、見本 (試作で選んだ案の画像) があれば並べて撮る
2. specのAcceptance Criteriaを1件ずつ、それを証明する検査と実装に対応づける。証明する検査が無いcriterionは実装と検証結果から判定し、判定できなければ未充足とする。doc modeでも、taskキューのAcceptance Criteriaは照合する
3. task同士が共有するinterface、データ形、エラー形式、設定が一致しているかをコードで確かめる
4. branch全体の変更 (`git diff <base>..HEAD`) が、specのBoundaries (Owns / Does Not Own) とOut of Scopeに収まるかを照合する。BoundariesとOut of Scopeがどちらも無ければ省く
5. `check_mechanical.sh <worktree> <base-branch> --final` を実行する。spec modeでは `--design` と、全taskの `CHECK_FILES` を書いた `--exclude` を付ける。`Change Outline` の `OUTSIDE` はboundary違反、骨組みの未実装 (`Skeleton stubs`) の残りはcriterionの未充足として扱う

判定は次のとおり。

- 検証コマンドがすべて成功し、全criterionが充足し、task間が整合し、boundary違反が無い → `GO`。Phase 4へ進む
- 他はすべて成功だが、実行時検証が未実施、実行できなかった操作シナリオがある、`(目視)` のシナリオがある、またはreview-onlyのtaskがある → `MANUAL_VERIFY_REQUIRED`。`(目視)` のシナリオは、実行して画像を撮れても合否を人間が決めるので、これに当たる。止まらずにPhase 4へ進み、Phase 5の報告とPR本文の検証結果に、人間が確かめることと画像を示す
- 検証コマンドの失敗、criterionの未充足、task間の不整合、boundary違反のどれかがある → 差し戻す。該当criterionを持つtaskの文脈と問題の内容、全taskの `CHECK_COMMANDS` / `CHECK_FILES`、`PROTECTED_CHECK_FILES` のハッシュを `<run-dir>/feature/brief.md` に書き、implementerを新しく起動して渡す (合わせて2周まで。2周目は同じimplementerを継続する)。検査を直すときはPhase 3の保護対象の規則に従う。修正後の報告は、Phase 3.1の手順2〜4 (親の検査とreviewer) を通してから、この検証を手順1からやり直す。最終検証の後の変更だけがboundaryの照合などを迂回しないようにするためである。収束しなければ中止し、未充足のcriterionを示す

Run Logの `feature:` 行に `validation=<GO | MANUAL_VERIFY_REQUIRED | NO-GO>` を残す。

## Phase 4: commitとPR作成・merge (git-commit / github-pr-create に連結)

作業ディレクトリをworktreeの絶対パスに切り替えて行う。commit messageやPR本文に、`.mjun/` 配下のパス、内部spec文書、spec内部の識別子を含めない。外へ見せるspecの参照はGitHub Issue番号だけである。選ばれたところまでだけを行う。選ばれていないmergeやpushは、ユーザーが判断を保留したものを勝手に進めることになる。

1. `git-commit` skillで、Phase 3のtask commitに含まれない残りの変更 (最終検証での修正、Git管理側のADRなど) をcommitする。残りが無ければ省く。commitしたらID検査を `log HEAD~1..HEAD` で実行し、検出されたら `git commit --amend` で直す
2. baseへ再同期する。worktreeを作った後に、並行する他のspecの成果がmergeされている場合に備える。`--no-pr` と `--merge` でも行う
   - `git fetch` で `<base-branch>` を最新にし、作業branchをその上へ `git rebase` する。remoteが無ければfetchを省いてlocalの `<base-branch>` を使う。remoteに同名branchが既にあれば、rebaseではなく `git merge` で取り込む
   - conflictが出たら自動で解決せず中止し、worktreeとbranchを残して衝突ファイルを報告する
   - 再同期後、Phase 3.3の手順1と同じコマンド一式を `run_checks.sh` (`<name>` は `base-sync`) で実行する。失敗があれば、Phase 3.3の差し戻しと同じ手順 (implementer → reviewer、合わせて2周まで) で直し、`git-commit` skillでcommitする。収束しなければ中止し、worktreeとbranchを残して報告する
   - Run Logの `feature:` 行に `base-sync=<CLEAN | FIXED | CONFLICT>` を足す
3. branch全体にID検査を `diff <base-branch>` と `log <base-branch>..HEAD` で実行する。コードの検出は直して `git-commit` skillでcommitし、commit messageの検出は該当commitを書き直す (pushしていないcommitに限る。push済みなら報告に残す)
4. `--no-pr`: ここで終え、Phase 5へ進む。base branchへのmergeはしない
5. `--merge`: メインrepositoryのworking treeが `<base-branch>` をcheckoutしていて未commit変更が無いことを確かめ、そこで `git merge --ff-only <branch-name>` を実行する。条件を満たさない、またはfast-forwardできなければmergeせず、worktreeとbranchを残して報告する。pushはしない。Phase 5へ進む
6. `--pr`: `github-pr-create` skillでPRを作る。push、PRのタイトルと本文、PR作成は連結先skillが行うので、手順を再実装しない
   - Phase 1で決めた出力言語を `language` として渡す
   - Phase 3.3で撮った画像があれば、パスと、画像ごとのシナリオ (`(目視)` なら人間の確かめる点) を渡し、検証結果の節に添付させる
   - specかbriefが `Source: #N` を持つなら、そのIssue番号を `spec` として渡す (PR本文の `Closes #N` になる)。純Local specでは渡さない。specは内部文書なので、PR本文では触れない。PRレビューでcontractとの整合を確かめるときは、Local specのパスを `--spec` で直接渡す
7. `--pr` の結果を確かめる。`gh pr view <url> --json url,state` でURLと状態を見る。`Source: #N` を持つspecやbriefでは本文に `Closes #N` があることを確かめ、無ければ `gh pr edit --body-file` で足す。PRのタイトルと本文 (`gh pr view <url> --json title,body`) にID検査を `text` で実行し、検出されたら `gh pr edit` で直す。PR作成に失敗したら、worktreeを片付けずにエラーを伝えて中止する
8. 選ばれたところまで進め終えたら (`--pr` はPR作成の成功後、`--no-pr` はcommitの完了後、`--merge` はmergeの成功後)、specのfrontmatterを `status: done` にする。briefを起点にした場合は、briefの `status` を `done` にする。それ以外のdoc modeでは省く。以降、このspecやbriefは逆引きや一覧の対象から外れる

## Phase 5: 結果の表示

- Outcome: `COMPLETE` / `PARTIAL`
- Source: Issue番号とタイトル / specパス
- Branch: 作成したbranch名
- PR: PRのURL。`--no-pr` なら「PRなし。成果はbranch `<name>` にある」、`--merge` なら「PRなし。`<base-branch>` へfast-forward merge済み」、`PARTIAL` なら「未作成。完了taskのcommitはbranch `<name>` にある」
- 変更概要: ファイル数、追加/削除行数 (`git diff --stat <base>..HEAD`)
- task進捗: 完了task数と、resumeで飛ばした完了済みtask数
- Checks: groupごとの検査数 (task別の内訳付き) と結果。review-onlyのtaskがあれば、そのtask IDと自動検査で覆えなかった理由
- AC coverage: 充足数 / 総数と、criterionごとの判定と証明した検査
- Validation: Phase 3.3の判定 (GO / MANUAL_VERIFY_REQUIRED。`PARTIAL` では「未実施」)。実行時検証が未実施なら、その旨と手動で確かめる操作シナリオ。`(目視)` のシナリオとreview-onlyのtaskは、人間が確かめることを1行ずつ、画像のパスと一緒に示す
- Base sync: CLEAN / FIXED (修正内容) / CONFLICT (衝突ファイル) (`PARTIAL` では「未実施」)
- Refactor: DONE / SKIPPED / REJECTED (`PARTIAL` では「未実施」) と、見送ったNOTES
- Run Log: 周回数と差し戻しの要約 (`tasks.md` の `## Run Log` から)
- Blocked Tasks: task IDとタイトル、直接原因、再開条件、これに依存して未実行のtask。無ければ「なし」
- ADR: 書いたADRの番号。無ければ「なし」。置き場所が未決定で書かなかったADRの案があれば、その案
- Follow-ups: 今回の範囲では扱わず、後で取り組む価値のあるもの。specのOut of Scopeのうち別の作業として検討すると書かれたもの、見送ったNOTES、implementerの `CONCERNS` (範囲外の同じ誤りなど) を1行ずつ並べる。Out of Scopeのうち「やらない」と決めたもの (変えてはいけない振る舞いなど) は含めない。無ければ「なし」
- modelやeffortを指定できなかった場合は、その旨

結果を示したら、次を1回の確認にまとめて聞く。どちらも無ければ聞かずに終える。

- Follow-upsがあり、GitHub remoteがあれば、Issueにするものを選んでもらう (AskUserQuestionの複数選択)。選ばれたものは、1件ずつ `github-issue-create` skillで起票する。specやbriefはこの後で使い捨てになり、ここで拾わないと失われるからである
- 書かなかったADRの案があれば、置き場所 (Git管理 / ローカル) を聞き、選ばれた場所に書く。Git管理を選ばれたら、作業branchとは別のcommitになるので、その届け方も同じ確認で聞く

## Phase 6: worktreeクリーンアップ

成果を失わずに、この実行で作ったものだけを片付ける。Phase 2で起動場所のworktreeを採用した場合は、結果にかかわらずworktreeとlocal branchを削除しない (用意した呼び出し元が片付ける)。以下は、この実行でworktreeを作成した、またはresumeで採用した場合である。

- `--pr` で成功: `git worktree remove --force <worktree-path>` → `git branch -D <branch-name>` (remote branchはPRのheadとして残る)
- `--no-pr` で成功: worktreeだけを削除し、local branchは残す。merge / pushの判断はユーザーに委ねる
- `--merge` で成功: worktreeを削除し、merge済みのlocal branchを `git branch -d <branch-name>` で削除する
- PR作成の失敗、`--merge` でmergeできなかった、Phase 4の再同期でconflictした、または再検査が収束しなかった: worktreeとlocal branchを残して報告する (手で直す余地を残す)
- `PARTIAL`: task隔離の後にworktreeがcleanなら、この実行で新規作成したworktreeだけを削除してlocal branchは残す。resumeで採用した既存worktreeは残す。変更の所有を特定できずcleanにできなければ、worktreeとbranchを残して警告する
- Phase 2〜5の途中でエラーやユーザーの中止により中断: この実行で新規作成したworktreeを削除し、commitがあればbranchを残してその旨を報告し、commitが無ければbranchも削除する。resumeで採用した既存worktreeとbranchは削除しない。ユーザーが再開を前提に一時停止を指示したなら、worktreeとbranchを残す。未commitの検査 (doneに達していないtaskのもの) は削除で失われ、resumeではPhase 3.0からやり直す
- `COMPLETE` なら `<run-dir>` を削除する。それ以外は残す (resumeで成功済みのコマンドの記録を再利用できる)。`.mjun/evidence/<branch-name>/` は、どの場合も削除しない
- 片付けに失敗したら、ユーザーに警告する
