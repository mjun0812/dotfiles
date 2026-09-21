# Validation and Delivery

実行可能なtaskが尽きた後の手順: Phase 3.2 (feature単位の検証)、Phase 3.3 (整理)、Phase 4 (commitと配送)、Phase 5 (結果の表示)、Phase 6 (worktreeクリーンアップ)。

## Phase 3.2: feature単位の検証

キュー再評価の結果、全taskがdoneの場合だけ行う。実行可能taskが尽きた時点でdoneでないtaskが残る場合は、Phase 3.2、3.3、4をスキップし、specをactiveのまま `PARTIAL` としてPhase 5へ進む。検証コマンドの実行 (手順1) は親が自分で行い、SubAgentの報告で代えない。判断を要する手順2〜4はSubAgentに依頼してよいが、判定は親が結果に基づいて行う。

1. **検証コマンドの実行**: TEST / LINT / BUILD 全体と `SMOKE_COMMANDS`。SMOKEが宣言されていない場合は、各taskの `CHECK_COMMANDS` のうちend-to-endに最も近いものを代用する。どちらも無ければ「実行時検証: 未実施」として扱う。`design.md` のTest Strategyに実機の操作シナリオがある場合は、親が実行できる手段でシナリオを実行して結果を記録し、実行できなかったシナリオはPhase 5で手動確認の手順として提示する
2. **Acceptance Criteriaの照合**: specのAcceptance Criteria 1件ごとに、それを証明する検査 (`CHECK_COMMANDS`) と実装を対応づける。証明する検査が無いcriterionは、実装と検証結果から充足を判定し、判定できなければ未充足とする。specにAcceptance Criteriaが無いdoc modeでも、taskキューのAcceptance Criteriaは照合する
3. **task間の整合**: task同士が共有するinterface、データ形、エラー形式、設定が一致しているかをコードから確認する
4. **contract境界の照合**: branch全体の変更 (`git diff <base>..HEAD`) がspecのBoundaries (Owns / Does Not Own) とOut of Scopeに収まっているかを照合する。spec modeでは `git diff --name-only <base>..HEAD` の全パスが `design.md` のChange Outlineのdirectory配下にあるかも確かめる (`CHECK_FILES` は除く)。specにBoundariesもOut of Scopeも無い場合はスキップする

判定:

- 検証コマンドがすべて成功し、全criterionが充足し、task間が整合し、boundary違反が無い → `GO`。Phase 3.3へ進む
- 実行時検証が「未実施」、実行できなかった操作シナリオがある、またはreview-onlyのtaskがあり、他はすべて成功 → `MANUAL_VERIFY_REQUIRED`。Phase 3.3へ進むが、Phase 5の報告とPR本文の検証結果に未実施を明記する
- 検証コマンドの失敗、criterionの未充足、task間の不整合、またはboundary違反 → 内容を添えてimplementerを新規に起動して差し戻す (合わせて最大2周。2周目は同じimplementerを継続する)。差し戻しは該当criterionを持つtaskの文脈で行い、全taskの `CHECK_COMMANDS` と `CHECK_FILES` のハッシュを渡す。**差し戻しで生じた修正は、Phase 3.1と同じreviewerの検査に合格してからPhase 3.3へ進む** (最終検証後の変更だけがboundary検査等を迂回する経路を作らない)。収束しなければ中止し、未充足のcriterionを明示して報告する

Run Logに `feature: validation=<GO | MANUAL_VERIFY_REQUIRED | NO-GO>` を記録する。

## Phase 3.3: 整理 (refactor pass)

Phase 3.2の判定がGOまたはMANUAL_VERIFY_REQUIREDのあと、reviewerの `NOTES` が1件以上あるか、Phase 3.2でtask間の重複が見つかった場合に行う。どちらも無ければスキップする。

1. **refactorerの起動**: テンプレートに、worktreeの絶対パス、contractのBoundariesとOut of Scope、全taskの `NOTES`、全 `CHECK_COMMANDS` と `CHECK_FILES`、検証コマンドを合成して起動する
2. `## Refactor Report` の `- STATUS:` だけをパースする。`SKIPPED` なら何もしない。`DONE` ならreviewerを `ROUND: refactor` で起動し、全taskの `CHECK_COMMANDS` と `CHECK_FILES` のハッシュ、検証コマンド、contractのBoundariesを渡す (全検査の通過、検査ファイルの不変、Boundary、振る舞いの不変を検査する)
3. `APPROVED` → `refactor:` 種別のcommitを作る。`REJECTED` → refactorerの `FILES_CHANGED` だけを `git checkout -- <files>` で戻す (失うのは整理だけで、taskのcommitは影響を受けない)。再試行はしない
4. Run Logの `feature:` 行に `refactor=<DONE | SKIPPED | REJECTED>` を追記する

## Phase 4: commitと配送 (git-commit / github-pr-create に連結)

メイン会話が、作業ディレクトリをworktreeの絶対パスに切り替えた上で実行する。commit messageやPR本文などの外部向け出力には、`.mjun/` 配下のパスや内部spec文書を含めない (外部へ見せるspecの参照はGitHub Issue番号だけを使う)。

1. **判断記録を確認する**: 実装中に新たな非自明な判断が生じた場合は、[共通記録規則](../../mjun-steering/references/glossary_and_adr.md) に従って解決済みの判断記録 (Git管理へ移行済みなら作業中のworktreeの `docs/adr/decisions.md`、未移行ならメインrepositoryの `.mjun/steering/decisions.md`) に追記し、spec modeではspec.mdの `Decisions:` にIDを加える。contractを変える判断は先にspecへ戻して再承認する。ADRは同じファイルのentryであり、配送時の転記や複製は行わない。
2. **`git-commit` skillでcommitを作成する**: 対象はPhase 3のtask commitに含まれていない残りの変更 (最終検証での修正、Git管理側の判断記録の追記など)。残変更が無ければスキップする
3. **baseへの再同期**: `git fetch` で `<base-branch>` を最新化し、作業branchをその上へ `git rebase` する (worktree作成後に並行する他のspecの成果がmergeされている場合に備える。`--no-pr` と `--merge` でも行う。remoteが無いrepositoryではfetchを省き、localの `<base-branch>` を使う。remoteに同名branchが既にある場合はrebaseではなく `git merge` で取り込む)。conflictが出たら自動解決せず中止し、worktreeとbranchを残して衝突ファイルを報告する。再同期後に全taskの `CHECK_COMMANDS` とTEST / LINT / BUILD / SMOKE (宣言済みのもの) を再実行し、失敗があればPhase 3.2の差し戻しと同じ手順 (implementer → reviewer、合わせて最大2周) で修正して `git-commit` skillでcommitする。収束しなければ中止し、worktreeとbranchを残して報告する。Run Logの `feature:` 行に `base-sync=<CLEAN | FIXED | CONFLICT>` を追記する
4. **`--no-pr` の場合**: ここで配送を終える。base branchへのmergeは行わない (選ばれていない配送をしない)。Phase 5へ進む
5. **`--merge` の場合**: メインrepositoryのworking treeが `<base-branch>` をcheckoutしていて未commit変更が無いことを確かめ、そこで `git merge --ff-only <branch-name>` を実行する。満たさない、またはfast-forwardできない場合はmergeせず、worktreeとbranchを残して報告する。pushはしない。Phase 5へ進む
6. **`--pr` の場合、`github-pr-create` skillでPRを作成する**:
   - Phase 1で決めた出力言語を `language` として渡す
   - **specが `Source: #N` を持つ場合はそのIssue番号を `spec` として渡す** (PR本文の `Closes #N` に使われる)。純Local specでは渡さない (specは内部文書であり、PR本文で言及しない。PRレビューでcontractを照合するときはLocal specのパスを `--spec` で直接渡す)
   - push、PRタイトルと本文の生成、PR作成はすべて連結先skillが行う。手順を再実装しない
7. **結果を検証する** (`--pr` のみ): 作成されたPRのURLと状態を `gh pr view <url> --json url,state` で確認する。`Source: #N` を持つspecでは本文に `Closes #N` が含まれるか確認し、無ければ `gh pr edit --body-file` で追記する。PR作成に失敗した場合はworktreeをクリーンアップせず、エラーを伝えて中止する
8. **specのstatusを更新する**: 配送の完了後 (`--pr` はPR作成成功後、`--no-pr` はcommit完了後、`--merge` はmerge成功後)、specのfrontmatterを `status: done` へ更新する (doc modeではスキップ)。以降このspecは照合、逆引き、一覧の対象から外れる

## Phase 5: 結果の表示

- **Outcome**: `COMPLETE` / `PARTIAL`
- **Source**: Issue番号とタイトル / specパス
- **Branch**: 作成したbranch名
- **PR**: 作成したPRのURL (`--no-pr` の場合は「PRなし。branch `<name>` に成果があります」。`--merge` の場合は「PRなし。`<base-branch>` へfast-forward merge済み」。`PARTIAL` の場合は「未作成。branch `<name>` に完了taskのcommitがあります」)
- **変更概要**: ファイル数、追加/削除行数 (`git diff --stat <base>..HEAD`)
- **task進捗**: 完了task数と、スキップした完了済みtask数 (resume時)
- **Checks**: groupごとの検査数 (task別の内訳付き) と結果 (Phase 3.0で作成した検査がすべて通ったか)。review-onlyのtaskがあれば、そのtask IDと検査化できなかった理由
- **AC coverage**: Acceptance Criteriaの充足状況 (充足数 / 総数と、各criterionの判定、証明した検査)
- **Validation**: Phase 3.2の判定 (GO / MANUAL_VERIFY_REQUIRED。`PARTIAL` では「未実施」)。実行時検証が未実施ならその旨と、手動で確かめる操作シナリオ
- **Base sync**: Phase 4の再同期の結果 (CLEAN / FIXED と修正内容 / CONFLICT と衝突ファイル。`PARTIAL` では「未実施」)
- **Refactor**: Phase 3.3の結果 (DONE / SKIPPED / REJECTED。`PARTIAL` では「未実施」) と、見送ったNOTES
- **Run Log**: 周回数と差し戻しの要約 (`tasks.md` の `## Run Log` から)
- **Blocked Tasks**: task IDとタイトル、直接原因、再開条件、これに依存して未実行のtask。無ければ「なし」
- **ADR**: 共通記録に追記したADRのD番号 (無ければ「なし」)

## Phase 6: worktreeクリーンアップ

- **`--pr` で成功した場合**: `git worktree remove --force <worktree-path>` → `git branch -D <branch-name>` (remote branchはPRのheadとして残る)
- **`--no-pr` で成功した場合**: worktreeだけを削除し、**local branchは削除しない**。merge / pushの判断はユーザーに委ねる
- **`--merge` で成功した場合**: worktreeを削除し、merge済みのlocal branchを `git branch -d <branch-name>` で削除する
- **PR作成に失敗した場合、`--merge` でmergeできなかった場合、またはPhase 4の再同期でconflictした、もしくは再検査が収束しなかった場合**: worktreeとlocal branchを残して報告する (手動修復の余地を残す)
- **`PARTIAL` の場合**: task隔離後にworktreeがcleanなら、この実行で新規作成したworktreeだけを削除してlocal branchは残す。resumeで採用した既存worktreeは残す。変更の所有を特定できずcleanにできない場合はworktreeとbranchを残して警告する
- **Phase 2〜5の途中でエラーまたはユーザーの中止により中断した場合**: この実行で新規作成したworktreeを削除し、commitが存在するならbranchを残してその旨を報告する。commitが無ければbranchも削除する。resumeで採用した既存worktreeとbranchは削除しない。ユーザーが再開を前提に一時停止を指示した場合は、worktreeとbranchを残す (未commitの検査と変更を保持する)。未commitの検査 (Phase 3.0で作成し、taskがdoneに達していないもの) は失われ、resume時にPhase 3.0からやり直す
- クリーンアップに失敗した場合はユーザーに警告する
