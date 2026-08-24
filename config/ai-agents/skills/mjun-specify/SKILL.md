---
name: mjun-specify
description: >-
  アイデア・GitHub Issue・ローカルMarkdownを、実装可能なspec (contract) へ仕上げるSkill。
  正本は常に `.mjun/specs/` のLocal specで、GitHub Issueは取り込みと投影のアダプタとして扱う。
  factsを調査してAgentの権限内のdecisionを自分で決め、人間の判断が必要なdecisionだけを1問ずつ確認し、
  承認後にIssueへ投影して必要ならtask分解まで行う。
  ユーザーが「issue作って」「バグ報告を起票して」「specを作って」「#Nを実装できるレベルに詰めて」「issueを磨いて」
  「この設計docをspecにして」のように依頼したら使うこと。
  実装からPR作成まで進める依頼や、既にspecが承認済みの実装依頼には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Skill(mjun-grill), Skill(mjun-research), Skill(mjun-prototype), Skill(mjun-to-tasks)
---

# mjun-specify

アイデア・GitHub Issue・ローカルMarkdownを、実装者が追加調査なしで着手できるcontractへ磨き上げるSkillです。人間はcontract (何を作るか) を承認し、その内側の設計はAgentが決めます。

正本は常に `.mjun/specs/<slug>/` のLocal specです。GitHub Issueが関わる場合も、Issueは入口 (取り込み) と出口 (投影) であり、作業はすべてLocalファイル上で行います。規則は [references/source-resolution.md](references/source-resolution.md) に従います。

GitHub操作は必ず `gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

連結先: 意思決定の解消に `mjun-grill` / `mjun-research` / `mjun-prototype` を、承認後のtask分解に `mjun-to-tasks` を、Skill toolで呼び出す。Skill toolが使えない環境では、連結先skillのSKILL.mdを直接読み込み、その手順に従って実行する。

## Arguments

- `source` (任意): 対象。GitHub Issue番号 (`#123` / `123`)、GitHub URL、`.mjun/specs/<slug>`、またはMarkdownパス。未指定の場合は会話内容を下書き素材として新規specを作る
- `--issue` (任意): 新規spec作成時に、投影先のGitHub Issueもあわせて作成する。既定は純Local (Issueを作らない)
- `--grill` (任意): Human-firstモード。非自明なdecisionを1問ずつ人間と決める
- `--skip-trial` (任意): trial implementation (Phase 5) を省略する
- `--dry-run` (任意): contract全文の提示 (Phase 6) で停止する。ファイル・Issueへの書き込みとtask分解を一切行わず、spec内容はファイルへ書かずに会話内で組み立てる

## 2つのモード

- **Agent-first (デフォルト)**: Agentが可能な限り調査して決め、Human-owned decisionだけを1問ずつ確認する
- **Human-first (`--grill`)**: factsはAgentが調査するが、非自明なdecisionはすべて人間と1問ずつ決める。決定はその場でspecへ反映する (grill-with-docs相当)

## Task

### Phase 0: source解決と前提取得

sourceから対象を判別する。

1. Issue番号またはGitHub URL → **取り込み**。`gh auth status` を確認し (失敗時は停止して認証を案内)、`gh issue view <number> --json number,state,title,body,labels,comments,url` で取得する。`state: CLOSED` なら中止して報告する。activeなspec (`status: active`) に `Source: #<number>` を持つ既存specがあれば取り込み済みとして、それを対象にする (複数ヒットした場合は一覧を提示して選んでもらう)
2. `.mjun/specs/<slug>` のパス → 既存specを対象にする (配下の全mdをRead)
3. `.mjun/specs/` 外のMarkdownパス → **取り込み**。内容を `.mjun/specs/<slug>/spec.md` へ構造化し、以降それを正本として磨く (元ファイルは変更しない)
4. sourceなし → **新規作成**。ただし作成の前に、activeなspecの一覧 (H1タイトルと `Source:` 行。source-resolution.mdの一覧手順で導出する) と依頼を突き合わせ、既存specの拡張・重複と判断できる場合は新規を作らず、そのspecをsourceとして磨き直す (重複specを作らない)。新規と判断したら、`--issue` の有無で投影先Issueを作るかが決まる。追加の質問はしない

出力言語はsourceまたは依頼の言語に合わせて決める。純Local操作では `gh` を一切呼ばない。

### Phase 1: sourceの確保

`--dry-run` 指定時は、このPhase以降のファイル作成・Issue作成・逐次更新をすべて行わず、同じ内容を会話内で組み立ててPhase 6の提示で終了する。

- **取り込み** (Issue番号または `.mjun/specs/` 外のMarkdown、未取り込みの場合): Issueは本文とコメントを、Markdownはファイル内容を `.mjun/specs/<slug>/spec.md` へ構造化する (slugはタイトルの英語kebab-case)。frontmatterに `status: active` を記録し、Issue由来はH1直下に `Source: #<number>` を書く (Markdown由来は書かず純Local扱いとし、元ファイルは変更しない)。この時点では機械的な構造化に留め、磨き上げはPhase 2以降で行う
- **新規作成**: 会話の依頼内容を下書き素材とする。内容がまったく無い場合のみ自由テキストで概要を受け取る。spec化が過剰な依頼 (単発のtypo修正など) では、specを作らず直接実装する選択肢を提示し、選ばれたら終了する
  - `.mjun/specs/<slug>/spec.md` を [references/spec-template.md](references/spec-template.md) の骨子で作成する (frontmatterは `status: active`)
  - `--issue` 指定時はさらに、リポジトリ内 `.github/ISSUE_TEMPLATE/` (無ければ [references/ISSUE_TEMPLATE](references/ISSUE_TEMPLATE)、日本語は [references/ISSUE_TEMPLATE_JA](references/ISSUE_TEMPLATE_JA)) から種別を自動判定してタイトル・本文・ラベル (既存ラベルのみ) を生成し、**ユーザーの承認を得てから** `gh issue create` で投影先Issueを作成して `Source:` を記録する

### Phase 2: 調査とgap分析

- `.mjun/steering/` (あれば) と関連コードを読み、原因・変更箇所・既存パターンを特定する
- 現在のspecを [references/spec-template.md](references/spec-template.md) のcontract構成と突き合わせ、欠落セクション・曖昧な記述・実装者が追加調査を要する箇所を列挙する。取り込んだIssueコメントの合意事項は反映対象として扱う
- スコープ外の問題を見つけた場合は本文に混ぜず、Out of Scopeへの記載と別spec化の提案に回す

### Phase 3: decision frontierの構築

gapから意思決定の論点を洗い出し、[references/decision-authority.md](references/decision-authority.md) に従って各論点をAgent-owned / Human-owned / Evidence-blockedへ分類する。前提が解決済みの論点 (frontier) だけを扱い、依存する論点は前提の解決後に分類し直す。

### Phase 4: decisionの解決

frontierの論点を1つずつ解決し、確定するたびに**Localのspecとdecision logへ逐次**反映する (`--dry-run` 時は会話内で保持する)。

- **Agent-owned**: decision-authority.mdの自己問答 (論点 → 調査 → 推奨案 → 反論 → 採択 + 確信度) で解決する。確信度lowは `Status: tentative` (要確認) として記録する
- **Human-owned**: `mjun-grill` の単一decisionモードへ、論点・選択肢・調査結果を渡して解決する
- **Evidence-blocked**: 不足の種類に応じて `mjun-research` (外部事実) / `mjun-prototype` (UI・状態・ロジックの実物) / trial implementation (Phase 5へ) で証拠を集め、再分類して解決する
- `--grill` 指定時は、Agent-ownedのうち非自明なもの (複数案が現実的に残るもの) もHuman-ownedと同様に1問ずつ確認する

### Phase 5: trial implementation

`--skip-trial` 指定時は省略する。実装方針の実現可能性が不確かな場合に、一時worktreeで検証する:

1. worktreeを作成する: branch名は `specify/<slug>-trial`、パスは `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>`。既存と衝突する場合は末尾に `-2`, `-3` を付ける
2. 修正方針の最小実装を行い、テストを実行して結果を確認する
3. 検証結果 (実行したテスト・結果・落とし穴・方針の修正点) を要約してdesign.mdの材料にする。diff全文は載せず、鍵になる数行のスニペットのみ許可する
4. 方針の問題が見つかった場合はPhase 4へ戻り、decisionを更新する
5. **worktreeとbranchは、成功・中断を問わず必ず削除する**: `git worktree remove --force <path>` → `git branch -D <branch>`。削除に失敗した場合はユーザーに警告する

### Phase 6: contractの提示と承認

- specのcontract全文と、変更点サマリ (追加・変更したセクションと理由)、要確認 (tentative) の一覧を提示する
- `--dry-run` はここで終了する
- AskUserQuestionで「反映する / 修正して再提示 / キャンセル」の承認を取る (使えない環境では同等の選択肢をテキストで提示する)。「修正して再提示」は指摘を反映してこのPhaseをやり直す

### Phase 7: 投影

Localのspec文書は Phase 4-6 で確定済みである (逐次更新のため書き込みは完了している)。`Source:` を持つspecのみ、承認済みcontractをIssueへ投影する:

1. `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントがあれば内容を提示し、specへ取り込むかを確認する (取り込む場合はPhase 4へ戻る)
2. Issue本文を一時ファイル経由で一括更新する (`gh issue edit <number> --body-file <tmpfile>`)。本文にはcontract (Context〜Out of Scope) + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes` を置く。**Tasksは投影しない**
3. 却下案・検討経緯は `gh issue comment` で記録し、変更サマリのコメントを1件追記する (body編集はwatcherに通知されないため)

純Local specでは何もしない。

### Phase 8: task分解

specの規模を判定する。

- 独立に検証可能な振る舞いが複数あり、1つのfresh contextに収まらない規模なら、`mjun-to-tasks` を連結して分解する。調査済みの文脈 (requirements・boundary・変更対象の見当) をプロンプトで渡す。task分解はAgent-ownedのため承認は取らない
- 単一task規模なら何もしない

### Phase 9: 結果報告

以下を簡潔にまとめて出力する。

- **Spec**: Local specのパス (`Source:` があればIssue番号とURLも)
- **変更点サマリ**: 追加・変更したセクション
- **要確認事項**: tentativeとして残したdecisionの一覧 (実装前に解消が必要)
- **Tasks**: 分解した場合はtask数と一覧、単一taskならその旨
- **次の一手**: `mjun-implement <source>` で実装を開始できる旨 (要確認が残る場合はその解消が先であることを添える)
