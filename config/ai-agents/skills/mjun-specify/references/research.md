# Research

decisionに必要な外部事実の不足を、ユーザーへの質問ではなく一次資料の調査で埋める。1回の調査で扱う質問は、答えの形が定まる1つにする。調査は判断材料を渡すところまでで、分類と決定はPhase 3に戻って行う。

## 何を根拠にするか

ここで書いた外部事実は、実装者がそのまま信じて使う。誤りや古い情報があると実装で初めて発覚するので、出典の確かさを主張ごとに示す。

- 出典は3階層で扱う
  - Tier 1: 標準仕様、対象ライブラリのソースコード、公式ドキュメント・first-partyのAPIリファレンス
  - Tier 2 (first-party artifacts): changelog / release notes、issue trackerのmaintainer発言、テストコード、git履歴
  - Tier 3 (secondary): 解説記事、第三者ベンチマーク、Q&Aサイト、コミュニティの報告
- Tier 1/2で確かめられる主張にTier 3を根拠として使わない。Tier 3は資料の所在探しに使い、Tier 1/2に記述の無い経験的な主張 (運用上の問題、メンテナンス状況、計測した性能など) に限って根拠にする
- 対象リポジトリが使うバージョン (lockfile、manifest) に対応する資料を読む
- 事前知識は確認の優先順位を決める仮説として使い、古くなっていそうな点から先に確かめる
- ドキュメントとソースコードの食い違いや、バージョン間の違いは、どちらかに寄せずに両方を書く

記録する前に、質問に答えきれているか、結論を覆しうる直近の変更 (release notes、deprecation、破壊的変更) を確かめたか、Tier 1/2の中に反例が無いかを見直す。WebSearchは英語と日本語の両方で行う。

## 記録

`.mjun/specs/<slug>/research/<topic>.md` (`<topic>` は内容を表す英語kebab-case) に次の形式で保存し、該当decisionのEvidenceから参照する。GitHub Issueへは投稿しない。ソースコードで確認できるがドキュメントに無い挙動には `(undocumented)` を付け、出典を示せない主張はUnresolvedへ回す。

```markdown
# Research: <topic>

## Question

<調査した質問>

## Findings

- <主張 1>
  - Source: <URL / path / 仕様の節> (<参照日 または version / commit hash>)
- <主張 2> (undocumented)
  - Source: <ソースコードのpath> (<commit hash>)
- <経験的な主張>
  - Source: Tier 3。<URL 1>、<URL 2> (<参照日>)。<件数>件中<件数>件が一致
- <資料間で食い違う主張>
  - Doc: <ドキュメントの主張> — Source: ...
  - Code: <ソースコードの挙動> — Source: ...

## Unresolved

- <どの階層の出典でも確認できなかった点。なければ「なし」>

## Implication

<このdecisionに対して調査結果が示唆すること (推奨ではなく含意)>
```
