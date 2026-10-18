# design.md Template

contractの内側にある実装設計。承認前に書く。後続のtask分解と実装は、構造をここから読む。実装手順書ではなく、実装者 (fresh context) が迷わないための構造の記述に留める。spec.mdと同じく、調査しても埋まらないセクションは省略する (空セクションやプレースホルダーを残さない) が、ModulesとChange Outlineは省略しない (task分解がModulesを、実装のreviewerがChange Outlineを読む)。Trial Implementation Notesはtrial implementationを実施した場合だけ書く。

`## Decisions` には、specを磨く過程で解決した論点を1件ずつ書く。新しい依存、抽象、設定項目を採用する判断では、より単純な候補 (既存実装や標準機能など) をAlternativesに、その候補では満たせない要求や制約をRationaleに書く。候補間で優劣が決まらず人間が選んだ場合は、そのtrade-offと選択理由を書き、候補の不足を捏造しない。

Seamは、taskの検査が呼ぶ公開interfaceを指す。関数、endpoint、CLIコマンドのいずれでもよく、CLI全体や1つのendpointのようなcompositeな境界を1つのSeamにしてよい。テスト時に差し替える依存点はSeamと呼ばず、Test Strategyに書く。

```markdown
# Design: <Title>

## Modules

<moduleごとの責務。新設・変更の別>

## Interfaces & Seams

<検査が呼ぶ公開interface (Seam)。Acceptance Criteriaが観測するものを列挙する。差し替える依存点は書かない>

## Data Flow

<入力から出力・永続化までの流れ>

## Test Strategy

<何をどの層でテストするか。テスト時に差し替える依存点 (fake / stubにする外部依存) があればここに書く。UIや対話操作、複数のclientや状態が絡む変更では、実機で確かめる操作シナリオ (操作列 → 期待する見え方) も列挙する。自動の検査が通っても、実機の操作でしか見つからない不具合があるため。見た目や操作感の良し悪しのように人間の目で判定するシナリオには `(目視)` を付け、試作で選んだ案があれば、その画像のパスを見本として添える>

## Trial Implementation Notes

<お試し実装で確認できたこと・落とし穴 (実施した場合)>

## Decisions

### <論点>

- Decision: <採択した案>
- Alternatives: <却下した案と、その理由>
- Rationale: <採用理由>
- Owner: human | agent
- Status: tentative <確信度lowで未解消のときだけ書く。解消したら行を消す>
- Evidence: <根拠。file:line、research/<topic>.md、prototypeの結果など。あれば>
- ADR: <ADRの3条件を満たす判断なら `要作成` (既存ADRを覆すなら `要作成 (ADR-NNNN を覆す)`)。ADRを書いたらその番号に置き換える>

## Change Outline

<変更対象をmodule / directory単位で列挙する (新設・変更の別。テストの置き場を含む)。ファイル単位の列挙はしない。実装のreviewerはdiffのパスがこの範囲に収まるかを機械的に照合し、他のactive specとの衝突検査にも使う>
```
