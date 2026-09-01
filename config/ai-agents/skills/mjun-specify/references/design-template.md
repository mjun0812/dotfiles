# design.md Template

contractの内側にある実装設計。承認前に必ず書き、後続のtask分解と実装が構造を読む正本とする。実装手順書ではなく、実装者 (fresh context) が迷わないための構造の記述に留める。spec.mdと同じく、調査しても埋まらないセクションは省略する (空セクションやプレースホルダーを残さない) が、Modules と Change Outline は省略しない。Trial Implementation Notes はtrial implementationを実施した場合だけ書く。

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

<何をどの層でテストするか。テスト時に差し替える依存点 (fake / stubにする外部依存) があればここに書く>

## Trial Implementation Notes

<お試し実装で確認できたこと・落とし穴 (実施した場合)>

## Change Outline

<変更対象をmodule / directory単位で列挙する (新設・変更の別。テストの置き場を含む)。ファイル単位の列挙はしない。実装のreviewerはdiffのパスがこの範囲に収まるかを機械的に照合し、他のactive specとの衝突検査にも使う>
```
