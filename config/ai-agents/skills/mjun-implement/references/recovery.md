# Recovery

taskをblockedへ移すときの隔離と、差し戻しが収束しないときの原因調査 (Phase 3.1') の手順。

## 自律継続とtaskの隔離

- 各groupのPhase 3.0開始時にHEADと `git status --porcelain` を記録する。taskまたはgroupをblockedへ移すときは、その作業で変更したと証明できるtracked pathだけを開始時の状態へ戻し、その作業で作成したと証明できるuntracked pathだけを削除する。対象pathを特定できなければ、他の変更を失う危険があるため中止する。worktree全体へのresetやcleanは使わない
- taskをblockedへ移す場合、spec modeでは `Status: blocked`、`Blocked reason: <直接原因>`、`Resume when: <再開条件>` を `tasks.md` に記録し、doc modeでは同じ情報を会話内のキューに保持する。Run Logにも原因を追記し、blocked一覧へ加える。groupがblockedになる場合は、groupの全taskに同じ記録を行う
- blockedへ移した後はキューを再評価し、依存taskがすべてdoneの独立taskを続行する。blocked taskに依存するtaskは実行せず、依存待ちとして保持する。groupの一部のtaskだけがblockedになった場合は、そのtaskと、それに依存するgroup内のtaskをgroupから外し、残りのtaskでgroupを続行する
- taskの分割・順序・依存だけを直す変更は、contractのRequirements / Boundaries / Acceptance Criteria / Out of Scopeと外部から観察できる振る舞いを一切変えず、既存ACを欠落・追加・再解釈しない場合に限り、ユーザー確認なしでtaskキューへ反映する。contractの意味が変わる場合は自動修正せず `RETURN_TO_SPEC` として中止する
- 自動再分解とdebugger由来のtask計画修正は、それぞれ元taskごとに最大2回とする。上限後も実行可能にならないtaskはblockedへ移す

## Phase 3.1': 原因調査 (収束しないとき)

BLOCKED、または差し戻し2周後のREJECTEDで起動する。debuggerはfresh contextで動かし、失敗した試行の経緯は渡さない。

1. **debuggerの起動**: テンプレートに、失敗の内容 (`BLOCKER` または最後のreviewerの `FINDINGS` / `REMEDIATION`)、失敗したコマンドの生の出力、現在の `git diff`、verifierの `TASK_BRIEF` と `CHECK_COMMANDS`、contractの該当箇所、Implementation Notesを合成して起動する
2. **NEXT_ACTIONの処理**: `## Debug Report` の `- NEXT_ACTION:` だけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する
   - `RETRY_TASK` → `FIX_PLAN` と `NOTES` を渡して新しいimplementerを起動し、Phase 3.1の3以降を1周だけ行う
   - `FIX_CHECK` → 検査自体の誤り。`ROOT_CAUSE` を渡してverifierに作り直させ (RED確認とハッシュ更新を行う)、implementerを起動してPhase 3.1の3以降を1周だけ行う
   - `RETURN_TO_TASKS` → `TASKS_CHANGE` を検査する。contractの意味を変えず、taskの分割・統合・順序・依存変更、またはcontract/designですでに要求されている前提taskの追加だけで解決できる場合はキューへ反映し、現在groupの変更をtask隔離の規則で戻し、groupを区切り直してPhase 3.0から続ける。既存ACの追加・削除・再解釈、BoundaryやOut of Scopeの変更、外部から観察できる振る舞いの変更が必要なら `RETURN_TO_SPEC` として中止する
   - `RETURN_TO_SPEC` → 中止し、contractと現実の矛盾箇所を報告して、specの磨き直しが必要であることを案内する (specは変更しない)
   - `STOP_FOR_HUMAN` → 中止し、`ROOT_CAUSE` と `HUMAN_QUESTION` (1問、選択肢付き) を報告する
3. debuggerは同一groupで**最大2回**まで起動する。2回目の後も解決しなければgroupをblockedへ移し (`ROOT_CAUSE` が特定のtaskに閉じている場合はそのtaskと依存taskだけをblockedにしてgroupを続行する)、キューを再評価して独立taskを続ける。blockedへ移した後にユーザーが続行を指示した場合は、そのgroupの差し戻しとdebuggerの回数を0に戻し、Phase 3.0から通常の手順で再開する
4. `CATEGORY` と `NEXT_ACTION` をRun Logに、次のgroupにも効く知見をImplementation Notesに記録する
