---
name: mjun-orchestrate
description: >-
  呼び出した会話セッションをHerdr上のorchestration modeへ切り替え、以後の作業依頼を複数の作業agent(claude / codex / opencode / agy)へ並列に分配し、成果を検証して受け入れるSkill。
  ユーザーが「orchestration modeに入って」「Herdrでworkerを立てて並列にやって」「Multi agentで作業して」のように依頼したら使うこと。
  1 taskをその場で実装する依頼や、Herdrの単一paneの操作だけの依頼には使わない。
  `HERDR_ENV=1` の会話セッションでのみ動く。
allowed-tools: Read, Glob, Grep, Bash(herdr:*), Bash(git:*), Bash(gh:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(ln:*), Bash(printf:*), Bash(sleep:*), Bash(test:*), Bash(grep:*), Bash(sort:*), Bash(codex debug models:*), Bash(agy models:*), Bash(opencode models:*), AskUserQuestion, Skill(herdr)
---

# mjun-orchestrate

呼び出した会話セッションをorchestration modeへ切り替えるSkill。mode中のセッションはmain orchestratorとして振る舞い、ユーザーの作業依頼をtaskに分解して、Herdrの同じworkspace内に作ったworker tabで並列に進める。
orchestratorはtaskの分解、worktreeとpaneの用意、dispatch、workerの監視と成果の検証、報告、後始末を担い、**実装とreviewはworkerに委譲する**。orchestratorはworktree内のファイルを編集しない。
Herdr CLIの構文・ID・stateの意味は `herdr` skillに従う。

## Arguments

引数はすべて任意で、mode中の設定になる。mode中にユーザーが変更を指示したら、以後に起動するworkerから新しい値を使う。

- `tasks`: 最初に流すtaskの一覧。会話中の箇条書き、`.mjun/specs/<slug>/tasks.md` の `ready` task、または単発Markdownのパス。省略したらmodeに入ってユーザーの依頼を待つ
- `--review` / `--no-review`: 受け入れ前に独立したreviewerを立てるか。未指定なら、コードを変更するtaskは `--review`、文書作成だけのtaskは `--no-review`
- `--pr` / `--no-pr`: workerにPR作成まで任せるか。**未指定ならPhase 1で確認する** (worker完了後の確認待ちにしない)
- `--max-workers <N>`: 同時に動かすworker数の上限。既定は3

## モデルの選択

workerとreviewerのagent種別とモデルは、Phase 1で取得した一覧からorchestratorが提案し、ユーザーが選ぶ。taskごとに変える場合はtask一覧に `[codex]` のように付記し、そのagent種別の推奨候補を使う。
mode中は、ユーザーが変更を指示しない限り同じ値を使う。

agent種別ごとの一覧の取り方と、`herdr agent start <name> --kind <agent種別> --pane <id> -- <argv>` の `<argv>` は次のとおり。

- claude: 一覧を出すコマンドは無いため、常に最新モデルを指すalias `opus` / `sonnet` / `haiku` を候補にする (`fable` は候補にしない)。推奨はworkerが `sonnet`、reviewerが `opus`
  - argv: `--model <model> --permission-mode auto`
- codex: `codex debug models | jq -r '.models[] | select(.visibility=="list") | [.slug, (.supported_reasoning_levels|map(.effort)|join(","))] | @tsv'`。一覧の先頭ほど新しい。effortは `max` に対応していれば `max`、無ければ対応する最上位にする
  - argv: `-m <model> -c model_reasoning_effort=<effort> --approve-for-me -s workspace-write`
- agy: `agy models` の `gemini-` で始まる行だけを候補にする
  - argv: `--model <model> --dangerously-skip-permissions`
- opencode: `opencode models --verbose | grep -v '^[^ {}]' | jq -r 'select(.status=="active" and .capabilities.toolcall and .capabilities.reasoning) | [.release_date, .providerID+"/"+.id] | @tsv' | sort -r`。同じモデルの別region (`us.` / `global.` など) や `-fast` / `-flex` 版は1つにまとめ、`-free` やpreviewは推奨にしない
  - argv: `-m <provider/model> --auto`

提案はworker用とreviewer用の2問を1回のAskUserQuestionで行う。各問の選択肢は新しく性能の高い順に最大3件とし、推奨を先頭に置いて `(Recommended)` を付ける。reviewerにはworkerと同等以上のモデルを推奨する。一覧の取得に失敗したら、失敗した出力を示してagent種別を選び直してもらう。

起動時のdialogで自動応答してよいのは、claudeの「Is this a project you created or one you trust?」だけとし、`herdr agent send-keys <worker> down enter` で「Yes, I trust」を選ぶ。認証・課金・破壊的操作の確認・外部送信を求めるdialogには答えず、画面内容を添えてユーザーに確認する。

起動できない、usage limitに達した、認証が切れた場合は、選択したagent種別 → `claude` → `codex` → `opencode` の順に、失敗したagent種別を飛ばして起動し直す。切り替え先のモデルは、そのagent種別の一覧を取得して推奨候補を使う。3種類とも失敗したら中止し、ユーザーに報告する。

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

## ユーザーとの対話

ユーザーはこの会話セッション (main orchestrator) とだけ対話する。ユーザーがworkerやreviewerのpaneに入力する前提の手順を作らない。
workerからの質問、dialog、usage limitや認証の問題はすべてorchestratorが受け取る。orchestratorが決められないものだけをAskUserQuestionでユーザーに確認し、回答はorchestratorが `herdr agent prompt` または `herdr agent send-keys` でworkerへ渡す。

## orchestration mode

Phase 1を終えるとmodeに入り、ユーザーが終了を指示するまで続く。全taskが片付いてもmodeは終わらず、次の依頼を待つ。
mode中はユーザーのmessageを次のように扱う:

- 編集を伴う作業依頼: Phase 2から流す。orchestratorが自分で実装しない
- 編集を伴わない作業依頼 (調査、比較検討、既存コードのレビューなど): orchestratorが自分で行うか、subagentに任せる
- 質問や状況確認: orchestratorが読み取りだけで答える。状況確認には会話内の表とpane labelで答える
- 実行中のworker全員に関わる指示 (書き方、対象範囲など): 影響するworker全員へ同じ文面で送る
- 設定の変更 (agent種別、モデル、review、PR、`--max-workers`): 設定を更新し、以後に起動するworkerから適用する。モデルを変える場合は一覧を取り直して提案する
- 終了の指示 (「orchestration終了」など): Phase 8とPhase 9を行い、modeを抜ける

mode中はできるだけworkerを使う。編集を伴う作業 (実装、修正、文書作成、レビュー対応など) は、subagentに委譲したくなる規模でも、subagentではなくtaskとしてworkerへ流す。

`DONE` / `BLOCKED` / `STATUS` / `ACCEPT` / `REJECT` で始まるmessageはworkerやreviewerからの報告であり、ユーザーの依頼ではない。Phase 5とPhase 6で扱う。

## Task

### Phase 1: modeの開始

1. `herdr` skillを読み、`test "${HERDR_ENV:-}" = 1` を確認する。失敗したら中止し、Herdrの外で動いていることをユーザーに伝える
2. 以下を取得して記録する:
   - 自分の位置: `printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"`
   - 現在のtab label: `herdr tab list --workspace "$HERDR_WORKSPACE_ID"`
   - リポジトリ情報: `git rev-parse --show-toplevel`、`gh repo view --json defaultBranchRef,nameWithOwner` (失敗したら `git symbolic-ref --short refs/remotes/origin/HEAD`、それも失敗したら現在のbranch)
3. `gh repo view` が失敗した場合はPRを作れないため `--no-pr` に固定する
4. workerのagent種別をAskUserQuestionで確認する。選択肢は `claude` (既定、先頭)、`codex`、`opencode`、`agy`。`--pr` / `--no-pr` が未指定なら、同じAskUserQuestionで確認する
5. 選ばれたagent種別のモデル一覧を取得し、「モデルの選択」に従ってworker用とreviewer用のモデルを確認する
6. 自分に名前を付ける: `herdr agent rename "$HERDR_PANE_ID" orch`、`herdr tab rename "$HERDR_TAB_ID" "🧭 orch"`
7. modeに入ったことと設定 (agent種別、worker / reviewerのモデル、review、PR、`--max-workers`) を簡潔に示す。`tasks` があればPhase 2へ進み、無ければユーザーの依頼を待つ

### Phase 2: taskの分解

1. `tasks` またはユーザーの依頼を、worker 1体で完了できる単位に分ける。各taskに以下を決める:
   - `slug` (kebab-case、20文字以内) とagent種別
   - 受け入れ基準。失敗するコマンド1つで確かめられる形にする
   - 変更してよいパスの範囲
   - 依存 (Blocked by)。依存先を受け入れるまで起動しない
2. 同じファイルを変更するtaskは並列にせず、依存として直列に並べる (worktreeが別でもmergeで衝突するため)。実行中のtaskと同じファイルを変更するtaskも、そのtaskへの依存にする
3. 計画 (task、agent種別、branch、reviewとPRの有無) を**簡潔に**提示し、確認は取らずPhase 3へ進む

### Phase 3: worktreeとworker tabの作成

1. 起動できるtask (依存なし、または依存先が受け入れ済み) を、実行中のworkerと合わせて `--max-workers` 件を超えない範囲で先頭から選ぶ
2. **worktreeを作成する**: taskごとに `git worktree add -b <branch-name> <worktree-path> <base-branch>`。branchやpathが既存と衝突する場合は末尾に `-2`, `-3` を付ける。`<repo-root>/.mjun` があれば `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る
3. **worker tabを作成する** (mode中に1回だけ。既存の `⚙️ workers` tabがあれば再利用する): `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <worktree-1> --label "⚙️ workers" --no-focus`。応答の `.result.tab.tab_id` と `.result.root_pane.pane_id` を記録し、root paneを1つ目のworkerに使う
4. **paneを分割する** (2つ目以降): `herdr pane split <pane-id> --direction right --cwd <worktree-n> --no-focus`。分割方向は `right` と `down` を交互にする。応答の `.result.pane.pane_id` を記録する。paneが既に4つある場合は、受け入れ済み (`🟢`) のworkerとそのreviewerのpaneを閉じてから分割する。閉じられるpaneが無ければ、どれかが受け入れられるまで起動を待つ
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
   - `blocked` でworkerからの質問 (`BLOCKED <worker>: ...`) なら、orchestratorが答えられるものは `$answer` に入れて `herdr agent prompt <worker> "$answer"` で返す。ユーザーにしか決められないものはpaneを `🔴 <slug> <要旨>` にしてAskUserQuestionで確認し、回答をそのまま渡す。どちらもwaitを張り直す
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
3. **reviewerを起動する**: 名前は `<orch名>-rv-<slug>`、argvはreviewer用のモデルで組み立てる。[templates/reviewer-prompt.md](templates/reviewer-prompt.md) のplaceholderを埋めてdispatchし、受領確認とwaitはPhase 4と同じ手順で行う
4. **verdictを処理する**: reviewerの `ACCEPT <reviewer>: ...` / `REJECT <reviewer>: <findings>` を `herdr agent read` のtranscriptで裏取りする。REJECTの根拠は「失敗したコマンドと出力」か「file:lineと違反した基準の引用」に限り、根拠の無いREJECTは指摘だけ記録してACCEPTとして扱う
   - `ACCEPT` → 受け入れてPhase 7へ。reviewerのpaneは後始末まで残す
   - `REJECT` → findingsをそのまま実装workerへ送り、waitを張り直す。settle後にPhase 5の2を再実行し、同じreviewerに修正後のHEADを再reviewさせる。同一taskのREJECTは**最大2回**とし、収束しなければpaneを `🔴 <slug> review収束せず` にしてユーザーに報告する
   - 「作り直し」に当たるREJECTの場合は同じworkerに送り直さず、そのpaneで新しいworkerを起動し、前回のdiffは渡さず要件と検証結果だけを渡す

### Phase 7: 受け入れと次のtask

1. paneを `🟢 <slug> <sha or PR番号>` にし、表を更新する
2. 依存が解消したtaskがあれば、空いた枠でPhase 3の2〜5とPhase 4を行う
3. 全taskが `🟢` か `🔴` になったらPhase 8の結果を表示し、modeを続けたままユーザーの次の依頼を待つ

### Phase 8: 結果の表示

全taskが片付いたときと、modeを終了するときに行う。modeの終了時はmode中の全taskを対象にする。
`herdr notification show "Workers done" --sound done` を出してから、以下を簡潔にまとめて出力する:

- **Outcome**: `COMPLETE` / `PARTIAL`
- **Tasks**: taskごとにslug、agent種別、branch、commit数、PR URL、review結果 (ACCEPT / REJECT回数 / なし)、状態
- **Checks**: orchestratorが実行した受け入れ基準のコマンドと結果
- **Blocked**: `🔴` のtask、原因、次にユーザーがすること
- **Workers**: 生きているworkerとreviewer (agent名、pane ID)。transcriptはpaneに残っている
- **ユーザーにしかできないこと**: PRのmerge、`🔴` への回答、後始末の承認。1項目1行で、コマンドかリンクを添える

### Phase 9: 後始末とmodeの終了

modeの終了時だけ行う。削除を伴う操作は、AskUserQuestionで1回だけ確認してから行う。選択肢は次の3つ:

- **すべて片付ける**: `herdr pane close` → `herdr tab close` でworker tabを閉じ、`git worktree remove <worktree-path>` でworktreeを削除し、commitの無いbranchだけ `git branch -D` する。未commit変更のあるworktree、PRを作成したbranch、`--no-pr` で成果のあるbranchは残して報告する
- **paneとtabだけ閉じる**: worktreeとbranchは残す
- **何もしない**: 次回は既存の `⚙️ workers` tabを再利用する

最後に `herdr tab rename "$HERDR_TAB_ID" "<記録した元のlabel>"` と `herdr agent rename "$HERDR_PANE_ID" --clear` で自分を元に戻し、modeを抜けたことをユーザーに伝える。以後のmessageは通常の会話として扱う。

## 注意

- orchestratorはworktree内のファイルを編集しない。検証コマンドの実行と `git` の読み取りは行ってよい
- `herdr agent prompt` の本文は必ずquoted heredocでshell変数に入れてから1引数で渡す。shellにtask本文を展開させない
- `agent_prompted` の応答は受領証にならない。Phase 4の3の2条件で判定する
- 自分が作っていないpane / tab / workspaceは閉じない。`herdr workspace close` と `herdr server stop` は使わない
- workerには自分のtask以外のworktreeに触らせない (promptに明記する)。orchestratorも、workerが生きている間はそのworktreeを編集しない
