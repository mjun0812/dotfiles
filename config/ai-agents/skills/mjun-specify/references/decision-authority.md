# Decision Authority

specを磨く過程で現れる各論点を、誰が決めるかで3種類に分類する。

> Agentはfactsを調べ、contract内の可逆なdesignを決める。HumanはAgentの権限を超えるdecisionを決める。

## Agent-owned

Agentが調査し、自分で決める。次のいずれかに該当するもの。

- コードを読めば答えが分かる
- steeringに既存方針がある
- リポジトリに明確なprior artがある
- 公式仕様で決まっている
- public behaviorを変えない
- contract内部の実装詳細
- 局所的で可逆
- 既存architectureからほぼ一意に決まる

### 自己問答の手順

各Agent-owned decisionは、1つずつ次の手順で解決する。複数の分岐をまとめて即断しない。

1. **論点**: 何を決めるのかを一文で明示する
2. **調査**: コードベース・規約・ドキュメントから判断材料を集める。推測で決めない
3. **推奨案**: 根拠とともに案を立てる
4. **反論**: 採択する前に、その案への反論 (devil's advocate) を必ず一つ挙げて検討する
5. **採択**: 案を決定し、確信度を high / medium / low で記録する

確信度lowの決定は「要確認」(`Status: tentative`) としてdecision logへ明示的に残す。無断でacceptedにしない。tentativeの残留はmjun-implementの起動時検査で検出され、人間の確認を求める関所として働く (機械的に実装を止めるhard gateではない。人間が続行を選んだdecisionは `accepted` へ更新される)。

## Human-owned

人間へ1問ずつ確認する。次のいずれかに該当するもの。

- Product behavior
- Domain semantics
- Scope
- Public contract
- Boundary ownership
- UX上のtrade-off
- 複数案に技術的な明確な優劣がない
- 高コストで覆しにくい
- steeringとユーザー要求が衝突する

必ず推奨案と理由を添える。調べれば分かるfactsを人間に聞かない。

## Evidence-blocked

情報が足りず、まだAgentもHumanも決められないもの。証拠を集めてから再分類する。

| 不足しているもの         | 解消手段                                      |
| ------------------------ | --------------------------------------------- |
| 外部仕様・外部事実       | research (一次資料調査)                       |
| UI・状態・ロジックの実物 | prototype (使い捨て試作)                      |
| 現行codeでの実現可能性   | trial implementation (一時worktreeで最小実装) |

証拠が得られたら、そのdecisionをAgent-ownedかHuman-ownedへ再分類して解決する。
