# design.md Template

contractの内側にある実装設計。contract (spec.md) だけでは実装方針が伝わらない場合にだけ作る。実装手順書ではなく、実装者 (fresh context) が迷わないための構造の記述に留める。

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
