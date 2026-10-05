# 用語集と決定記録

## 保存先と責務

- 用語集はrepo直下の `CONTEXT.md` を優先し、無ければ `.mjun/CONTEXT.md` を使う。用語が確定したら `**用語**: 定義 (1〜2文)` と `_Avoid_: 使わない言い換え` を追記する。実装詳細は書かない。
- 判断履歴とADRの正本は決定記録ディレクトリ (Git管理へ移行済みなら `docs/adr/`、それ以外は `.mjun/steering/adr/`) とし、1決定 = 1ファイル (`NNNN-<slug>.md`) で保存する。暫定案・確定判断・ADRを同じディレクトリに置き、1件を複数ファイルへ分けたり、複数件を1ファイルへまとめたり、spec配下へ複製したりしない。最初の記録は、Git管理側が無ければ `.mjun/steering/adr/` に作り、Git管理への移行は下記の手順で行う。
- Git管理へ移行済みとは、`docs/adr/` に `# D-NNNN:` 見出しを持つentryファイルがある状態を指す。他の形式の既存ADRだけがある `docs/adr/` は移行済みと見なさない。
- 形式は [decisions-template.md](../../mjun-specify/references/decisions-template.md) に従う。spec作成、実装中の判断、会話での決定、履歴の発掘のいずれも同じ形式で記録する。書き手はこの記録規則を適用し、決定の追記だけのためにcore steeringのBootstrap / Syncを行わない。
- core / custom steeringは現在の実装に裏付けられたパターンを記録する。決定記録は判断の理由と履歴を記録する。両者が同じディレクトリにあっても、決定記録をコードから再生成したり、コードに合わせて理由を書き換えたりしない。

## Git管理へ移す場合

- 対応は `.mjun/CONTEXT.md` からrepo直下の `CONTEXT.md`、`.mjun/steering/adr/` の各entryファイルから `docs/adr/` の同名ファイル。移行先の用語集と判断記録が正本となり、移行元は削除する。判断記録はtentative・supersededを含む全entryを移し、D番号と履歴を維持する。移行先の既存ADRも削除・上書きしない。
- ユーザーがGit管理への移行を依頼した場合に実施する。`docs/adr/` というディレクトリや他の形式の既存ADRの存在だけでは切り替えない。以後の決定記録の解決は `docs/adr/` のentryの存在を優先する。entryがあるのにGit管理対象でない場合は移行未完了として報告する。
- 移行はメインrepositoryの作業ツリーで行う。既存の移行先があれば全内容を照合し、重複だけをまとめる。番号が移行先の既存ファイルと衝突するentryは、移行先の最大番号 + 1から振り直し、ファイル名・H1・`superseded by`・specの `Decisions:`・steeringからのリンクを新番号へ揃える。定義・判断内容の衝突は勝手に上書きせず人間へ確認する。空の移行先があるだけで移行済みと見なさない。
- 移行先へ全内容を保存し、用語・判断の欠落がないこと、D番号とsupersededの参照が解決すること、specやsteeringからのファイルリンクが新しい保存先を指すことを確認する。振り直したentry以外のD番号は変えない。
- Git管理する文書から、他のcheckoutに存在しない `.mjun/` のパスを根拠として要求しない。必要な根拠は移行先へ要約するかGit管理の資料へ移し、元の由来は履歴として保持する。未公開情報を含む場合は公開範囲をユーザーへ確認する。
- 移行先がGitの管理対象になり (`git ls-files --error-unmatch -- <移行先>` で確認し、未追跡なら移行依頼の対象としてstageする。移行だけを理由にcommit・pushまでは行わない)、内容と参照の検証が済んでから対応する移行元ファイルだけを削除する。spec、research、他のsteeringや親ディレクトリをまとめて削除しない。失敗・中断時は元を残し、完了と報告しない。
- 移行完了後はGit管理側だけを読み書きし、旧ファイルを再作成・同期しない。両方にentryが残っていたら通常の追記を止め、移行未完了として内容を照合し、上記の検証後に旧ファイルを削除する。読み取り専用skillは削除せず、重複を警告する。
- 移行完了後の通常のworktree作業では、Git管理側の記録は作業中のworktreeで読み書きし、そのbranchのcommitに含める。`.mjun/` 側のspecや未移行の判断記録はメインrepositoryの絶対パスで参照する。

## 読み取りと変更

- 読み手はStatusとScopeを必ず確認する。`accepted` は採択済みの判断であり、contractの承認や実装完了を意味しない。`tentative` と `superseded` は現在の規約として適用しない。
- `Scope: project` のacceptedはプロジェクト全体の方針、`Scope: spec:<slug>` はそのspecの判断であり、他specへ自動適用しない。specが参照するD番号はspec.mdの `Decisions:` 行で管理する。参照する決定が無いときは行を省略する。
- 承認・実装開始時のtentative検査とIssue投影は、対象specの `Decisions:` にある決定だけを対象にする。別specのtentativeを解消したり、Issueへ投影したりしない。参照先が無い、重複IDがある、旧決定を参照したままの場合は黙って無視せず、参照の修正または再判断が必要と報告する。
- acceptedの判断に反する要求はHuman-owned decisionとして確認する。採択内容を変更する場合は、新しいD番号のentryファイルを追加し、旧entryのStatusだけを `superseded by D-NNNN` にする。変更の影響を受けるspecの参照とcontractを確認し、約束が変わるspecはpendingに戻して再承認する。別specの約束を自動で置き換えない。
- 既存のDecision / Rationale / Evidenceは削除・書き換えない (上記の保存先移行、番号の振り直しと参照の更新を除く)。tentativeの確定時だけStatusとOwnerを更新でき、確認した根拠と日付をEvidenceへ追記する。根拠の誤りや採択内容の変更は新entryで訂正する。
- codeとacceptedの判断が食い違う場合は、適用範囲と対象specの承認・実装状態を調べる。未実装の計画を直ちにCode Driftとせず、実装済みの判断への違反は報告して人間に確認する。

## ADRと履歴の発掘

- ADRもdecisionと同じ形式で同じディレクトリに1件1ファイルで記録し、`Kind: adr` で区別する。「覆しにくい」「文脈なしでは不可解」「本物のtrade-offがあった」の3条件をすべて満たす判断だけをadr、それ以外の非自明な判断をdecisionにする。種類とScopeは別であり、ADRだからprojectへ自動昇格しない。
- 由来はSourceにspecのslug、PR / Issue番号、設計文書、または会話の日付を記録する。履歴からは理由が明文の判断だけを発掘し、Sourceと決定内容が既存entryと同じなら重複作成しない。既存の判断を別specで採用するときはIDを参照する。
- コードから分かる使用技術だけで採用理由を推測しない。その事実はtech.mdやcustom steeringへ記録する。core / customから判断の理由を参照するときは該当entryファイルへリンクする。
- 用語集は追記専用。決定記録も既存entryの本文は保持し、状態変更の例外は上記だけとする。specの終了・削除時にも判断履歴は削除しない。保存先移行時だけ、全内容を移した旧ファイルを削除する。
