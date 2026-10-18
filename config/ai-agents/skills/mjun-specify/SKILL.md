---
name: mjun-specify
description: >-
  アイデア、GitHub Issue、Markdownを、実装者が追加調査なしで着手できる仕様へ磨き上げるSkill。
  調査で決まる論点はAgentが決め、人間の判断が必要な論点だけを確認して仕様を確定し、承認後にspec ファイルを作成する。
  ユーザーが「specを作って」「仕様を作成して」のように依頼したら使うこと。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Bash(open:*), Bash(zsh:*), WebSearch, WebFetch, Skill(exhtml), Skill(mjun-grilling), Skill(mjun-spec-review), Skill(mjun-to-tasks), Skill(mjun-start)
---

# mjun-specify

ゴールは、実装者 (fresh contextの `mjun-implement`) が追加調査なしで着手できるcontract (`spec.md`) と実装設計 (`design.md`) を、人間の承認つきで用意することである。人間の時間は、人間にしか決められない論点と、1画面の判断シートでの承認だけに使う。

specの実体は常に `.mjun/specs/<slug>/` のLocal specで、GitHub Issueは取り込みと投影にだけ使う。作業中にIssueを読み書きすると、承認したcontractとIssueのどちらが最新か分からなくなるためである。配置、状態、Issueとの対応は [references/source-resolution.md](references/source-resolution.md) にまとめてある。

## Arguments

- `source` (任意): GitHub Issue番号 (`#123` / `123`)、GitHub URL、`.mjun/specs/<slug>`、またはMarkdownパス。未指定なら会話内容を下書きとして新規specを作る
- `--grill` (任意): Human-firstモード。Agent-ownedを含むすべてのdecisionを人間と決める (factsの調査はAgentが行う)。未指定時はAgent-firstで、Agent-ownedはAgentが決め、Human-ownedと判断に迷うものだけを人間と決める
- `--skip-trial` (任意): 一時worktreeでの最小実装 (trial implementation) を行わない

## 共通の前提

- specの中で閉じる判断は `design.md` の `## Decisions` に書く。ADRにするかどうかと書式は [用語集とADR](../mjun-steering/references/glossary_and_adr.md) に従う
- 用語集とADRの置き場所は、[置き場所の決め方](../mjun-steering/references/glossary_and_adr.md#置き場所の決め方) で決まる (用語集はrepo直下の `CONTEXT.md` か `.mjun/CONTEXT.md`)。未決定のまま書く必要が出たら、Phase 3のHuman-ownedの質問とまとめて聞く
- 選択肢のある確認はAskUserQuestionで行い、使えない環境では同じ選択肢をテキストで示す
- `gh repo view` が失敗するrepositoryはGitHub remoteが無いものとして扱い、PRやIssue作成の選択肢を出さない
- 出力言語はsourceまたは依頼の言語に合わせる

## Task

### Phase 0: source解決と振り分け

#### source解決

1. Issue番号またはGitHub URL → `gh auth status` で認証を確かめ (失敗なら停止して認証を案内)、`gh issue view <number> --json number,state,title,body,labels,comments,url` で取得する。`state: CLOSED` なら中止して報告する。`status: active` のspecから `Source:` 行を逆引きし、見つかればそれを対象にする。無ければ振り分けへ進む。`status: done` のspecは作業を終えた使い捨ての文書で、残っていても参照しない
2. `.mjun/specs/<slug>` のパス → 配下の全mdを読み、既存specを対象にする
3. `.mjun/specs/` 外のMarkdownパス → 内容を読み、振り分けへ進む
4. sourceなし → 会話の依頼内容を素材に振り分けへ進む。素材がまったく無いときだけ概要を自由テキストで受け取る

#### 振り分け

既存specを対象にした場合は省く。それ以外は、依頼内容とactiveなspecの一覧 (H1タイトルと `Source:` 行) を比べ、判定に要る範囲だけコードを見て、最初に当てはまるものを選ぶ。

1. **既存specの拡張**: 依頼が既存のactiveなspecの境界内の拡張、修正、または重複である。sourceなしとMarkdownなら、質問せずに依頼内容を素材としてそのspecを磨き直す。Issueは `Source:` を1つしか持てないので新規specとして取り込み、境界の重なりはPhase 2で扱う
2. **spec作りに当たらない**: 新しい振る舞いを足すのでも、期待する振る舞いを変えるのでもない (軽微な修正、バグ修正、1つのtaskに収まるrefactoring、性能改善)。specを作らず、判定理由を1行添えて、依頼内容と調べた範囲 (sourceがIssueならその番号) を `mjun-start` へ渡し、このskillを終える。これらは種類ごとに重視する点が違い、spec作りの流れはそれに合わない。`mjun-start` から新規機能 (広範囲のrefactoringを含む) として渡された依頼では、この判定を省く
3. **新規spec**: 上のどちらにも当たらない

### Phase 1: Local specの確保

contractを作成・更新する前に、`spec.md` のfrontmatterを `approval: pending` にする。`approved` のまま書き換えると、未承認の内容を `mjun-implement` が承認済みとして受け付けてしまう。

- **取り込み** (新規specになったIssue、または `.mjun/specs/` 外のMarkdown): 原文 (Issueは本文とコメント) を `.mjun/specs/<slug>/spec.md` へ機械的に構造化する。slugはタイトルの英語kebab-case、frontmatterは `status: active` と `approval: pending`。Issue由来はH1直下に `Source: #<number>` を書く。Markdown由来は純Localとし、元ファイルは変更しない
- **新規作成** (sourceなし): 依頼内容を素材に、[references/spec-template.md](references/spec-template.md) の骨子で `spec.md` を作る
- **実装済みの機能の拡張**: 実装済みの振る舞いを定めるのはコードとテストで、作業を終えたspecではない。既存の機能を拡張するspecも、今のコード・テスト・Issueから新しく作り、増分だけをRequirementsとAcceptance Criteriaにする。既存のテストが固定している振る舞いを変える要求は、期待する振る舞いを変えるのでHuman-owned decisionにする。取り込むIssueの本文に区切り行 `<!-- projected-spec -->` があれば、その下は前回の投影 (実装済みの判断と完了条件) なので、Requirementsへ写さずContextとして扱う
- **activeなspecの拡張**: `tasks.md` に `done` のtaskがあるactiveなspec (PR作成などの前) を拡張するときは、既存のRequirementsとAcceptance Criteriaの意味を変えず、増分を新しい項目として足す。doneのtaskはcommit済みで、その意味を変えると完了済みの作業が誰も気づかないまま無効になるためである。意味を変えて再検証へ戻すかはHuman-owned decisionにする

### Phase 2: 調査と論点整理

目的は、現在のspecと「実装者が追加調査なしで着手できる状態」との差 (gap) を洗い出し、誰が決める論点かを分けることである。

- `.mjun/steering/`、関連コード、用語集、ADRを読み、原因、変更箇所、既存パターンを押さえる。specの用語は用語集の定義に揃える。定義を変えたい場合と、有効なADRと矛盾する要求はHuman-owned decisionにする
- specを [references/spec-template.md](references/spec-template.md) のcontract構成と比べ、欠けたセクション、曖昧な記述、実装者が調べ直すことになる箇所をgapとして挙げる。取り込んだIssueコメントの合意事項も反映する
- 対象以外のactiveなspecとの境界の重なりと依存は、source-resolution.mdの「spec間の依存と境界」に従って扱う
- スコープ外の問題は本文に混ぜず、Out of Scopeへの記載と別spec化の提案に回す
- Requirementsが10件を超える、または `design.md` のModulesが4つ以上に及ぶ見込みなら、独立したPRにできる単位への分割をHuman-owned decisionとして提案する。1本のspecが大きいと、taskをどう切っても実装が長時間になる。分割したspecどうしはDependenciesの `spec: <slug>` で結ぶ
- 依頼の解釈が複数成り立ち、どれを取るかで論点の大半が変わるなら (既存の仕組みに載せるか、別の単純な処理を足すか)、その方向だけを先にHuman-owned decisionとして決める。方向が決まる前に細部を詰めても捨てることになる
- gapを論点にして、[references/decision-authority.md](references/decision-authority.md) の基準でAgent-owned / Human-owned / Evidence-blockedに分ける。前提が解決済みの論点 (frontier) だけを扱い、依存する論点は前提が決まってから分類し直す

### Phase 3: decisionの解決と設計

frontierの論点を解決し、frontierを1つ解決し終えるごとに、まとめて `spec.md` と `design.md` の `## Decisions` ([references/design-template.md](references/design-template.md) の形式) へ反映する。判断のたびに書き込むと、その間、人間は次の質問を待つことになる。ADRの3条件を満たす判断には `ADR: 要作成` を付ける (ADRは実装の最終検証の前に `mjun-implement` が書く)。用語が確定したら用語集へ追記する (置き場所は共通の前提に従う)。

- **Agent-owned**: decision-authority.mdの自己問答で決める。確信度lowは `Status: tentative` として記録し、Phase 4で解消する
- **Human-owned**: frontierのHuman-ownedの論点をすべて、論点ごとの選択肢と調査結果を付けて `mjun-grilling` の指定decisionモードへまとめて渡す。互いに依存しない論点を1回の質問にすることで、人間の往復を減らす
- **Evidence-blocked**: [references/research.md](references/research.md) の一次資料の調査 (外部事実) か、[references/prototyping.md](references/prototyping.md) の試作 (UI、状態、ロジックの実物) / 最小実装 (現行コードでの実現可能性) で証拠を集め、分類し直して解決する

frontierがすべて解決したら、採択した設計で `design.md` の残りのセクションを書く (既存なら更新する)。実装方針の実現可能性が不確かなら、prototyping.mdの最小実装で確かめる (`--skip-trial` 指定時は行わない)。

### Phase 4: 承認準備

承認を求める前に、次の4つをこの順に行う。人間への質問は4-1で終え、4-1を終えたら承認の質問まで入力が要らない旨を1行で伝える。人間がその間に席を外せるようにするためである。4-2以降で人間の判断が必要になった論点 (4-4の `HUMAN_DECISION_CONFLICTS` など) はその場で聞かず、承認の質問の直前にまとめて聞く。

#### 4-1. tentativeの解消

`## Decisions` の `Status: tentative` を、spec reviewより前に0件とする。人間の決定もレビューで確かめるためである。

1. **証拠による昇格**: 確信度の低さが証拠の不足によるなら、Evidence-blockedと同じ手段で証拠を集めて判定し直す (`--skip-trial` 指定時は最小実装を使わない)。high / mediumになれば `Status:` 行を消し、Evidenceへ根拠を足す
2. **人間の確認**: 上がらなかったものは、論点ごとの選択肢、agentの採択案 (推奨として)、調査結果をまとめて `mjun-grilling` の指定decisionモードへ渡す。`Status:` 行を消して `Owner: human` にし、agentの採択と異なれば、決定内容とそれに依存する `spec.md` と `design.md` の箇所を書き直す

#### 4-2. セルフチェック

spec reviewの指摘を、機械的に見つかる欠けではなく判断の誤りに集中させるため、次を確かめて直す。

1. **AC 1件 = 1コマンド**: 各ACを1つの確認コマンドで判定できるか。複数の観察 (シナリオ、バージョン、dispatch) を束ねていれば分ける。目視の確認シナリオ (`design.md` のTest Strategy) へ移すのは、見た目や操作感の良し悪しだけである。メモリ使用量や処理時間のように測れる量は、計測するコマンドと閾値の形に書き直してACに残す。見た目のうちコマンドで判定できる部分 (適用される値、状態の遷移) もACに残す
2. **Requirement ↔ ACの対応**: 各Requirementの振る舞いごとに、それを観察するACがあるか (対応表は会話内に持ち、specへは書かない)。件数や回数を問うRequirementのACは、存在ではなく件数で確かめる形にする
3. **Evidenceの実在**: `## Decisions` のEvidence (`file:line`、引用、件数) を読み直しか再実行で確かめる。contractとdesignに書いた外部の固有名 (環境変数名、URL、package名、CLI option) は一次資料で綴りを確かめ、確かめられなければEvidence-blockedとしてPhase 3へ戻す。ここで誤った綴りは、実装者がそのまま写す
4. **ACのbaseline**: 既存のコマンドで確認できるACは現在のtreeで実行する。新規・変更する振る舞いのACが変更前から通るなら、要求した差分を観察できていないので、差分を捉える形に書き直す。回帰防止のACと、完了済みtaskの意味を保つACは、変更前に通っていても残す。Boundaries外の既存の失敗で成り立たないAC (repository全体のlint成功など) は、観察範囲を変更箇所へ絞る

#### 4-3. task planのdraft

`mjun-to-tasks` を `--draft` 付きで呼び、調査済みの文脈 (requirements、boundary、変更対象の見当) を渡して、`.mjun/specs/<slug>/tasks.draft.md` にtask planのdraftを作らせる。task分解は4-4でcontract・designと並べてレビューする。

draftができたら、`zsh <skill-dir>/../mjun-to-tasks/scripts/check_spec_format.sh .mjun/specs/<slug> .mjun/specs/<slug>/tasks.draft.md` で形式を検査し、`spec.md` と `design.md` への指摘を直す (tentativeの指摘は4-1で解消しきれていないので、4-1へ戻る)。spec reviewの時間を、機械的に見つかる形式の崩れに使わないためである。

#### 4-4. spec review

`mjun-spec-review` をSkill toolで呼び、`.mjun/specs/<slug>` と次の文脈を渡す (`--grill` 指定時も省かない)。

- sourceの原文 (Issueの本文とコメント、取り込んだMarkdown、または下書き素材)
- 人間が決めたdecision (`Owner: human`) の見出しの一覧
- task planのdraft (`tasks.draft.md` のパス)

結果ブロック `## Spec Review` の `- VERDICT:`、`FINDINGS`、`HUMAN_DECISION_CONFLICTS` を読む。構造化値が無い、または曖昧なら1回だけ再要求する。

- `PASS` → Phase 5へ進む
- `NEEDS_FIXES` → contractの明文とコードの事実に照らして妥当な指摘だけを、spec、design、draftへ反映する (`[tasks:...]` の指摘はdraftへ)。reviewerは書き手の意図を知らないため、指摘がすべて正しいとは限らない
- `HUMAN_DECISION_CONFLICTS` と、反映で新たに生じたHuman-ownedの論点 → `mjun-grilling` の指定decisionモードへまとめて渡して決め直し、`design.md` を更新する

再レビューはしない。反映の結果は判断シートに現れ、人間が承認時に確かめる。レビューを繰り返すと収束しない。

### Phase 5: 判断シートの提示と承認

人間に見せて承認を取るのは、[references/approval-sheet.md](references/approval-sheet.md) の形式で作る1画面の判断シートである。`spec.md` と `design.md` は、シートの判断を実装者とreviewerが追加調査なしで使える形に展開した、agent向けの文書として扱う。人間は全文を読まない前提なので、文書の正しさはspec reviewと4-2のセルフチェックで確かめ、人間の判断が要る内容はすべてシートに出す。シートと文書のパスを示し、「反映する / 修正して再提示 / HTMLで内容を確認する / キャンセル」で承認を取る。

- **反映する**: `approval: approved` へ更新してPhase 6へ進む。`approved` にするのはこの選択を受けたときだけで、中断、tool障害、キャンセルでは `pending` のまま残す
- **修正して再提示**: 指摘を反映し、変わった行に印を付けたシートでこのPhaseをやり直す。agentが決めたことを覆す指摘は、その決定を `Owner: human` にして書き直す
- **HTMLで内容を確認する**: [references/approval-html.md](references/approval-html.md) に従って解説HTMLを作って開き、同じ承認質問に戻る
- **キャンセル**: 以降へ進まず、Local specを削除するか `approval: pending` のまま残すかを確認する

### Phase 6: task分解

`mjun-to-tasks` に、4-4のspec reviewを経たdraft (`tasks.draft.md`) と調査済みの文脈 (requirements、boundary、変更対象の見当) を渡し、承認済みcontractの `tasks.md` を確定させる。draftの後に変わったspecとdesignの記述は、mjun-to-tasksが差分だけ反映する。`mjun-implement` は `tasks.md` が無いと着手しないので、単一task規模でも省かず、既存の `tasks.md` は最新contractで再分解する。承認は取らない。

### Phase 7: Issueへの投影

`Source:` の無いspecでは投影先Issueを作るかを確認し、作らない場合とGitHub remoteが無い場合は純LocalのままこのPhaseを終える。それ以外は [references/issue-projection.md](references/issue-projection.md) に従ってIssueを作成・投影する。投影直前の確認でLocal specに無い内容を取り込むなら、承認していない内容になるので `approval: pending` へ戻してPhase 3へ戻る。

### Phase 8: 結果報告

- **Spec**: Local specのパス (`Source:` があればIssue番号とURLも)
- **変更点サマリ**: 追加または変更したセクション
- **Review**: spec reviewのVERDICTと、反映した指摘の件数 (task planへの指摘を含む。決め直したdecisionがあればその見出し)
- **Decisions**: 4-1で解消したtentative (見出しと、証拠で昇格 / 人間の決定の別) と、`ADR: 要作成` のdecision。無ければ「なし」
- **Tasks**: task一覧 (各taskのBoundary、AC数、Done whenと、分割候補の印)、または単一taskである旨。粒度が合わなければ `mjun-to-tasks` で再分解できる旨を添える
- **次の一手**: `mjun-implement` の呼び出しを、そのままコピペできる1行の `text` コードブロックで示す (Codexでは `$mjun-implement`、Claude Codeでは `/mjun-implement`)。引数は `Source: #N` があれば実際のIssue番号、無ければ実際のLocal specディレクトリのパスとし、プレースホルダーを残さない。案内文はブロックの外に置く。単一task規模の増分で `tasks.md` に `Implementation Branch:` が記録済みなら、そのbranchへ直接commitする選択肢も1行添える
