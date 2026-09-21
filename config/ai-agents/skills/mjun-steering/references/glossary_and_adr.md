# 用語集と決定記録

## 保存先と責務

- 用語集はrepo直下の `CONTEXT.md` を優先し、無ければ `.mjun/CONTEXT.md` を使う。用語が確定したら `**用語**: 定義 (1〜2文)` と `_Avoid_: 使わない言い換え` を追記する。実装詳細は書かない。
- 判断履歴とADRの正本は `.mjun/steering/decisions.md` の1ファイルとする。最初の記録時に親ディレクトリとファイルを作る。spec配下のdecisions.mdや別のadrディレクトリには作成・転記しない。
- 形式は [decisions-template.md](../../mjun-specify/references/decisions-template.md) に従う。spec作成、実装中の判断、会話での決定、履歴の発掘のいずれも同じ形式で記録する。書き手はこの記録規則を適用し、決定の追記だけのためにcore steeringのBootstrap / Syncを行わない。
- core / custom steeringは現在の実装に裏付けられたパターンを記録する。decisions.mdは判断の理由と履歴を記録する。両者が同じディレクトリにあっても、決定記録をコードから再生成したり、コードに合わせて理由を書き換えたりしない。

## 読み取りと変更

- 読み手はStatusとScopeを必ず確認する。`accepted` は採択済みの判断であり、contractの承認や実装完了を意味しない。`tentative` と `superseded` は現在の規約として適用しない。
- `Scope: project` のacceptedはプロジェクト全体の方針、`Scope: spec:<slug>` はそのspecの判断であり、他specへ自動適用しない。specが参照するD番号はspec.mdの `Decisions:` 行で管理する。参照する決定が無いときは行を省略する。
- 承認・実装開始時のtentative検査とIssue投影は、対象specの `Decisions:` にある決定だけを対象にする。別specのtentativeを解消したり、Issueへ投影したりしない。参照先が無い、重複IDがある、旧決定を参照したままの場合は黙って無視せず、参照の修正または再判断が必要と報告する。
- acceptedの判断に反する要求はHuman-owned decisionとして確認する。採択内容を変更する場合は、新しいD番号で追記し、旧entryのStatusだけを `superseded by D-NNN` にする。変更の影響を受けるspecの参照とcontractを確認し、約束が変わるspecはpendingに戻して再承認する。別specの約束を自動で置き換えない。
- 既存のDecision / Rationale / Evidenceは削除・書き換えない。tentativeの確定時だけStatusとOwnerを更新でき、確認した根拠と日付をEvidenceへ追記する。根拠の誤りや採択内容の変更は新entryで訂正する。
- codeとacceptedの判断が食い違う場合は、適用範囲と対象specの承認・実装状態を調べる。未実装の計画を直ちにCode Driftとせず、実装済みの判断への違反は報告して人間に確認する。

## ADRと履歴の発掘

- ADRは別ファイルではなく `Kind: adr` のentryとして同じファイルへ記録する。「覆しにくい」「文脈なしでは不可解」「本物のtrade-offがあった」の3条件をすべて満たす判断だけをadr、それ以外の非自明な判断をdecisionにする。種類とScopeは別であり、ADRだからprojectへ自動昇格しない。
- 由来はSourceにspecのslug、PR / Issue番号、設計文書、または会話の日付を記録する。履歴からは理由が明文の判断だけを発掘し、Sourceと決定内容が既存entryと同じなら重複作成しない。既存の判断を別specで採用するときはIDを参照する。
- コードから分かる使用技術だけで採用理由を推測しない。その事実はtech.mdやcustom steeringへ記録する。core / customから判断の理由を参照するときは `decisions.md` のD番号へリンクする。
- 用語集は追記専用。決定記録も本文は追記で保持し、状態変更の例外は上記だけとする。specの終了・削除時にも判断履歴は削除しない。
