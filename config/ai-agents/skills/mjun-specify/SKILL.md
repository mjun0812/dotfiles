---
name: mjun-specify
description: >-
  アイデア、GitHub Issue、Markdownを、実装者が追加調査なしで着手できる仕様へ磨き上げるSkill。
  調査で決まる論点はAgentが決め、人間の判断が必要な論点だけを確認して仕様を確定し、承認後にspec ファイルを作成する。
  ユーザーが「specを作って」「仕様を作成して」のように依頼したら使うこと。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Bash(open:*), WebSearch, WebFetch, Skill(exhtml), Skill(mjun-grilling), Skill(mjun-spec-review), Skill(mjun-to-tasks)
---

# mjun-specify

specの実体は常に `.mjun/specs/<slug>/` のLocal specとし、GitHub Issueは取り込みと投影にだけ使う。spec・Issue・状態の規則は [references/source-resolution.md](references/source-resolution.md) に従う。

## Arguments

- `source` (任意): GitHub Issue番号 (`#123` / `123`)、GitHub URL、`.mjun/specs/<slug>`、またはMarkdownパス。未指定なら会話内容を下書きとして新規specを作る
- `--grill` (任意): Human-firstモード。Agent-ownedを含むすべてのdecisionを人間と決める (factsの調査はAgentが行う)。未指定時はAgent-firstで、Agent-ownedはAgentが決め、Human-ownedと判断に迷うものだけを人間と決める
- `--skip-trial` (任意): 一時worktreeでの最小実装 (trial implementation) を行わない

## 共通規則

- **decisionの記録**: specの中で閉じる判断は `design.md` の `## Decisions` に書く。保存先、3条件、書式などADRの規則は [用語集とADR](../mjun-steering/references/glossary_and_adr.md) に従う
- **用語集**: repo直下の `CONTEXT.md`、無ければ `.mjun/CONTEXT.md`
- **選択肢の確認**: AskUserQuestionで行う。使えない環境では同じ選択肢をテキストで提示する
- **GitHub remote**: `gh repo view` が失敗する場合はGitHub remoteが無いものとして扱い、PRやIssue作成の選択肢を出さない
- 出力言語はsourceまたは依頼の言語に合わせる

## Task

### Phase 0: source解決と振り分け

#### source解決

1. Issue番号またはGitHub URL → `gh auth status` を確認し (失敗時は停止して認証を案内)、`gh issue view <number> --json number,state,title,body,labels,comments,url` で取得する。`state: CLOSED` なら中止して報告する。`Source:` 行の逆引きで既存specが見つかればそれを対象にする (doneのspecなら、`active` へ戻して磨き直すか中止するかを確認する)。無ければ振り分けへ進む
2. `.mjun/specs/<slug>` のパス → 既存specを対象にする (配下の全mdをRead)
3. `.mjun/specs/` 外のMarkdownパス → ファイル内容を読み、振り分けへ進む
4. sourceなし → 会話の依頼内容を素材として振り分けへ進む。内容がまったく無い場合のみ自由テキストで概要を受け取る

#### 振り分け

既存specを対象にした場合は省略する。それ以外は、依頼内容とactiveなspecの一覧 (H1タイトルと `Source:` 行) を比べ、判定に必要な範囲だけ関連コードを確認して、最初に当てはまるものを選ぶ。

1. **既存specの拡張**: 依頼が既存のactiveなspecの境界内の拡張、修正、または重複である。sourceなしとMarkdownでは、追加の質問をせず依頼内容を素材としてそのspecを磨き直す。Issueは `Source:` を1つしか持てないため新規specとして取り込み、境界の重なりはPhase 2で扱う
2. **spec不要**: 人間の判断を要する論点 (振る舞い、ドメインの意味、スコープ) が無く、変更が局所的で、完了条件が自明である (typo修正、設定値の変更、振る舞いを変えないリファクタリングなど)。判定理由を1行添えて「直接実装してPRを作る / 直接実装してcommitまで / specを作る」を確認する。直接実装なら、specを作らずにこのskillを終えて同じ会話で実装し、commitは `git-commit`、PRは続けて `github-pr-create` で作る (sourceがIssueならIssue番号を `spec` として渡し、`Closes #N` を付ける)
3. **新規spec**: 上のどちらにも当たらない

### Phase 1: Local specの確保

contractを作成・更新する前に `spec.md` のfrontmatterを `approval: pending` にする (既存specが `approved` なら最初の変更より先に戻す)。

- **取り込み** (新規specになったIssueまたは `.mjun/specs/` 外のMarkdown): Issueは本文とコメントを、Markdownはファイル内容を `.mjun/specs/<slug>/spec.md` へ機械的に構造化する (slugはタイトルの英語kebab-case、frontmatterは `status: active` と `approval: pending`)。Issue由来はH1直下に `Source: #<number>` を書く。Markdown由来は純Localとし、元ファイルは変更しない
- **新規作成** (sourceなし): 依頼内容を下書き素材として、[references/spec-template.md](references/spec-template.md) の骨子で `spec.md` を作る
- **追記型**: `tasks.md` に `done` のtaskがあるspecを拡張する場合は、既存のRequirementsとAcceptance Criteriaの意味を変えず、増分を新しい項目として足す。`done` のtaskを再検証へ戻す (そのACの意味を変える) かはHuman-owned decisionとする。`status: done` のspecへの追加要求も、`active` へ戻してこのskillの手順を通す

### Phase 2: 調査と論点整理

- `.mjun/steering/` と関連コードを読み、原因、変更箇所、既存パターンを特定する
- 用語集とADRを (あれば) 読む。specの用語が用語集と衝突すればspec側を定義に揃え、定義を変えたい場合や、有効なADRと矛盾する要求はHuman-owned decisionとする
- 対象以外のactiveなspecとの境界の重なりと依存を、source-resolution.mdの「spec間の依存と境界」に従って扱う
- 現在のspecを [references/spec-template.md](references/spec-template.md) のcontract構成と比べ、欠落セクション、曖昧な記述、実装者が追加調査を要する箇所 (gap) を列挙する。取り込んだIssueコメントの合意事項も反映対象とする
- スコープ外の問題は本文に混ぜず、Out of Scopeへの記載と別spec化の提案に回す
- specの大きさを見積もる。Requirementsが10件を超える、または `design.md` のModulesが4つ以上に及ぶ見込みなら、独立に配送できる単位へのspecの分割をHuman-owned decisionとして提案する (1本のspecが大きいと、taskの切り方によらず実装が長時間になる)。分割したspecどうしは、Dependenciesの `spec: <slug>` で依存を結ぶ
- 依頼の解釈が複数成立し、どれを取るかで論点の大半が変わる場合 (例: 既存の仕組みへ載せるのか、別の単純な処理を足すのか) は、その方向だけを先にHuman-owned decisionとして解決する
- gapから論点を洗い出し、[references/decision-authority.md](references/decision-authority.md) に従ってAgent-owned / Human-owned / Evidence-blockedへ分類する。前提が解決済みの論点 (frontier) だけを扱い、依存する論点は前提の解決後に分類し直す

### Phase 3: decisionの解決と設計

frontierの論点を解決し、frontierを解決し終えるたびに、まとめてspecと `design.md` の `## Decisions` ([references/design-template.md](references/design-template.md) の形式) へ反映する。判断のたびに書き込むと、その間、人間は次の質問を待つことになる。ADRの3条件を満たす判断には `ADR: 要作成` を付ける (ADRは実装の最終検証の前に `mjun-implement` が書く)。用語が確定したら用語集へ追記する (無ければ `.mjun/CONTEXT.md` を作る)。

- **Agent-owned**: decision-authority.mdの自己問答で解決する。確信度lowは `Status: tentative` として記録し、Phase 4で解消する
- **Human-owned**: frontierのHuman-ownedの論点をすべて、`mjun-grilling` の指定decisionモードへ、論点ごとの選択肢と調査結果を付けてまとめて渡す (互いに依存しない論点は1回の質問になる)
- **Evidence-blocked**: [references/research.md](references/research.md) の一次資料の調査 (外部事実) か、[references/prototyping.md](references/prototyping.md) の試作 (UI、状態、ロジックの実物) / 最小実装 (現行codeでの実現可能性) で証拠を集め、再分類して解決する

frontierがすべて解決したら、採択した設計で `design.md` の残りのセクションを書く (既存なら更新する。省略しない)。

実装方針の実現可能性が不確かな場合は、prototyping.mdの最小実装で検証する (`--skip-trial` 指定時は行わない)。

### Phase 4: 承認準備

承認を求める前に、次の4つをこの順に行う。人間への質問は4-1で終え、4-1を終えたら承認の質問まで入力が要らない旨を1行で伝える。4-2以降で人間の判断が必要になった論点 (4-4の `HUMAN_DECISION_CONFLICTS` など) は、その場で聞かず、承認の質問の直前にまとめて聞く。

#### 4-1. tentativeの解消

`## Decisions` の `Status: tentative` は、spec reviewより前に0件とする (人間が決めた内容もレビューで確かめるため)。

1. **証拠による昇格**: 確信度の低さが証拠の不足によるなら、Evidence-blockedと同じ手段で証拠を集めて再判定する (`--skip-trial` 指定時は最小実装を使わない)。確信度がhigh / mediumになれば `Status:` 行を消し、Evidenceへ根拠を追記する
2. **人間の確認**: 上がらなかったものは、`mjun-grilling` の指定decisionモードへ、論点ごとの選択肢、agentの採択案 (推奨として)、調査結果をまとめて渡して解決する。どちらの場合も `Status:` 行を消して `Owner: human` にする。agentの採択と異なるなら、決定内容と、それに依存する `spec.md` と `design.md` の箇所を書き直す

#### 4-2. セルフチェック

spec reviewに機械的な指摘を残さないため、次を確かめて欠けを反映する。

1. **AC 1件 = 1コマンド**: 各ACが1つの確認コマンドに対応するか。複数の観察 (シナリオ、バージョン、dispatch) を束ねていれば分割する
2. **Requirement ↔ ACの対応**: 各Requirementの振る舞いごとに、それを観察するACがあるか。無ければ追加する (対応表は会話内に保持し、specへは書かない)。件数や回数を問うRequirementのACは、存在確認ではなく件数で書く
3. **Evidenceの実在確認**: `## Decisions` のEvidence (`file:line`、引用、件数) を、ファイルの読み直しかコマンドの再実行で確かめ、食い違いを直す。contractとdesignに書いた外部の固有名 (環境変数名、URL、package名、CLI option) は一次資料で綴りを確かめ、確かめられなければEvidence-blockedとしてPhase 3へ戻す
4. **ACのbaseline確認**: 既存のコマンド (テスト、lint、CLI、`grep`) で確認できるACは現在のtreeで実行する。新規・変更する振る舞いのACが変更前から通るなら、要求した差分を観察できているかを確かめ、できていなければ差分を捉えるACへ書き直す。回帰防止のACと、完了済みtaskの意味を変えないACは、変更前に通っていても残す。Boundaries外の既存の失敗で成立しないAC (repository全体のlint成功など) は、観察範囲を変更箇所へ絞る

#### 4-3. task planのdraft

`mjun-to-tasks` を `--draft` 付きで呼び、調査済みの文脈 (requirements、boundary、変更対象の見当) を渡して、task planのdraftを `.mjun/specs/<slug>/tasks.draft.md` に作らせる。task分解のレビューは、4-4のspec reviewでcontract・designと並列に行う。

#### 4-4. spec review

`mjun-spec-review` に `.mjun/specs/<slug>` と次の文脈を渡してSkill toolで呼び出す (`--grill` 指定時も省略しない)。

- sourceの原文 (Issueの本文とコメント、取り込んだMarkdown、または下書き素材)
- 人間が決めたdecision (`Owner: human`) の見出しの一覧
- task planのdraft (`tasks.draft.md` のパス)

結果ブロック `## Spec Review` の `- VERDICT:`、`FINDINGS`、`HUMAN_DECISION_CONFLICTS` を読む。構造化値が無い、または曖昧なら1回だけ再要求する。

- `PASS` → Phase 5へ進む
- `NEEDS_FIXES` → contractの明文とコードの事実に照らして妥当な指摘だけを、spec、design、draftへ反映する (`[tasks:...]` の指摘はdraftへ反映する)
- `HUMAN_DECISION_CONFLICTS` と、指摘の反映で新たに生じたHuman-ownedの論点 → `mjun-grilling` の指定decisionモードへまとめて渡して再解決し、`design.md` を更新する
- どの場合も再レビューはしない

### Phase 5: contractの提示と承認

contract全文、`design.md` 全文、変更点サマリ (追加・変更したセクションと理由。spec reviewの指摘を反映した箇所はその旨)、4-1で解消したdecision (見出しと、証拠で昇格 / 人間の決定の別)、task planのdraftの要約 (task数と各taskのタイトル) を提示し、「反映する / 修正して再提示 / HTMLで内容を確認する / キャンセル」で承認を取る。承認対象はcontractで、design.mdは目視用である。

`spec.md` と `design.md` の合計が200行を超える場合は、全文の代わりに要点 (Goal、Requirementsの見出し、ACの件数、Boundaries、Out of Scope、人間が決めたdecision、`ADR: 要作成` のdecision) と両ファイルのパスを提示し、承認の選択肢では「HTMLで内容を確認する」を先頭に推奨として置く。

- **反映する**: `approval: approved` へ更新してPhase 6へ進む
- **修正して再提示**: 指摘を反映してこのPhaseをやり直す
- **HTMLで内容を確認する**: [references/approval-html.md](references/approval-html.md) に従って解説HTMLを作って開き、同じ承認質問に戻る
- **キャンセル**: 以降へ進まず、Local specを削除するか `approval: pending` のまま残すかを確認する

### Phase 6: task分解

`mjun-to-tasks` に、4-4のspec reviewを経たdraft (`tasks.draft.md`) と調査済みの文脈 (requirements、boundary、変更対象の見当) を渡し、承認済みcontractの `tasks.md` を確定させる。draftの後に変わったspecとdesignの記述は、mjun-to-tasksが差分だけ反映する。単一task規模でも省略せず、既存の `tasks.md` は最新contractで再分解する。承認は取らない。

### Phase 7: Issueへの投影

`Source:` の無いspecでは投影先Issueを作るかを確認し、作らない場合とGitHub remoteが無い場合は純LocalのままこのPhaseを終える。それ以外は [references/issue-projection.md](references/issue-projection.md) に従ってIssueを作成・投影する。投影直前の確認でLocal specに無い内容を取り込む場合は、`approval: pending` へ戻してPhase 3へ戻る。

### Phase 8: 結果報告

- **Spec**: Local specのパス (`Source:` があればIssue番号とURLも)
- **変更点サマリ**: 追加または変更したセクション
- **Review**: spec reviewのVERDICTと、反映した指摘の件数 (task planへの指摘を含む。再解決したdecisionがあればその見出し)
- **Decisions**: 4-1で解消したtentative (見出しと、証拠で昇格 / 人間の決定の別) と、`ADR: 要作成` のdecision。無ければ「なし」
- **Tasks**: task一覧 (各taskのBoundary、AC数、Done whenと、分割候補の印)、または単一taskである旨。粒度が粗い、または細かいと感じた場合は `mjun-to-tasks` で再分解できる旨を添える
- **次の一手**: `mjun-implement` の呼び出しを、そのままコピペできる1行の `text` コードブロックで提示する (Codexでは `$mjun-implement`、Claude Codeでは `/mjun-implement`)。引数は `Source: #N` があれば実際のIssue番号、無ければ実際のLocal specディレクトリのパスとし、プレースホルダーを残さない。案内文はブロックの外に置く。単一task規模の増分で `tasks.md` に `Implementation Branch:` が記録済みなら、そのbranchへ直接commitする選択肢も1行添える
