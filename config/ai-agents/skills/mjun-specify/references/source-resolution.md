# Source Resolution

このskillが従う、正本と投影の規則。専用のindexや同期状態ファイルは持たず、specと実装状態は毎回この規則で解決する。

## 目次

- 原則: 正本は常にLocal、GitHubは投影
- Local specの配置
- ライフサイクル状態 (`status`)
- Contract承認状態 (`approval`)
- `Source:` 行
- Context
- 取り込み (Issue → spec)
- 投影 (spec → Issue)
- 同期規則
- 用語集と決定記録 (steering / CONTEXT.md / adr の住み分けを含む)
- git管理と参照規則

## 原則: 正本は常にLocal、GitHubは投影

specの正本 (source of truth) は常に `.mjun/specs/<slug>/` である。GitHub Issueは入口 (取り込み) と出口 (投影) のアダプタであり、作業中にIssueを正本として読み書きしない。

```text
取り込み: Issue → .mjun/specs/<slug>/ へspec化
作業:     spec作成・task分解・実装のどの段階でもLocalの4文書だけを読み書きする
投影:     承認後、Localのcontractを Issue本文へ反映 (Sourceを持つspecのみ)
配送:     worktreeで実装 → PR (SourceがあればCloses #N)
```

## Local specの配置

```text
.mjun/specs/<slug>/
├── spec.md          # 必須。人間が承認するcontract
├── decisions.md     # 非自明な意思決定が発生した場合だけ
├── design.md        # 必須。contract内の実装設計。承認前に書く
├── tasks.md         # taskと実装状態。実装開始後は単一taskでも持つ
├── prototype/       # artifact自体を一次資料として残す場合だけ
└── research/        # 外部調査が発生した場合だけ
```

- `<slug>` は内容を表す英語kebab-case。既存slugと衝突する場合は末尾に `-2`, `-3` を付ける
- 最初からすべては作らない。`spec.md` だけから開始できる
- frontmatterにはライフサイクル状態 `status: active | done` とcontract承認状態 `approval: pending | approved` を持つ。実装の対象になるのは `approval: approved` のspecだけである
- decision確定ごとの更新は常にLocalファイルへ逐次行う。task進捗は `tasks.md` の `Status`、resume先は同ファイルの `Implementation Branch` で管理する
- task分解は単一taskでも `tasks.md` を作る。分解を省略した単一taskでは、実装側がworktree作成後に同じ形式で作る
- `Implementation Branch` があり、そのlocal branchが存在すればtaskのstatusにかかわらずそのbranchからresumeする。branchが存在しない場合は記録を破棄して新規branchで続行する。done taskのAcceptance Criteriaが変わった場合は `ready` に戻し、再実装・再検証の対象にする

## ライフサイクル状態 (`status`)

specは増えていくため、堆積管理のためのライフサイクル状態をfrontmatterで持つ。

- 作成・取り込み時に `status: active` を書き、配送の完了時に実装側が `status: done` へ更新する
- **照合・逆引き・一覧の対象は `status: active` のspecだけ**とする。doneのspecも明示的にパスを渡せば読める
- 放棄したspecは手動でdoneにするか削除する
- `status` は堆積管理であり承認ゲートではない。contract承認は別の `approval` で管理する

## Contract承認状態 (`approval`)

- contractの作成・更新を始める前に `approval: pending` を書き、Phase 6で人間が「反映する」を選んだ後にだけ `approval: approved` へ更新する
- session中断、tool障害、明示的なキャンセルのいずれでも、承認が完了していないspecは `pending` のまま残る
- 実装側は `approval: approved` 以外のspecを受け付けない (spec外の単発Markdownを起点にする実装には適用しない)

### 一覧の手順

activeなspecの一覧は、索引ファイルを作らず毎回導出する。

```bash
grep -l "^status: active" .mjun/specs/*/spec.md   # activeなspecの列挙
grep -m1 "^# " <spec.md>                          # H1タイトル
grep -m1 "^Source: " <spec.md>                    # 投影先 (あれば)
```

## `Source:` 行

GitHub Issueから取り込んだspec (または投影時に投影先Issueを作ったspec) は、`spec.md` のH1直下に投影先への参照を1行持つ。

```markdown
# <Title>

Source: #123

## Context
```

- `Source:` 行が無いspecは純Local (投影しない)
- これはIssueへの**参照**であり、lifecycle状態ではない。snapshotや同期状態のファイルは作らない
- Issue番号からspecを逆引きするときは、**activeなspec** (`status: active`) の中から `Source: #<N>` を検索する。複数ヒットした場合は一覧を提示してユーザーに選んでもらい、選ばれなかった方の整理 (doneへの変更または統合) を促す
- activeでmissした場合はdoneのspecからも検索し、あれば実装済みの可能性と再開方法 (statusをactiveへ戻す、または取り込み直し) を案内する (未取り込みと誤認して取り込み直しへ誤誘導しない)

## 取り込み (Issue → spec)

- Issue本文とコメントを読み、spec.mdのcontract構成へ構造化する (slugはIssueタイトルから)。**取り込みを行うのはこのskillだけ**である
- **入口は常にこのskill**: task分解や実装に未取り込みのIssue番号が渡された場合、それらは中止してこのskillでの取り込みを案内する。Issueが直行で実装できる品質かの判断を取り込み側で肩代わりしない (trivialな依頼はPhase 1の「spec化が過剰なら直接実装を提示」で振り分ける)

## 投影 (spec → Issue)

`Source:` を持つspecは、contract承認後にIssue本文へ投影する。

- 投影範囲: contract (Context〜Out of Scope) + `## Decision Log` (採用decisionの要約表) + 必要なら `## Design Notes` + `tasks.md` があれば `## Tasks` (taskタイトルのチェックボックス一覧)
- **task進捗は投影しない**。進捗は内部 (tasks.md) だけで管理し、外部からはPRで見える。実装はIssueへ一切書き込まない (Issueの `## Tasks` は承認時点のスナップショット)
- 書き換えは一時ファイル経由の一括更新 (`gh issue edit --body-file`) + 変更サマリの1コメント (body編集はwatcherに通知されないため)
- 却下案・検討経緯はIssueコメントへ記録する
- 純Local specは投影しない

## 同期規則

- 投影の直前に `gh issue view` で最新のIssueを取得する。取り込み後に付いた新しいコメントがあれば内容を提示し、specへ取り込むかを確認する
- 外部でIssue本文が編集されていても、投影は承認済みのLocal contractで上書きする (正本はLocal)。上書き内容は承認フローで提示済みのため、そこで差分に気付ける

## 用語集と決定記録

specをまたいで効く語彙と決定は、spec配下ではなく `.mjun/` 直下に置く。どちらもコードから再生成できない人間の決定であり、steering (コードに証拠がある事実) とは分けて扱う。

```text
.mjun/
├── CONTEXT.md       # 用語集。用語が確定した時点で1件ずつ追記する
├── adr/             # 決定記録。NNNN-<slug>.md (4桁連番、既存の最大値 + 1)
├── specs/
└── steering/
```

- `CONTEXT.md` は用語集だけを持つ。実装詳細・spec・決定は書かない。形式は `**用語**: 定義 (1〜2文)` に `_Avoid_: 使わない言い換え` を添える。複数の呼び名があれば1つを選び、他は `_Avoid_` に入れる
- ADRは見出しと1〜3文 (文脈・決定・理由) で書く。必要なときだけ `Status: proposed | accepted | deprecated | superseded by NNNN` のfrontmatter、Considered Options、Consequencesを足す
- ADRには由来 (出典) を必ず1行添える: specから投影したものは `由来: <slug> / D-NNN`、履歴から発掘したものは `由来: PR #N` / `Issue #N` / `docs/<path>`、会話中の決定は `由来: 会話 (YYYY-MM-DD)`。衝突時に人間が出典を見て判断できるようにする
- ADRにするのは、**覆しにくい**・**文脈なしでは不可解**・**本物のtrade-offがあった**、の3条件をすべて満たす決定だけ。1つでも欠ければ `decisions.md` に留める
- 投影: 実装の配送完了時に、`decisions.md` の `Status: accepted` のdecisionから3条件を満たすものをADRへ書く。既存ADRを覆すdecisionなら旧ADRを `superseded by NNNN` にする
- 発掘: steeringの整備時に履歴 (merged PR、closed Issue、設計doc) から、理由が明文で書かれている決定と用語を追記する。コードからの推測はADRにせずsteeringの事実に留める
- 追記専用: どのskillも既存の用語・ADRを書き換えたり削除したりしない。決定を覆すときは新しいADRを書き、旧ADRを `superseded by NNNN` にする
- repoに `docs/adr/` があればそれを正とし、`.mjun/adr/` へ複製しない。読み込む側は両方を読む
- 読み込み: spec・design・taskを作る側とレビューする側は、`CONTEXT.md` の語彙を使い、既存ADRと矛盾する要求・設計を衝突として扱う (spec側を直すか、Human-owned decisionとしてADRを覆すかを人間が決める)

### steering / CONTEXT.md / adr の住み分け

事実はsteering、名前はCONTEXT.md、理由はADRに書く。置き場所は次の問いで決める。

| 置き場所     | 答える問い                         | 中身                                                          | 判定テスト                                              |
| ------------ | ---------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------- |
| `steering/`  | 今どうなっているか (what / how)    | 技術スタック、構成、規約、従うべきパターン (ファイルパス付き) | この記述を消しても、コードを読めば復元できる            |
| `CONTEXT.md` | この概念を何と呼ぶか (name)        | プロジェクト固有の概念の見出し語、1〜2文の定義、`_Avoid_`     | どちらの呼び名が正かはコードから決まらない (人間の選択) |
| `adr/`       | なぜそうしたか、何を捨てたか (why) | 文脈・決定・理由 (+代替案)。3条件を満たすものだけ             | 将来の誰かがコードを見て「直そう」と思う                |

重なりやすい箇所の扱い:

- **tech.md / customの「決定」とADR**: steeringには決定の結果としての現在の規約だけを書き、理由と代替案を書かない。理由が必要な決定はADRに書き、steering側から `→ adr/NNNN` と参照する。有効なADRは必ずsteeringのどこかにパターンとして現れる (現れていなければコードで守られていない)。steeringのパターンすべてにADRは要らない
- **product.md と CONTEXT.md**: product.mdは目的・価値・できることを文章で書き、用語を使うが定義しない。「Xとは〜のこと」と書きたくなったらCONTEXT.mdの行にする。CONTEXT.mdには技術用語と振る舞いの説明を入れない
- **どれでもない決定** (一度きり、可逆、自明) は specの `decisions.md` に留めて外に出さない

コードと食い違ったときにどちらを正とするかは3つで逆になる:

| 置き場所     | コードと食い違ったら                              | 理由                                                |
| ------------ | ------------------------------------------------- | --------------------------------------------------- |
| `steering/`  | steeringをコードに合わせて更新する                | 事実の記述であり、コードが正                        |
| `adr/`       | コードが決定に反していると報告する。ADRは直さない | 決定が正。覆すなら新ADR + 旧を `superseded by NNNN` |
| `CONTEXT.md` | 呼び名がコードで変わったと報告し、人間に確認する  | 呼び名の変更は決定であり、自動で書き換えない        |

ライフサイクルと書き手:

| 置き場所     | 再生成                  | 更新方式                               | 書き手                                                         |
| ------------ | ----------------------- | -------------------------------------- | -------------------------------------------------------------- |
| `steering/`  | できる (Bootstrap)      | 追記主義だが、事実が変われば書き換える | steeringの整備だけ                                             |
| `CONTEXT.md` | できない (seedはできる) | 追記専用                               | 用語を確定した側 (spec作成、会話中の作業) + 履歴からの発掘     |
| `adr/`       | できない (seedはできる) | 追記専用 + superseded                  | 決定した側 (実装の配送時の投影、会話中の作業) + 履歴からの発掘 |

「seedはできるが再生成はできない」がsteeringとの決定的な差であり、steeringの整備がCONTEXT.md / ADRに追記しかしないのはこのためである。

## git管理と参照規則

`.mjun/` はグローバルgitignoreによりgit管理外である。したがって:

- worktreeやPR checkoutには `.mjun/specs/` が**存在しない**。worktree内の作業からspec文書を参照・更新するときは、必ずメインrepositoryの絶対パスを使う。SubAgentへはspec内容をプロンプトに合成して渡し、worktree内のパスを読ませない
- specは**内部文書**である。PR本文・PRタイトル・commit messageなど外部向けの出力では、`.mjun/` 配下のパスやspecの存在に言及しない。外部へ見せるspecの参照はGitHub Issue (`Closes #N`) だけを使う
- PRレビュー側は、contractを「`--spec` 引数で明示されたsource → PR本文の `Closes #N` が指すIssue」の順で解決する。どちらも無ければContract観点をスキップする (Issue本文は承認時点の投影であり、最新の正本はLocal specにある)
- resumeとtask進捗の永続化は、`.mjun/` が残っている同一working tree上でのみ有効
