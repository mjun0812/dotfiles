---
name: mjun-orchestrate
description: >-
  Herdr上で複数の作業agent(claude / codex / opencode / agy)を並列に動かし、呼び出した会話セッションがorchestratorとして成果を検証して受け入れるSkill。
  ユーザーが「Herdrでworkerを立てて並列にやって」「Multi agentで作業して」のように依頼したら使うこと。
  1 taskをその場で実装する依頼や、Herdrの単一paneの操作だけの依頼には使わない。
  `HERDR_ENV=1` の会話セッションでのみ動く。
allowed-tools: Read, Glob, Grep, Bash(herdr:*), Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(ln:*), Bash(printf:*), Bash(sleep:*), Bash(test:*), AskUserQuestion, Skill(herdr)
---

# mjun-orchestrate

独立した複数のtaskを、Herdrの同じworkspace内に作ったworker tabで並列に進めるSkill。
メイン会話がorchestratorとしてtaskの分解、worktreeとpaneの用意、dispatch、成果の検証、報告、後始末を担い、**実装とreviewはworkerに委譲する**。orchestratorはworktree内のファイルを編集しない。
Herdr CLIの構文・ID・stateの意味は `herdr` skillに従う。

## Arguments

- `tasks` (必須): taskの一覧。会話中の箇条書き、`.mjun/specs/<slug>/tasks.md` の `ready` task、または単発Markdownのパス
- `--agent <agent種別>` (任意): workerとして使うagentの種別。`claude` (既定)、`codex`、`opencode`、`agy`。taskごとに変える場合はtask一覧に `[codex]` のように付記する
- `--review` / `--no-review` (任意): 受け入れ前に独立したreviewerを立てるか。未指定なら、コードを変更するtaskは `--review`、調査や文書作成だけのtaskは `--no-review`
- `--pr` / `--no-pr` (任意): workerにPR作成まで任せるか。**未指定ならPhase 2で確認する** (worker完了後の確認待ちにしない)
- `--max-workers <N>` (任意): 同時に動かすworker数の上限。既定は3

## workerの設定

`herdr agent start <name> --kind <agent種別> --pane <id> -- <argv>` の `<argv>` はagent種別ごとに固定する。
skillの実行中に別の値へ変えない。

- claude:
  - Worker: `--model sonnet --permission-mode auto`
  - Reviewer: `--model opus --permission-mode auto`
- codex:
  - Worker: `-m gpt-5.6-luna -c model_reasoning_effort=max --approve-for-me -s workspace-write`
  - Reviwer: `-m gpt-5.6-luna -c model_reasoning_effort=max --approve-for-me -s workspace-write`
- agy:
  - Worker / Reviewer: `--model gemini-3.8-flash-high --dangerously-skip-permissions`
- opencode:
  - Worker / Reviewer: `-m openai/gpt-6-astra --auto`

起動時のdialogで自動応答してよいのは、claudeの「Is this a project you created or one you trust?」だけとし、`herdr agent send-keys <worker> down enter` で「Yes, I trust」を選ぶ。認証・課金・破壊的操作の確認・外部送信を求めるdialogには答えず、画面内容を添えてユーザーに確認する。

起動できない、usage limitに達した、認証が切れた場合は、指定したagent種別 → `claude` → `codex` → `opencode` の順に、失敗したagent種別を飛ばして起動し直す。3種類とも失敗したら中止し、ユーザーに報告する。

## 名前とlabel

- orchestratorのagent名: `orch` (使用中なら `orch-2`, `orch-3`)。tab labelは `🧭 orch` にし、元のlabelは後で戻すために記録する
- worker tab: `⚙️ workers` を1つだけ作る。workerが増えたらこのtab内でpaneを分割する。paneは4つまで
- workerのagent名: `<orch名>-<slug>`。reviewerは `<orch名>-rv-<slug>`。32文字以内、`[a-z][a-z0-9_-]*`
- worktree: `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。branchは `<type>/<slug>`
- pane label: 先頭の絵文字で状態を示す
  - `🟡 <slug>`: 作業中
  - `🔵 <slug>`: review中
  - `🔴 <slug> <次の行動>`: 止まっている
  - `🟢 <slug> <sha or PR番号>`: 受け入れ済み

worker名、pane ID、worktree、branch、直近の `state_change_seq`、状態、報告は会話内の表で管理する。この表はHerdrのstate・git・PRから作り直せるcacheであり、食い違いがあればHerdr側を正とする。

## Task

### Phase 1: 準備

1. `herdr` skillを読み、`test "${HERDR_ENV:-}" = 1` を確認する。失敗したら中止し、Herdrの外で動いていることをユーザーに伝える
2. 以下を取得して記録する:
   - 自分の位置: `printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"`
   - 現在のtab label: `herdr tab list --workspace "$HERDR_WORKSPACE_ID"`
   - リポジトリ情報: `git rev-parse --show-toplevel`、`gh repo view --json defaultBranchRef,nameWithOwner` (失敗したら `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
3. `gh repo view` が失敗した場合はPRを作れないため `--no-pr` に固定する
4. 自分に名前を付ける: `herdr agent rename "$HERDR_PANE_ID" orch`、`herdr tab rename "$HERDR_TAB_ID" "🧭 orch"`

### Phase 2: taskの分解

1. `tasks` をworker 1体で完了できる単位に分ける。各taskに以下を決める:
   - `slug` (kebab-case、20文字以内) とagent種別
   - 受け入れ基準。失敗するコマンド1つで確かめられる形にする
   - 変更してよいパスの範囲
   - 依存 (Blocked by)。依存先を受け入れるまで起動しない
2. 同じファイルを変更するtaskは並列にせず、依存として直列に並べる (worktreeが別でもmergeで衝突するため)
3. `--pr` / `--no-pr` が未指定なら、ここでAskUserQuestionにより確認する
4. 計画 (task、agent種別、branch、reviewとPRの有無) を**簡潔に**提示し、確認は取らずPhase 3へ進む

### Phase 3: worktreeとworker tabの作成

1. 起動できるtask (依存なし、または依存先が受け入れ済み) を先頭から `--max-workers` 件選ぶ
2. **worktreeを作成する**: taskごとに `git worktree add -b <branch-name> <worktree-path> <base-branch>`。branchやpathが既存と衝突する場合は末尾に `-2`, `-3` を付ける。`<repo-root>/.mjun` があれば `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る
3. **worker tabを作成する** (最初の1回だけ): `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <worktree-1> --label "⚙️ workers" --no-focus`。応答の `.result.tab.tab_id` と `.result.root_pane.pane_id` を記録し、root paneを1つ目のworkerに使う
4. **paneを分割する** (2つ目以降): `herdr pane split <pane-id> --direction right --cwd <worktree-n> --no-focus`。分割方向は `right` と `down` を交互にする。応答の `.result.pane.pane_id` を記録する
5. 各paneを `herdr pane rename <pane-id> "🟡 <slug>"` にする

### Phase 4: workerの起動とdispatch

workerごとに以下を行う。`herdr agent prompt` に `--wait` は付けない (1つ目のworkerで待ち続けるため)。

1. **workerを起動する**: `herdr agent start <worker> --kind <agent種別> --pane <pane-id> --timeout 60000 -- <argv>`
   - `agent_not_ready` が返ったら `herdr agent read <worker> --source visible --lines 40` で画面を読む。自動応答してよいdialogなら答えて `herdr agent wait <worker> --until idle --timeout 60000` で待ち、それ以外のdialogはユーザーに確認する
   - usage limit、認証、model不在の文言が見えたら `herdr agent send-keys <worker> ctrl+c ctrl+c` で終了し、`herdr pane read` でshellに戻ったことを確認してから次のagent種別で起動し直す
2. **dispatchする**: `herdr agent get <worker>` の `state_change_seq` を記録してから、[templates/worker-prompt.md](templates/worker-prompt.md) のplaceholderを埋めた本文をquoted heredocでshell変数に入れ、`herdr agent prompt <worker> "$task_prompt"` と1引数で送る
3. **受領を確認する**。次の2つが揃って受領とみなす:
   - `herdr agent wait <worker> --until working --timeout 15000` が返り、`state_change_seq` が記録した値より進んでいる
   - `herdr agent read <worker> --source recent-unwrapped --lines 40` に `RECEIPT <worker>: task received` がある
   - 片方しか揃わない場合は15秒待って再読する。それでも揃わなければ画面を読み、dialogなら答える、usage limitや認証ならagent種別を切り替えて同じpromptを再送する、`idle` のまま変化が無ければ同じpromptを1回だけ再送する。再送後も揃わなければpaneを `🔴 <slug> 応答なし` にしてユーザーに報告する
4. **waitを張る**: 受領したworkerごとに `herdr agent wait <worker> --timeout 1800000` をbackgroundで1本実行する (`--until` は付けない)。短い間隔で `agent get` を繰り返さない。backgroundで実行できない環境では、起動済みのworkerを順に待つ

### Phase 5: 成果の回収と検証

workerの `DONE` / `BLOCKED` / `STATUS` 報告は `herdr agent prompt <orch名>` 経由でこの会話にuser messageとして届くが、受け入れの根拠にはしない。stateが `working` のまま `DONE` が届いても、まだ終わっていない。

1. waitが返ったworkerの `herdr agent get <worker>` を読む:
   - `blocked` で自動応答してよいdialogなら答え、waitを張り直す
   - `blocked` でworkerからの質問 (`BLOCKED <worker>: ...`) なら、orchestratorが答えられるものは `$answer` に入れて `herdr agent prompt <worker> "$answer"` で返す。ユーザーにしか決められないものはpaneを `🔴 <slug> <要旨>` にしてユーザーに確認し、回答をそのまま渡す。どちらもwaitを張り直す
   - `idle` / `done` なら2へ進む
   - `unknown` が続く、またはpaneがshellに戻っている場合はworkerが死んでいる。paneを `🔴 <slug> worker停止` にし、`git status` と `git log` で状況を読み、同じpaneでworkerを起動し直して残作業をdispatchする。promptには前回の方針の要約1行と、worktreeに残る変更を確認させる指示を添える
2. **worktreeを検証する** (orchestratorが自分で実行する):
   - `git -C <worktree> status --porcelain` が空であること。残っていれば `STATUS` を要求して待つ
   - `git -C <worktree> log <base>..HEAD --oneline` にcommitがあること
   - `git -C <worktree> diff --name-only <base>..HEAD` が変更してよいパスに収まっていること
   - 受け入れ基準のコマンドがすべて通ること
   - `--pr` のときは `gh pr view <url> --json url,state,headRefName` でPRが存在すること
3. 検証に通れば、`--no-review` のtaskは受け入れてPhase 7へ、`--review` のtaskはPhase 6へ進む
4. 検証に落ちたら、失敗したコマンドの出力をそのまま添えて同じworkerへ差し戻す (`herdr agent prompt <worker> "$fix"`)。同一taskの差し戻しは**最大2回**とし、2回後も通らなければpaneを `🔴 <slug> 収束せず` にしてユーザーに報告する

### Phase 6: review

reviewerは実装したworkerとは別のsessionで動かす。workerに自分の変更をreviewさせない。

1. 対象workerのpaneを `🔵 <slug>` にする
2. **reviewer用のpaneを作る**: `herdr pane split <workerのpane> --direction down --cwd <同じworktree> --no-focus`。paneが既に4つある場合は、受け入れ済みworkerのpaneを閉じてから作る
3. **reviewerを起動する**: 名前は `<orch名>-rv-<slug>`、argvはreviewer用。[templates/reviewer-prompt.md](templates/reviewer-prompt.md) のplaceholderを埋めてdispatchし、受領確認とwaitはPhase 4と同じ手順で行う
4. **verdictを処理する**: reviewerの `ACCEPT <reviewer>: ...` / `REJECT <reviewer>: <findings>` を `herdr agent read` のtranscriptで裏取りする。REJECTの根拠は「失敗したコマンドと出力」か「file:lineと違反した基準の引用」に限り、根拠の無いREJECTは指摘だけ記録してACCEPTとして扱う
   - `ACCEPT` → 受け入れてPhase 7へ。reviewerのpaneは後始末まで残す
   - `REJECT` → findingsをそのまま実装workerへ送り、waitを張り直す。settle後にPhase 5の2を再実行し、同じreviewerに修正後のHEADを再reviewさせる。同一taskのREJECTは**最大2回**とし、収束しなければpaneを `🔴 <slug> review収束せず` にしてユーザーに報告する
   - 「作り直し」に当たるREJECTの場合は同じworkerに送り直さず、そのpaneで新しいworkerを起動し、前回のdiffは渡さず要件と検証結果だけを渡す

### Phase 7: 受け入れと次のtask

1. paneを `🟢 <slug> <sha or PR番号>` にし、表を更新する
2. 依存が解消したtaskがあれば、空いた枠でPhase 3の2〜5とPhase 4を行う
3. 途中でユーザーから全workerに関わる指示 (書き方、対象範囲など) が来たら、影響するworker全員へ同じ文面で送る
4. 全taskが `🟢` か `🔴` になったらPhase 8へ進む

### Phase 8: 結果の表示

`herdr notification show "Workers done" --sound done` を出してから、以下を簡潔にまとめて出力する:

- **Outcome**: `COMPLETE` / `PARTIAL`
- **Tasks**: taskごとにslug、agent種別、branch、commit数、PR URL、review結果 (ACCEPT / REJECT回数 / なし)、状態
- **Checks**: orchestratorが実行した受け入れ基準のコマンドと結果
- **Blocked**: `🔴` のtask、原因、次にユーザーがすること
- **Workers**: 生きているworkerとreviewer (agent名、pane ID)。transcriptはpaneに残っている
- **ユーザーにしかできないこと**: PRのmerge、`🔴` への回答、後始末の承認。1項目1行で、コマンドかリンクを添える

### Phase 9: 後始末

削除を伴う操作は、AskUserQuestionで1回だけ確認してから行う。選択肢は次の3つ:

- **すべて片付ける**: `herdr pane close` → `herdr tab close` でworker tabを閉じ、`git worktree remove <worktree-path>` でworktreeを削除し、commitの無いbranchだけ `git branch -D` する。未commit変更のあるworktree、PRを作成したbranch、`--no-pr` で成果のあるbranchは残して報告する
- **paneとtabだけ閉じる**: worktreeとbranchは残す
- **何もしない**: 次回は既存の `⚙️ workers` tabを再利用する

最後に `herdr tab rename "$HERDR_TAB_ID" "<記録した元のlabel>"` と `herdr agent rename "$HERDR_PANE_ID" --clear` で自分を元に戻す。

## 注意

- orchestratorはworktree内のファイルを編集しない。検証コマンドの実行と `git` の読み取りは行ってよい
- `herdr agent prompt` の本文は必ずquoted heredocでshell変数に入れてから1引数で渡す。shellにtask本文を展開させない
- `agent_prompted` の応答は受領証にならない。Phase 4の3の2条件で判定する
- 自分が作っていないpane / tab / workspaceは閉じない。`herdr workspace close` と `herdr server stop` は使わない
- workerには自分のtask以外のworktreeに触らせない (promptに明記する)。orchestratorも、workerが生きている間はそのworktreeを編集しない
