---
name: mjun-specify
description: >-
  アイデア・GitHub Issue・ローカルMarkdownを、実装可能なspec (contract) へ仕上げるSkill。
  factsを調査してAgentの権限内のdecisionを自分で決め、人間の判断が必要なdecisionだけを1問ずつ確認し、
  承認後に反映して必要ならtask分解まで行う。`--local` 指定時はGitHubを使わず `.mjun/specs/` に保存する。
  ユーザーが「issue作って」「バグ報告を起票して」「specを作って」「#Nを実装できるレベルに詰めて」「issueを磨いて」
  「この設計docをspecにして」のように依頼したら使うこと。
  実装からPR作成まで進める依頼や、既にspecが承認済みの実装依頼には使わない。
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(gh:*), Bash(git:*), Bash(mkdir:*), Bash(rm:*), Bash(cd:*), Bash(ls:*), Bash(cat:*), Bash(mktemp:*), Skill(mjun-grill), Skill(mjun-research), Skill(mjun-prototype), Skill(mjun-to-tasks)
---

# mjun-specify

アイデア・GitHub Issue・ローカルMarkdownを、実装者が追加調査なしで着手できるcontractへ磨き上げるSkillです。人間はcontract (何を作るか) を承認し、その内側の設計はAgentが決めます。

GitHub操作は必ず `gh` CLIで行うこと。GitHub connector/pluginやMCPのGitHubツールは使用しない。

連結先: 意思決定の解消に `mjun-grill` / `mjun-research` / `mjun-prototype` を、承認後のtask分解に `mjun-to-tasks` を、Skill toolで呼び出す。Skill toolが使えない環境では、連結先skillのSKILL.mdを直接読み込み、その手順に従って実行する。

## Arguments

- `source` (任意): 対象。GitHub Issue番号 (`#123` / `123`)、GitHub URL、`.mjun/specs/<slug>`、またはMarkdownパス。未指定の場合は会話内容を下書き素材として新規specを作る
- `--local` / `--github` (任意): modeの明示指定
- `--grill` (任意): Human-firstモード。非自明なdecisionを1問ずつ人間と決める
- `--skip-trial` (任意): trial implementation (Phase 5) を省略する
- `--dry-run` (任意): contract全文の提示 (Phase 6) で停止し、Issue・ファイルへの書き込みとtask分解を一切行わない

modeの解決・Local specの配置・GitHub Issueとの対応は [references/source-resolution.md](references/source-resolution.md) に従う。矛盾する入力 (例: `#123 --local`) は中止して確認する。

## 2つのモード

- **Agent-first (デフォルト)**: Agentが可能な限り調査して決め、Human-owned decisionだけを1問ずつ確認する
- **Human-first (`--grill`)**: factsはAgentが調査するが、非自明なdecisionはすべて人間と1問ずつ決める。決定はその場でspecへ反映する (grill-with-docs相当)

## Task

### Phase 0: 前提取得

- sourceとmodeを解決する。GitHub modeでは `gh auth status` を確認し、失敗時は停止して認証を案内する。Local modeでは `gh` を一切呼ばない
- 既存sourceの場合は本文を取得する (Issue: `gh issue view <number> --json number,state,title,body,labels,comments,url`、Local: ディレクトリ配下の全mdをRead)。Issueが `state: CLOSED` なら中止して報告する
- 出力言語をsourceの言語に合わせて決める (曖昧なら日本語の依頼には日本語)

### Phase 1: sourceの確保

既存sourceがあればこのPhaseをスキップする。新規の場合:

- 会話の依頼内容を下書き素材とする。内容がまったく無い場合のみ自由テキストで概要を受け取る
- spec化が過剰な依頼 (単発のtypo修正など) では、specを作らず直接実装する選択肢を提示し、選ばれたら終了する
- **GitHub mode**: リポジトリ内 `.github/ISSUE_TEMPLATE/` があればそれを、無ければ [references/ISSUE_TEMPLATE](references/ISSUE_TEMPLATE) (日本語は [references/ISSUE_TEMPLATE_JA](references/ISSUE_TEMPLATE_JA)) から種別 (bug_report / feature_request / task / test / research) を自動判定して使う。タイトル・本文・ラベル (既存ラベルのみ) を生成し、**ユーザーの承認を得てから** `gh issue create` する
- **Local mode**: `.mjun/specs/<slug>/spec.md` を [references/spec-template.md](references/spec-template.md) の骨子で作成する (`mkdir -p`。GitHubへは接続しない)

### Phase 2: 調査とgap分析

- `.mjun/steering/` (あれば) と関連コードを読み、原因・変更箇所・既存パターンを特定する
- 現在のspec本文を [references/spec-template.md](references/spec-template.md) のcontract構成と突き合わせ、欠落セクション・曖昧な記述・実装者が追加調査を要する箇所を列挙する。Issueのコメントでの合意事項は反映対象として扱う
- スコープ外の問題を見つけた場合は本文に混ぜず、Out of Scopeへの記載と別spec化の提案に回す

### Phase 3: decision frontierの構築

gapから意思決定の論点を洗い出し、[references/decision-authority.md](references/decision-authority.md) に従って各論点をAgent-owned / Human-owned / Evidence-blockedへ分類する。前提が解決済みの論点 (frontier) だけを扱い、依存する論点は前提の解決後に分類し直す。

### Phase 4: decisionの解決

frontierの論点を1つずつ解決し、確定するたびにspecとdecision logを更新する (GitHub modeでは会話内に保持し、Phase 7で一括反映する)。

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

### Phase 7: 反映

- **Local mode**: `spec.md` を確定内容で更新する。非自明な決定は `decisions.md` へ、contractだけで実装方針が伝わらない場合は `design.md` へ書く (遅延作成: 必要になった文書だけ作る)
- **GitHub mode**: Issue本文を一時ファイル経由で一括更新する (`gh issue edit <number> --body-file <tmpfile>`)。本文にはcontract + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes` を置く。却下案・検討経緯は `gh issue comment` で記録し、変更サマリのコメントを1件追記する (body編集はwatcherに通知されないため)

### Phase 8: task分解

反映後、specの規模を判定する。

- 独立に検証可能な振る舞いが複数あり、1つのfresh contextに収まらない規模なら、`mjun-to-tasks` を連結して分解する。調査済みの文脈 (requirements・boundary・変更対象の見当) をプロンプトで渡す。task分解はAgent-ownedのため承認は取らない
- 単一task規模なら何もしない

### Phase 9: 結果報告

以下を簡潔にまとめて出力する。

- **Source**: Issue番号とURL、またはLocal specのパス
- **変更点サマリ**: 追加・変更したセクション
- **要確認事項**: tentativeとして残したdecisionの一覧 (実装前に解消が必要)
- **Tasks**: 分解した場合はtask数と一覧、単一taskならその旨
- **次の一手**: `mjun-implement <source>` で実装を開始できる旨 (要確認が残る場合はその解消が先であることを添える)
