# Decision Authority

specを磨く過程で現れる各論点を、誰が決めるかで3種類に分ける。

> Agentはfactsを調べ、contract内の可逆なdesignを決める。HumanはAgentの権限を超えるdecisionを決める。

人間の時間は、人間にしか決められない論点だけに使う。調べれば分かるfactsを人間に聞かず、Human-ownedをagentが決めない。後者は承認されたcontractに、人間が選んでいない振る舞いや範囲を紛れ込ませることになる。

## Agent-owned

根拠 (コード、steering、repository内のprior art、公式仕様、既存architecture) から答えがほぼ一意に決まり、public behaviorを変えず、contract内部で局所的に覆せる論点。Agentが調べて自分で決める。

各論点は1つずつ、次の順で決める。まとめて即断すると、論点ごとの根拠と反論を検討しないまま確定してしまう。

1. 何を決めるのかを1文にする
2. コードベース、規約、ドキュメントから判断材料を集める。推測で決めない
3. 根拠つきの案を立て、採択の前にその案への最も強い反論を1つ検討する
4. 採択し、確信度をhigh / medium / lowで記録する

確信度lowの決定は `design.md` の `## Decisions` に `Status: tentative` 付きで残し、確定扱いにしない。tentativeは承認の前 (mjun-specify Phase 4) に、証拠で確信度を上げるか人間に確認して0件にする。承認後に編集されてtentativeが残った場合は、mjun-implementが起動時に検出して人間に続行を確認する。

## Human-owned

決め方によって、利用者や他の担い手から見える結果が変わる論点、または根拠からは決まらない論点。Product behavior、Domain semantics、Scope、Public contract、Boundary ownership、UX上のtrade-offがこれに当たる。技術的には、複数案に明確な優劣が無いもの、高コストで覆しにくいもの、steeringとユーザー要求が衝突するものも含む。

Agent-ownedの条件にも当たる場合はHuman-ownedを優先する。人間に聞くときは推奨案と理由を添える。互いに依存しない論点は1回の質問にまとめる。

## Evidence-blocked

分類に必要な事実が足りず、まだ誰にも決められない論点。証拠を集めてから、Agent-ownedかHuman-ownedへ分類し直す。

| 不足しているもの         | 解消手段                                    |
| ------------------------ | ------------------------------------------- |
| 外部仕様・外部事実       | 一次資料の調査 ([research.md](research.md)) |
| UI・状態・ロジックの実物 | 試作 ([prototyping.md](prototyping.md))     |
| 現行codeでの実現可能性   | 最小実装 ([prototyping.md](prototyping.md)) |
