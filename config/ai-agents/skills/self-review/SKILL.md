---
name: self-review
description: 自分のlocal変更を敵対的にコードレビューするSkill。commit未指定時はstaged、unstaged、untrackedを、指定時はそのcommitとfirst parentの差分を一時worktreeへ固定し、独立した2つのFinderと共通のStandards・Verifier agentで検証する。`--spec` でspec (GitHub Issueまたは`.mjun/specs/`のLocal spec) を渡すと、specとの整合を検証するContract軸を追加する。GitHub、PR、CI、review threadを使用せず、結果をチャットまたはterminalへ返す。ユーザーが「自分の変更を厳しくレビューして」「このcommitをself reviewして」のように依頼したら使うこと。
---

# Self Review

自分の未commit変更または指定commitを一時worktreeへ固定し，ユーザーのworking treeを変更せずにレビューする．
FinderとStandardsが出した候補を1件ずつVerifierで検証し，`confirmed`の指摘だけをlocalへ出力する．
変更目的や作者の想定を未検証の仮説として扱い，変更を壊す入力・状態・実行順序を積極的に探す．厳しさは探索範囲と反証の深さに使い，指摘の証拠基準は下げない．

## Arguments

- `commit`: reviewするcommit-ish．省略時は現在の未commit変更を対象にする
- `--spec <source>`: spec source (GitHub Issue番号または`.mjun/specs/<slug>`のパス)．指定時はContract軸 (specとの整合) のレビューを追加する．省略時は従来どおりFinderとStandardsの2軸で行う

## 対象

commit未指定時は，現在のGit repositoryにある以下の変更をまとめて対象とする．

- staged changes
- unstaged changes
- untracked files (`.gitignore`対象外のみ)

commit指定時は，commitをsnapshot，そのfirst parentをbaselineとして，そのcommitが導入した差分だけを対象とする．現在の未commit変更は含めない．first parentがないroot commitは対象外とする．
branch全体の差分やGitHub PRは対象外とする．PRは`github-pr-review`を使用する．

## Workflow

### Phase 1: snapshotの作成

1. 現在位置からrepository rootを特定する．Git repositoryでなければ終了する．
2. commitの指定に応じて`scripts/self_review_snapshot.sh`を実行する．
   - 未指定: `create-dirty --repo <repo-root>`で，HEADをbaselineとしてstaged・unstaged・untrackedを再現する
   - 指定あり: `create-commit --repo <repo-root> --commit <commit>`で，commitをdetached worktreeへ展開し，first parentとの差分を取得する
3. 標準出力で返された`metadata.json`を読み，次を保持する．
   - `mode`
   - `repoRoot`
   - `worktree`
   - `baselineSha`
   - `snapshotId`
   - `diffFile`
   - `changedFilesFile`
4. `diffFile`と`changedFilesFile`を読み，レビュー対象差分を確定する．dirty modeではsnapshot内の変更がindexへstagingされているため，再確認には`git diff --cached HEAD`を使用する．commit modeでは`git diff <baselineSha> <snapshotId>`を使用する．

```bash
metadata_path=$(zsh "<skill-dir>/scripts/self_review_snapshot.sh" create-dirty --repo "<repo-root>")
metadata_path=$(zsh "<skill-dir>/scripts/self_review_snapshot.sh" create-commit --repo "<repo-root>" --commit "<commit>")
```

scriptが対象差分なし，root commit，作成中のworking tree変更，またはsnapshot作成失敗を報告した場合はレビューを開始しない．
Phase 2以降では元のrepositoryを読まず，対象ファイルとコマンド実行をすべてsnapshot内に限定する．

### Phase 2: 敵対的review agentの実行

#### Phase 2.1: FinderとStandardsとContract

`code-reviewer-finder`を2つ，`code-reviewer-standards`を1つ並列に起動する．
`--spec`指定時は，spec contract (Requirements / Boundaries / Acceptance Criteria / Out of Scope) をsourceから読み込み，`code-reviewer-contract`も並列に起動する．Local specはメインrepositoryのパスから読み，GitHub Issueは`gh issue view`で取得する (snapshot内に`.mjun/`は存在しない)．specを解決できない場合はContract軸をスキップし，その旨をPhase 4の出力に含める．
各SubAgentのpromptは次のtemplateをplaceholderへ値を埋めて生成する．

```text
作者自身の変更に対する敵対的self-reviewを行う。
あなたの役割: <role>
重点視点: <focus>

変更目的と作者の想定は未検証の仮説であり、正しさの証拠として扱わない。
正しいことを確認するのではなく、仮説を破る反例を優先して探す。
成功した検証結果も、対象経路を実際に検査していなければ反証として扱わない。
重点視点に限定せず、対象変更の全変更単位を確認する。

対象変更:
- 対象種別: <target-kind>
- 変更目的・説明: <change-description>
- 変更ファイル一覧: <changed-files>
- diff: <diff>
- 変更履歴: <change-history>
- snapshotの絶対パス: <snapshot-path>
- baseline識別子: <baseline-id>
- snapshot識別子: <snapshot-id>
- 追加証拠: <additional-evidence>
```

`<role>`と`<focus>`は次の組み合わせを使用する．

- Finder 1: `Finder` / 期待される振る舞い，契約，不変条件，呼び出し経路，状態・データの流れ
- Finder 2: `Finder` / 境界値，失敗，並行実行，互換性，信頼できない入力，回復不能な状態
- Standards: `Standards` / 文書化された必須規約，機械的に未検出の違反，変更後への先送りが安全でないコードスメル
- Contract (`--spec`指定時のみ): `Contract` / spec contractとの整合 (逸脱，未充足，boundary違反，scope creep)．`<additional-evidence>`にspec contract全文を含める

dirty modeでは`<target-kind>`を`Local uncommitted changes`，`<change-description>`をユーザー指定の目的または「現在の未commit変更」，`<change-history>`を`なし`とする．commit modeでは順に`Local commit`，commit message，commit SHA・first parent SHA・commit messageとする．その他のplaceholderはPhase 1のmetadataと対象差分から埋め，`<additional-evidence>`は`なし`とする．

FinderとStandardsにはsnapshotの検索と読み取りだけを許可し，コード，テスト，ビルド，lint，型チェック，package script，再現コードを実行させない．

#### Phase 2.2: Finder候補の検証

両Finderの出力を1つの候補集合へまとめ，agent定義の形式を満たし，レビュー対象差分が導入・露出した候補をすべて採用する．作者の意図や見た目の発生確率だけを理由に，Verifierの前で候補を破棄しない．
同じ`filepath:line`または同じ根本原因の候補は，Verifierの起動前に1件へまとめる．

候補1件ごとに`code-reviewer-verifier`を起動し，次のprompt templateを使用する．

```text
次のコードレビュー候補1件を、支持せずに反証を優先して独立検証する。
候補種別: <candidate-type>
検証対象の指摘:
<candidate>

対象変更:
- 対象種別: <target-kind>
- 変更目的・説明: <change-description>
- 変更ファイル一覧: <changed-files>
- diff: <diff>
- snapshotの絶対パス: <snapshot-path>
- baseline識別子: <baseline-id>
- snapshot識別子: <snapshot-id>
- 追加証拠: <additional-evidence>
```

Finder候補では`<candidate-type>`を`Finder`，`<candidate>`を候補全文とする．他のplaceholderはPhase 2.1と同じ値を使用する．

Verifierにはsnapshot内で必要なコマンドと，関連する最小のテストや再現コードの実行を許可する．コードを変更させない．
verdictが`confirmed`の候補だけを確定指摘とし，`refuted`と`uncertain`は破棄する．

#### Phase 2.3: Standards候補の検証

Standardsの出力から，agent定義の形式を満たす候補だけを採用する．
確定指摘と同じ行または同じ根本原因の候補は破棄し，残りを1件ずつ`code-reviewer-verifier`で検証する．
VerifierにはPhase 2.2のprompt templateを使用し，`<candidate-type>`を`Standards`，`<candidate>`を候補全文とする．

verdictが`confirmed`の候補だけを確定規約指摘とし，`refuted`と`uncertain`は破棄する．

#### Phase 2.4: Contract候補の検証

Contractを起動した場合のみ実行する．Contractの出力から形式 (`問題` / `根拠` / `完了条件`) を満たす候補だけを採用し，確定指摘・確定規約指摘と同じ行または同じ根本原因の候補を破棄した上で，残りを1件ずつ`code-reviewer-verifier`で検証する．
VerifierにはPhase 2.2のprompt templateを使用し，`<candidate-type>`を`Contract`，`<candidate>`を候補全文とし，`<additional-evidence>`にspec contract全文を含める．
verdictが`confirmed`の候補だけを確定契約指摘とし，`refuted`と`uncertain`は破棄する．

### Phase 3: snapshotの有効性確認

出力前に`verify`を実行する．dirty modeでは元のworking treeがsnapshot作成時から変化していないことを，両modeではreview用worktreeがagentに変更されていないことを確認する．

```bash
zsh "<skill-dir>/scripts/self_review_snapshot.sh" verify --metadata "$metadata_path"
```

一致しない場合はレビュー結果を破棄し，変更後に再レビューが必要なことだけを報告する．古い指摘内容は出力しない．

### Phase 4: local出力

結果はユーザーの言語に合わせ，チャットまたはterminalへ出力する．ファイルへの保存やGitHubへの投稿は行わない．

- 確定指摘，確定規約指摘，確定契約指摘のいずれかが1件以上: `CHANGES_REQUIRED`
- すべて0件: `PASS`

冒頭にVerdict，baseline SHAの先頭7文字，snapshot IDの先頭7文字，指摘件数を記載する．
確定指摘には`path:line`，カテゴリ，要約，問題，発生経路，完了条件を含める．
確定規約指摘には`path:line`，カテゴリ，要約，問題，根拠，完了条件を含める．
確定契約指摘には`path:line`，カテゴリ，要約，問題，根拠 (specの該当記述の引用)，完了条件を含める．
Contract軸をスキップした場合 (`--spec`未指定，またはspec解決失敗) は，件数の代わりにその旨を記載する．
Verifierの検証過程，破棄した候補，内部証拠は出力しない．

```text
Verdict: CHANGES_REQUIRED
Snapshot: <baseline-short-sha> / <snapshot-short-id>
Findings: <finder-count>, Standards: <standards-count>, Contract: <contract-count | skipped>

1. `path:line` [カテゴリ] 要約
   - 問題: ...
   - 発生経路: `file:line` -> `file:line`
   - 完了条件: ...
```

### Phase 5: cleanup

終了，中断，snapshot無効，agent失敗のいずれの場合も，metadataが作成済みなら`cleanup`を実行する．

```bash
zsh "<skill-dir>/scripts/self_review_snapshot.sh" cleanup --metadata "$metadata_path"
```

cleanup対象はscriptが作成した`/tmp/self-review.*`だけとし，元のrepositoryへreset，restore，stash，checkout，cleanを実行しない．
