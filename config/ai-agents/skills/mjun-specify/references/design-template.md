# design.md Template

contractの内側にある実装設計。承認前に必ず書き、後続のtask分解と実装が構造を読む正本とする。実装手順書ではなく、実装者 (fresh context) が迷わないための構造の記述に留める。spec.mdと同じく、調査しても埋まらないセクションは省略する (空セクションやプレースホルダーを残さない) が、Modules と Change Outline は省略しない。Trial Implementation Notes はtrial implementationを実施した場合だけ書く。

```markdown
# Design: <Title>

## Modules

<moduleごとの責務。新設・変更の別>

## Interfaces & Seams

<公開インターフェース、テストで差し替えるseam>

## Data Flow

<入力から出力・永続化までの流れ>

## Test Seams

<何をどの層でテストするか>

## Trial Implementation Notes

<お試し実装で確認できたこと・落とし穴 (実施した場合)>

## Change Outline

<変更対象の概略。ファイル単位の詳細列挙はしない>
```
