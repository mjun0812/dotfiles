---
name: mjun-specify
description: >-
  アイデア、GitHub Issue、Markdownを、実装者が追加調査なしで着手できる仕様 (contract) へ磨き上げるSkill。
  調査で決まる論点はAgentが決め、人間の判断が必要な論点だけを1問ずつ確認して仕様を確定し、承認後にIssueへ投影する。
  ユーザーが「specを作って」「仕様を詰めて」「issueを磨いて」のように依頼したら使うこと。
  実装からPR作成まで進める依頼や、既にspecが承認済みの実装依頼には使わない。
allowed-tools: Task, Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Skill(mjun-grilling), Skill(mjun-research), Skill(mjun-prototype), Skill(mjun-spec-review), Skill(mjun-to-tasks)
---

# mjun-specify

アイデア、GitHub Issue、Markdownを、実装者が追加調査なしで着手できるcontractへ磨き上げるSkill。
自明な部分はAgentが自身で判断し、非自明な部分は人間との対話によって判断し、Agentと人間が協力して仕様を決定する。

正本は常に `.mjun/specs/<slug>/` のLocal specとする。
GitHub Issueが関わる場合も、Issueは入口(取り込み)と出口(投影)であり、作業はすべてLocalファイル上で行う。
規則は [references/source-resolution.md](references/source-resolution.md) に従う。

意思決定の判断材料に `mjun-grilling` / `mjun-research` / `mjun-prototype` を、
承認前のspec検査に `mjun-spec-review` を、承認後のtask分解に `mjun-to-tasks` をSkill toolで呼び出す。

## 委譲の境界

- `mjun-specify` workflow直下の委譲を判断するorchestratorは本体だけとする
- SubAgentを直接起動する場合は、次のleaf contractをpromptに含める: 「SubAgentを起動せず、担当作業を別Agentへ再移譲しない。自分で完了できない場合は結果またはblockerを親へ返し、追加の委譲は親だけが判断する」
- Skill toolで呼び出したcallee skillはleaf roleとして扱わず、そのskill内部の委譲はcallee自身の規則に従う

## Arguments

- `source` (任意): GitHub Issue番号 (`#123` / `123`)、GitHub URL、`.mjun/specs/<slug>`、またはMarkdownパス。
  未指定の場合は会話内容を下書き素材として新規specを作る
- `--grill` (任意): Human-firstモード。すべてのdecisionを1問ずつ人間と決める
- `--skip-trial` (任意): trial implementation (Phase 5) を省略する

## 2つのモード

- **Agent-first (default)**: 調査して決定できるdecision (Agent-owned) はAgentが自動で決め、人間の判断が必要なもの (Human-owned) と判断に迷うものだけを1問ずつ人間と決める
- **Human-first (`--grill`)**: factsの調査はAgentが行い、意思決定はAgent-ownedを含むすべてを1問ずつ人間との対話で決める。決定はその場でspecへ反映する。

## Task

### Phase 0: source解決と前提取得

sourceから対象を判別する。出力言語はsourceまたは依頼の言語に合わせて決める。

1. Issue番号またはGitHub URL → **取り込み**。`gh auth status` を確認し (失敗時は停止して認証を案内)、`gh issue view <number> --json number,state,title,body,labels,comments,url` で取得する。`state: CLOSED` なら中止して報告する。activeなspec (`status: active`) に `Source: #<number>` を持つ既存specがあれば取り込み済みとして、それを対象にする (複数ヒットした場合は一覧を提示して選んでもらう)。activeに無ければ `status: done` のspecからも `Source: #<number>` を検索し、見つかれば実装済みの可能性を警告して、`active` へ戻して磨き直すか中止するかを確認する (同じIssueを正本とするspecを複数作らない)
2. `.mjun/specs/<slug>` のパス → 既存specを対象にする (配下の全mdをRead)
3. `.mjun/specs/` 外のMarkdownパス → **取り込み**。内容を `.mjun/specs/<slug>/spec.md` へ構造化し、以降それを正本として磨く (元ファイルは変更しない)
4. sourceなし → **新規作成**。ただし作成の前に、activeなspecの一覧 (H1タイトルと `Source:` 行。source-resolution.mdの一覧手順で導出する) と依頼を突き合わせ、既存specの拡張や重複と判断できる場合は新規を作らず、そのspecをsourceとして磨き直す (重複specを作らない)。追加の質問はしない

### Phase 1: sourceの確保

Phase 2以降でcontractを作成または更新する前に `spec.md` のfrontmatterを `approval: pending` にする。既存specを磨き直す場合も、最初の変更より先に `approved` から `pending` へ戻す。承認前にsessionが中断しても、未承認contractが実装されないためのgateである。

- **取り込み** (Issue番号または `.mjun/specs/` 外のMarkdown、未取り込みの場合): Issueは本文とコメントを、Markdownはファイル内容を `.mjun/specs/<slug>/spec.md` へ構造化する (slugはタイトルの英語kebab-case)。frontmatterに `status: active` と `approval: pending` を記録し、Issue由来はH1直下に `Source: #<number>` を書く (Markdown由来は書かず純Local扱いとし、元ファイルは変更しない)。この時点では機械的な構造化に留め、磨き上げはPhase 2以降で行う
- **新規作成**: 会話の依頼内容を下書き素材とする。内容がまったく無い場合のみ自由テキストで概要を受け取る。spec化が過剰な依頼 (単発のtypo修正など) では、specを作らず直接実装する選択肢を提示し、選ばれたら終了する
  - `.mjun/specs/<slug>/spec.md` を [references/spec-template.md](references/spec-template.md) の骨子で作成する (frontmatterは `status: active` と `approval: pending`)

### Phase 2: 調査とgap分析

- `.mjun/steering/` (あれば) と関連コードを読み、原因、変更箇所、既存パターンを特定する
- `.mjun/CONTEXT.md` と `.mjun/adr/*.md` (あれば) を読む。specの用語がCONTEXT.mdの定義と衝突していればspec側を定義に揃え (定義を変えたい場合はHuman-owned decisionにする)、既存ADRと矛盾する要求はHuman-owned decisionとして扱う ([references/source-resolution.md 用語集と決定記録](references/source-resolution.md#用語集と決定記録))
- 現在のspecを [references/spec-template.md](references/spec-template.md) のcontract構成と突き合わせ、欠落セクション、曖昧な記述、実装者が追加調査を要する箇所を列挙する。取り込んだIssueコメントの合意事項は反映対象として扱う
- スコープ外の問題を見つけた場合は本文に混ぜず、Out of Scopeへの記載と別spec化の提案に回す

### Phase 3: decision frontierの構築

gapから意思決定の論点を洗い出し、[references/decision-authority.md](references/decision-authority.md) に従って各論点をAgent-owned / Human-owned / Evidence-blockedへ分類する。前提が解決済みの論点 (frontier) だけを扱い、依存する論点は前提の解決後に分類し直す。

### Phase 4: decisionの解決

frontierの論点を1つずつ解決し、確定するたびに**Localのspecとdecision logへ逐次**反映する。decision logのentry形式は [references/decisions-template.md](references/decisions-template.md) に従う。

- **Agent-owned**: decision-authority.mdの自己問答 (論点 → 調査 → 推奨案 → 反論 → 採択 + 確信度) で解決する。確信度lowは `Status: tentative` (要確認) として記録する
- **Human-owned**: `mjun-grilling` の単一decisionモードへ、論点、選択肢、調査結果を渡して解決する
- **Evidence-blocked**: 不足の種類に応じて `mjun-research` (外部事実) / `mjun-prototype` (UI、状態、ロジックの実物) / trial implementation (Phase 5へ) で証拠を集め、再分類して解決する
- `--grill` 指定時は、Agent-ownedのdecisionもHuman-ownedと同様に1問ずつ確認する
- decisionの解決で用語が確定したら、その場で `.mjun/CONTEXT.md` へ追記する (無ければ作る)

### Phase 4.5: design.mdの作成

frontierのdecisionがすべて解決したら、採択した設計を `design.md` へ [references/design-template.md](references/design-template.md) の構成で書く (既存specの磨き直しでは既存のdesign.mdを更新する)。design.mdは省略しない。spec.mdと同じく、調査しても埋まらないセクションは省略してよいが、Modules と Change Outline は必ず書く。decisions.mdに散らばる設計上の採択を1か所に集約し、実装者 (fresh context) がdecisions.mdを読み直さなくても構造が分かる状態にする。

### Phase 5: trial implementation

`--skip-trial` 指定時は省略する。実装方針の実現可能性が不確かな場合に、一時worktreeで検証する:

1. worktreeを作成する: branch名は `specify/<slug>-trial`、パスは `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
2. 修正方針の最小実装を行い、テストを実行して結果を確認する
3. 検証結果 (実行したテスト、結果、落とし穴、方針の修正点) を要約して `design.md` の Trial Implementation Notes に書く。diff全文は載せず、鍵になる数行のスニペットのみ許可する
4. 方針の問題が見つかった場合はPhase 4へ戻り、decisionと `design.md` を更新する
5. **worktreeとbranchは、成功でも中断でも必ず削除する**: `git worktree remove --force <path>` → `git branch -D <branch>`。削除に失敗した場合はユーザーに警告する

### Phase 5.5: spec review

承認を求める前に、`mjun-spec-review` に `.mjun/specs/<slug>` を渡してSkill toolで呼び出し、contractとdesign.mdをfresh contextで検査させる。メイン会話はPhase 2〜5で自分が下した判断に引きずられるため、検査は必ず別のcontextで行う。`--grill` 指定時も省略しない。

呼び出し時に次の文脈を渡す (skillが取得し直さないため)。

- sourceの原文: Issueなら本文とコメント、Markdown取り込みなら元ファイルの内容、新規作成ならPhase 1の下書き素材
- Human-ownedとして人間が決めたdecisionの一覧 (D番号とタイトル)

結果ブロック `## Spec Review` の `- VERDICT:` フィールドだけをパースする。構造化値が無い、または曖昧な場合は1回だけ再要求する。

- `PASS` → Phase 6へ進む
- `NEEDS_FIXES` → 各指摘を読み、contractの明文とコードの事実に照らして妥当なものをspec / decisions / designへ反映する。決定の内容が変わる場合は `decisions.md` にentryを追記する。妥当でないと判断した指摘は捨てる。**再レビューはしない** (直後に人間の承認があるため)
- `HUMAN_DECISION_CONFLICTS` に挙がった指摘 (人間が決めたdecisionとの矛盾) は、Phase 4へ戻って該当decisionだけを `mjun-grilling` の単一decisionモードで再解決し、`design.md` を更新してからPhase 6へ進む。戻るのは1回だけとし、再解決後の再レビューはしない

### Phase 6: contractの提示と承認

- specのcontract全文、`design.md` の全文、変更点サマリ (追加または変更したセクションと理由。Phase 5.5の指摘を反映した箇所はその旨を添える)、要確認 (tentative) の一覧を提示する。承認対象はcontractであり、design.mdは人間が目視する場所とする (気になる点があれば「修正して再提示」で戻す)
- AskUserQuestionで「反映する / 修正して再提示 / キャンセル」の承認を取る (使えない環境では同等の選択肢をテキストで提示する)。「修正して再提示」は指摘を反映してこのPhaseをやり直す
- 「反映する」の場合は `spec.md` のfrontmatterを `approval: approved` へ更新してからPhase 7へ進む
- 「キャンセル」の場合は以降のPhaseへ進まず、作成または更新済みのLocal specを削除するか `approval: pending` のまま残すかを確認する

### Phase 7: task分解

specの規模を判定する。

- 独立に検証可能な振る舞いが複数あり、1つのfresh contextに収まらない規模なら、`mjun-to-tasks` を連結して分解する。調査済みの文脈 (requirements、boundary、変更対象の見当) をプロンプトで渡す。task分解はAgent-ownedのため承認は取らない
- 単一task規模でも、既存の `tasks.md` があれば `mjun-to-tasks` を連結して最新contractへ再分解する (contractから消えたtaskがキューに残らない)。`tasks.md` が無ければ何もしない

### Phase 8: Issueへの記帳

`Source:` の無いspecでは、投影先Issueを作成するかをAskUserQuestionで確認する (使えない環境では選択肢をテキストで提示する)。作成しない場合は純LocalのままこのPhaseを終了する。作成する場合は、リポジトリ内 `.github/ISSUE_TEMPLATE/` (無ければ [references/ISSUE_TEMPLATE](references/ISSUE_TEMPLATE)、日本語は [references/ISSUE_TEMPLATE_JA](references/ISSUE_TEMPLATE_JA)) から種別を自動判定してタイトルとラベル (既存ラベルのみ) を生成し、`gh issue create` で投影先Issueを作成して `Source:` を記録する (本文は次の投影手順で書き込む)。

承認済みcontractをIssueへ投影する:

1. `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントや、Local specに反映されていない本文の記述があれば内容を提示し、specへ取り込むかを確認する (取り込む場合は `approval: pending` へ戻してからPhase 4へ戻る)
2. Issue本文を一時ファイル経由で一括更新する (`gh issue edit <number> --body-file <tmpfile>`)。本文にはcontract (Context〜Out of Scope) + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes` + `tasks.md` があれば `## Tasks` (taskタイトルを `- [ ]` のチェックボックスで列挙) を置く。task進捗はLocalの `tasks.md` だけで管理し、Issueのチェックボックスへは同期しない
3. 却下案と検討経緯は `gh issue comment` で記録し、変更サマリのコメントを1件追記する (body編集はwatcherに通知されないため)

### Phase 9: 結果報告

以下を簡潔にまとめて出力する。

- **Spec**: Local specのパス (`Source:` があればIssue番号とURLも)
- **変更点サマリ**: 追加または変更したセクション
- **Review**: Phase 5.5のVERDICTと、反映した指摘の件数 (Phase 4へ戻したdecisionがあればそのD番号)
- **要確認事項**: tentativeとして残したdecisionの一覧 (実装前に解消が必要)
- **Tasks**: 分解した場合はtask一覧 (各taskのBoundary、AC数、Done whenと、数の目安を超える分割候補の印)、単一taskならその旨。粒度が粗い、または細かいと感じた場合は `mjun-to-tasks` で再分解できる旨を添える (ここは承認ではなく、人間が粒度を目視する場所)
- **次の一手**: このspecを実装に渡せる旨 (要確認が残る場合はその解消が先であることを添える)
