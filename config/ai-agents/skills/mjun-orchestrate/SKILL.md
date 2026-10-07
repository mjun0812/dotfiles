---
name: mjun-orchestrate
description: >-
  呼び出した会話セッションをHerdr上のorchestration modeへ切り替え、人間の代わりに複数の作業agent(claude / codex / opencode / agy)を並列に操作するSkill。
  ユーザーが「mjun-orchestrateで」「orchestration modeに入って」のように明示的に依頼したときだけ使うこと。
  agent自身の判断で使わない。1 taskをその場で実装する依頼や、Herdrの単一paneの操作だけの依頼には使わない。
  `HERDR_ENV=1` の会話セッションでのみ動く。
allowed-tools: Read, Glob, Grep, Bash(herdr:*), Bash(git:*), Bash(jq:*), Bash(cd:*), Bash(cat:*), Bash(ls:*), Bash(printf:*), Bash(sleep:*), Bash(test:*), Bash(grep:*), AskUserQuestion, Skill(herdr)
disable-model-invocation: true
---

# mjun-orchestrate

呼び出した会話セッションをorchestration modeへ切り替えるSkill。mode中のセッションはmain orchestratorとして、**人間の代わりに**複数のworker agentを操作する。ユーザーの作業依頼をtaskに分け、Herdrの同じworkspace内に作ったworker tabでworkerを起動し、人間が打つのと同じ依頼文を送り、質問やdialogに答え、終わったら結果をユーザーへ伝える。
作業の進め方 (worktree、commit、PR、review) は、workerと、workerが実行するskillに任せる。orchestratorはファイルを編集せず、workerの成果物を独自に検証しない。
Herdr CLIの構文・ID・stateの意味は `herdr` skillに従う。

## Arguments

- `tasks` (任意): 最初に流すtaskの一覧。会話中の箇条書き、`.mjun/specs/<slug>/tasks.md` の `ready` task、または単発Markdownのパス。省略したらmodeに入ってユーザーの依頼を待つ

## モデルの選択

workerのagent種別はAskUserQuestionで選んでもらい、モデルはその後にユーザーが自由入力で決める。orchestratorはモデルの一覧を取得したり候補を提案したりしない。入力が空、または「既定」なら、モデルの指定を省いてCLIの既定モデルで起動する。taskごとに変える場合はtask一覧に `[codex]` や `[codex:<model>]` のように付記する。
mode中は、ユーザーが変更を指示しない限り同じ値を使う。

`herdr agent start <name> --kind <agent種別> --pane <id> -- <argv>` の `<argv>` は次のとおり。モデルを省くときは `<model>` の部分 (`--model <model>` / `-m <model>`) ごと外す。

- claude: `--model <model> --dangerously-skip-permissions`
- codex: `-m <model> --dangerously-bypass-approvals-and-sandbox`。入力にeffortが添えられていれば (例: `gpt-5.5 high`) `-c model_reasoning_effort=<effort>` を足す
- agy: `--model <model> --dangerously-skip-permissions`
- opencode: `-m <provider/model> --auto`

起動時のdialogで自動応答してよいのは、claudeの「Is this a project you created or one you trust?」だけとし、`herdr agent send-keys <worker> down enter` で「Yes, I trust」を選ぶ。認証・課金・破壊的操作の確認・外部送信を求めるdialogには答えず、画面内容を添えてユーザーに確認する。

起動できない、usage limitに達した、認証が切れた場合は、選択したagent種別 → `claude` → `codex` → `opencode` の順に、失敗したagent種別を飛ばして起動し直す。切り替え先ではモデルの指定を省き、CLIの既定モデルで起動したことをユーザーに伝える。3種類とも失敗したら中止し、ユーザーに報告する。

## 名前とlabel

- orchestratorのagent名: `orch` (使用中なら `orch-2`, `orch-3`)。tab labelは `🧭 orch` にし、元のlabelは後で戻すために記録する
- worker tab: `⚙️ workers` のpaneを分割してworkerを増やす。1 tabのpaneは4つまでとし、空きのあるworker tabが無ければ `⚙️ workers 2`, `⚙️ workers 3` と新しいtabを作る。同時に動かすworker数に上限は設けない。終わったtaskのpaneはすぐ閉じる
- workerのagent名: `<orch名>-<slug>`。32文字以内、`[a-z][a-z0-9_-]*`
- pane label: orchestratorが付け、先頭の絵文字で状態を示す
  - `🟡 <slug>`: 作業中
  - `🔴 <slug> <次の行動>`: ユーザーの判断待ち、または止まっている

worker名、pane ID、送った依頼文、直近の `state_change_seq`、状態、結果は会話内の表で管理する。この表はHerdrのstateとtranscriptから作り直せるcacheであり、食い違いがあればHerdr側を正とする。

## ユーザーとの対話

ユーザーはこの会話セッション (main orchestrator) とだけ対話する。ユーザーがworkerのpaneに入力する前提の手順を作らない。
workerの質問、skillが開くdialog、usage limitや認証の問題は、人間がpaneを見て対応するのと同じようにorchestratorが受け取る。orchestratorが決められないものだけをAskUserQuestionでユーザーに確認し、回答はorchestratorが `herdr agent prompt` または `herdr agent send-keys` でworkerへ渡す。

## orchestration mode

Phase 1を終えるとmodeに入り、ユーザーが終了を指示するまで続く。全taskが片付いてもmodeは終わらず、次の依頼を待つ。
mode中はユーザーのmessageを次のように扱う:

- 作業依頼 (実装、修正、文書作成、調査、比較検討、既存コードのレビューなど): Phase 2から流す。orchestratorが自分で作業しない
- 質問や状況確認: orchestratorが読み取りだけで答える。状況確認には会話内の表とpane labelで答える
- 実行中のworkerへの追加指示: 対象のworkerへそのまま送る。全員に関わる指示は影響するworker全員へ同じ文面で送る
- 設定の変更 (agent種別、モデル): 設定を更新し、以後に起動するworkerから適用する
- 終了の指示 (「orchestration終了」など): Phase 7とPhase 8を行い、modeを抜ける

mode中は作業をすべてworkerへ流す。編集を伴わない作業も、subagentに委譲したくなる規模の作業も、subagentではなくtaskとしてworkerへ流す。

`DONE` で始まるmessageはworkerからの報告であり、ユーザーの依頼ではない。Phase 5で扱う。

## Task

### Phase 1: modeの開始

1. `herdr` skillを読み、`test "${HERDR_ENV:-}" = 1` を確認する。失敗したら中止し、Herdrの外で動いていることをユーザーに伝える
2. 以下を取得して記録する:
   - 自分の位置: `printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"`
   - 現在のtab label: `herdr tab list --workspace "$HERDR_WORKSPACE_ID"`
   - リポジトリのroot: `git rev-parse --show-toplevel`
3. workerのagent種別をAskUserQuestionで確認する。選択肢は `claude` (既定、先頭)、`codex`、`opencode`、`agy`
4. workerのモデル名をチャットで自由入力してもらう (選択肢は示さない)。入力を待ってから次へ進む
5. 自分に名前を付ける: `herdr agent rename "$HERDR_PANE_ID" orch`、`herdr tab rename "$HERDR_TAB_ID" "🧭 orch"`
6. modeに入ったことと設定 (agent種別、モデル) を簡潔に示す。`tasks` があればPhase 2へ進み、無ければユーザーの依頼を待つ

### Phase 2: taskの分解

1. `tasks` またはユーザーの依頼を、worker 1体に1回の依頼で任せられる単位に分ける。各taskに以下を決める:
   - `slug` (kebab-case、20文字以内) とagent種別
   - 依頼文。人間がworkerのpaneに打つのと同じ文面にする。skillを使う作業ならskillの呼び出しと引数を書く (例: `/mjun-implement #12 --pr`)。ユーザーが指定したオプションはそのまま含め、ユーザーが決めていないことをorchestratorが補わない
   - 依存 (Blocked by)。依存先が終わるまで起動しない
2. 同じファイルを変更しそうなtaskは並列にせず、依存として直列に並べる。実行中のtaskと同じファイルを変更しそうなtaskも、そのtaskへの依存にする
3. 計画 (task、agent種別、依頼文、依存) を**簡潔に**提示し、確認は取らずPhase 3へ進む

### Phase 3: worker paneの作成

1. 起動できるtask (依存なし、または依存先が終わっている) をすべて選ぶ
2. **worker tabを作成する** (paneが4つ未満のworker tabが無いときだけ。あれば再利用する): `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd <repo-root> --label "<label>" --no-focus`。labelは1つ目が `⚙️ workers`、2つ目以降が `⚙️ workers 2`, `⚙️ workers 3`。応答の `.result.tab.tab_id` と `.result.root_pane.pane_id` を記録し、root paneをそのtabの1つ目のworkerに使う
3. **paneを分割する** (tab内の2つ目以降): `herdr pane split <同じtabのpane-id> --direction right --cwd <repo-root> --no-focus`。分割方向は `right` と `down` を交互にする。応答の `.result.pane.pane_id` を記録する
4. 各paneを `herdr pane rename <pane-id> "🟡 <slug>"` にする

### Phase 4: workerの起動とdispatch

workerごとに以下を行う。`herdr agent prompt` に `--wait` は付けない (1つ目のworkerで待ち続けるため)。

1. **workerを起動する**: `herdr agent start <worker> --kind <agent種別> --pane <pane-id> --timeout 60000 -- <argv>`
   - `agent_not_ready` が返ったら `herdr agent read <worker> --source visible --lines 40` で画面を読む。自動応答してよいdialogなら答えて `herdr agent wait <worker> --until idle --timeout 60000` で待ち、それ以外のdialogはユーザーに確認する
   - usage limit、認証、model不在の文言が見えたら `herdr agent send-keys <worker> ctrl+c ctrl+c` で終了し、`herdr pane read` でshellに戻ったことを確認する。model不在ならユーザーにモデル名を入力し直してもらい、それ以外は次のagent種別で起動し直す
2. **dispatchする**: `herdr agent get <worker>` の `state_change_seq` を記録してから、[templates/worker-prompt.md](templates/worker-prompt.md) に依頼文を埋めた本文をquoted heredocでshell変数に入れ、`herdr agent prompt <worker> "$task_prompt"` と1引数で送る
3. **受領を確認する**: `herdr agent wait <worker> --until working --timeout 15000` が返り、`state_change_seq` が記録した値より進んでいれば受領とみなす。そうならなければ `herdr agent read <worker> --source visible --lines 40` で画面を読み、dialogなら答える、usage limitや認証ならagent種別を切り替えて同じ本文を再送する、変化が無ければ同じ本文を1回だけ再送する。再送後も受領しなければpaneを `🔴 <slug> 応答なし` にしてユーザーに報告する
4. **waitを張る**: 受領したworkerごとに `herdr agent wait <worker> --timeout 1800000` をbackgroundで1本実行する (`--until` は付けない)。短い間隔で `agent get` を繰り返さない。backgroundで実行できない環境では、起動済みのworkerを順に待つ

### Phase 5: workerへの対応

workerの `DONE` 報告は `herdr agent prompt <orch名>` 経由でこの会話にuser messageとして届く。stateが `working` のまま `DONE` が届いても、まだ終わっていない。
waitが返ったworkerの `herdr agent get <worker>` と `herdr agent read <worker> --source recent-unwrapped --lines 80` を読み、人間がpaneを見たときと同じように対応する:

- `blocked` でdialogが開いている: 自動応答してよいdialogなら答える。workerやskillの質問で、ユーザーの依頼から答えが決まるものはorchestratorが答える。ユーザーにしか決められないものはpaneを `🔴 <slug> <要旨>` にしてAskUserQuestionで確認し、回答をそのまま渡す。答えたらwaitを張り直す
- `idle` / `done` で `DONE` が届いている: Phase 6へ進む
- `idle` / `done` で `DONE` が無い: transcriptの最後を読む。質問で止まっていれば上と同じく答える。エラーや確認待ちで止まっていれば、ユーザーの依頼の範囲で続行を促すか、paneを `🔴 <slug> <要旨>` にしてユーザーに報告する。送ったらwaitを張り直す
- `unknown` が続く、またはpaneがshellに戻っている: workerが死んでいる。paneを `🔴 <slug> worker停止` にし、同じpaneでworkerを起動し直して、元の依頼文に「前回のworkerが途中で止まった。作りかけのworktreeやbranchがあれば続きから進めて」と添えて送る

### Phase 6: 完了と次のtask

1. `DONE` 報告とtranscriptの最後から、結果 (PR URL、branch、未解決の事項) を表に記録する。workerの報告をそのまま記録し、orchestratorが成果物を検証し直すことはしない。調査やレビューのように結果が回答そのもののtaskでは、paneを閉じる前にtranscriptから結果を読み、ユーザーへ伝える
2. **paneを閉じる**: `herdr pane close <pane-id>` でworkerのpaneを閉じる。そのworker tabに残る最後のpaneなら、pane closeの代わりに `herdr tab close <tab-id>` でtabごと閉じ、記録したtab IDを消す
3. 依存が解消したtaskがあれば、空いた枠でPhase 3の2〜4とPhase 4を行う
4. 全taskが完了か `🔴` になったらPhase 7の結果を表示し、modeを続けたままユーザーの次の依頼を待つ

### Phase 7: 結果の表示

全taskが片付いたときと、modeを終了するときに行う。modeの終了時はmode中の全taskを対象にする。
`herdr notification show "Workers done" --sound done` を出してから、以下を簡潔にまとめて出力する:

- **Outcome**: `COMPLETE` / `PARTIAL`
- **Tasks**: taskごとにslug、agent種別、依頼文、結果 (workerが報告したPR URLやbranch)、状態
- **Blocked**: `🔴` のtask、原因、次にユーザーがすること
- **Workers**: 残っているworker (`🔴` のtask、agent名、pane ID)。transcriptはpaneに残っている
- **ユーザーにしかできないこと**: PRのmerge、`🔴` への回答、後始末の承認。1項目1行で、コマンドかリンクを添える

### Phase 8: 後始末とmodeの終了

modeの終了時だけ行う。worker tabが残っていれば、閉じるかをAskUserQuestionで1回だけ確認し、閉じる場合は `herdr pane close` → `herdr tab close` で閉じる。残す場合は、次回のmodeで既存のworker tabを再利用する。worktreeとbranchはworkerとskillが管理するため、orchestratorは削除しない。

最後に `herdr tab rename "$HERDR_TAB_ID" "<記録した元のlabel>"` と `herdr agent rename "$HERDR_PANE_ID" --clear` で自分を元に戻し、modeを抜けたことをユーザーに伝える。以後のmessageは通常の会話として扱う。

## 注意

- orchestratorはファイルを編集しない
- `herdr agent prompt` の本文は必ずquoted heredocでshell変数に入れてから1引数で渡す。shellに依頼文を展開させない
- `agent_prompted` の応答は受領証にならない。Phase 4の3で判定する
- 自分が作っていないpane / tab / workspaceは閉じない。`herdr workspace close` と `herdr server stop` は使わない
