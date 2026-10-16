# Recovery

taskをblockedへ移すときの隔離と、差し戻しが収束しないときの原因調査 (Phase 3.1') の手順。止まったtaskがあっても、独立したtaskは進め続けることが目的である。

## 自律継続とtaskの隔離

- taskやgroupをblockedへ移すときは、その作業の変更だけを、Phase 3.0の開始時に記録した状態へ戻す。戻してよいのは、その作業で変更したと示せるtracked pathと、その作業で作成したと示せるuntracked pathだけである。対象を特定できなければ中止する。worktree全体へのresetやcleanは、他の変更を失うので使わない
- blockedにするtaskには、spec modeでは `tasks.md` に `Status: blocked`、`Blocked reason: <直接原因>`、`Resume when: <再開条件>` を書き、doc modeでは同じ情報を会話内のキューに持つ。Run Logにも原因を残し、blocked一覧へ加える。group全体がblockedなら、全taskに同じ記録をする
- blockedへ移したらキューを見直し、依存がすべてdoneの独立taskを続ける。blocked taskに依存するtaskは依存待ちに残す。groupの一部だけがblockedなら、そのtaskと、それに依存するgroup内のtaskを外し、残りでgroupを続ける
- taskの分割・順序・依存だけを直す変更は、contractの意味 (Requirements / Boundaries / Acceptance Criteria / Out of Scope、外から観察できる振る舞い) を変えず、既存ACを欠落・追加・再解釈しないなら、ユーザーに確認せず反映してよい。spec modeでは変更内容を文脈に `mjun-to-tasks` で再分解させ、doc modeでは会話内のキューを直す。contractの意味が変わるなら直さず、`RETURN_TO_SPEC` として中止する
- 自動の再分解と、debuggerを受けたtask計画の修正は、それぞれ元taskごとに2回までとする。それでも実行できないtaskはblockedへ移す

## Phase 3.1': 原因調査 (収束しないとき)

[group-loop.md](group-loop.md) のPhase 3.1で、BLOCKED、2周後のREJECTED、同じ指摘や失敗出力の繰り返し、検査やspecの誤りを示す指摘があったときに行う。debuggerはfresh contextで起動し、失敗した試行の経緯は渡さない。経緯を知らない目で、root causeを見直させるためである。

1. debuggerを起動する。起動promptには、失敗の内容 (`BLOCKER`、または最後のreviewerの `FINDINGS` / `REMEDIATION`) と、失敗したコマンドのログのパスを書く。`TASK_BRIEF`、採用済みの検査、Implementation Notesはgroupの `brief.md` にあり、`git diff` はdebuggerが自分で読む
2. `## Debug Report` の `- NEXT_ACTION:` をパースする
   - `RETRY_TASK`: `FIX_PLAN` と `NOTES` を渡して新しいimplementerを起動する。Phase 3.1の手順2で報告を採用してから、レビューを1周だけ行う
   - `FIX_CHECK`: 検査自体の誤り。対象が `PROTECTED_CHECK_FILES` か事前検査のコマンドなら、`ROOT_CAUSE` を渡してverifierに作り直させ、Phase 3.0と同じ採用確認とハッシュの記録をする。それ以外は、implementerに `ROOT_CAUSE` と `FIX_PLAN` を渡して直させる。どちらも、更新後の検査でimplementerが検証し、Phase 3.1の手順2で採用してからレビューを1周だけ行う
   - `RETURN_TO_TASKS`: `TASKS_CHANGE` が、contractの意味を変えずに、taskの分割・統合・順序・依存の変更か、contractやdesignが既に求めている前提taskの追加で済むかを確かめる。済むなら現在のgroupの変更を隔離の規則で戻し、上の規則で反映する (spec modeでは `mjun-to-tasks` に `TASKS_CHANGE` と `ROOT_CAUSE` を渡す)。その後Phase 1の手順4からキューとgroupを組み直し、Phase 3.0から続ける。ACの追加・削除・再解釈、BoundaryやOut of Scopeの変更、外から観察できる振る舞いの変更が要るなら、`RETURN_TO_SPEC` として中止する
   - `RETURN_TO_SPEC`: 中止し、contractと現実の矛盾箇所を示して、specの磨き直しが要ると案内する。specは変更しない
   - `STOP_FOR_HUMAN`: 中止し、`ROOT_CAUSE` と `HUMAN_QUESTION` (1問、選択肢付き) を示す
3. debuggerは同じgroupで2回まで起動する。2回目は、1回目の後に新しい証拠 (新しい失敗出力や別の指摘) があるときだけ、1回目の `## Debug Report` を渡して起動する。上限に達した、または新しい証拠が無いまま解決しなければ、groupをblockedへ移し (`ROOT_CAUSE` が特定のtaskに閉じていれば、そのtaskと依存taskだけ)、独立したtaskを続ける。blockedの後にユーザーが続行を指示したら、そのgroupの差し戻しとdebuggerの回数を0に戻し、Phase 3.0からやり直す
4. `CATEGORY` と `NEXT_ACTION` をRun Logに、次のgroupでも役立つ知見をImplementation Notesに残す
