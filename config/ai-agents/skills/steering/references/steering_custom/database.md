# Database Standards

[目的: スキーマ設計・クエリ・migration・整合性の指針を定める]

## Philosophy

- まずドメインをモデリングし、正しさの後に最適化する
- 制約は明示的に。不変条件はデータベースに強制させる
- 必要なものだけクエリする。最適化の前に計測する

## Naming & Types

- テーブル: `snake_case`・複数形 (`users`, `order_items`)
- カラム: `snake_case` (`created_at`, `user_id`)
- FK: `{table}_id` が `{table}.id` を参照する
- 型: timezone付きtimestamp。強い型のID。金額は精度のある型

## Relationships

- 1:N: 子テーブルにFK
- N:N: 複合キーを持つjoinテーブル
- 1:1: FK + UNIQUE

## Migrations

- migrationは不変。必ずrollbackを用意する
- 小さく焦点の絞られたステップにし、本番以外で先にテストする
- 命名: `{seq}_{action}_{object}` (例: `002_add_email_index`)

## Query Patterns

- 単純なCRUDと安全性にはORM。複雑・性能重視には生SQL
- N+1を避ける (eager load・バッチ化)。大きな結果セットはpaginationする
- FKと、頻繁にfilter・sortされるカラムにindexを張る

## Connection & Transactions

- poolingを使う (サイズ・タイムアウトはワークロードに合わせる)
- 1つの作業単位につき1接続。速やかにclose・返却する
- 複数ステップの変更はtransactionで包む

## Data Integrity

- NOT NULL / UNIQUE / CHECK / FK制約を使う
- 適切な場面ではDB側でも検証する (多層防御)
- 一貫した導出値にはgenerated columnを検討する

## Backup & Recovery

- 保持期間を決めて定期バックアップし、リストアをテストする
- RPO/RTO目標を文書化し、バックアップジョブを監視する

---

_パターンと決定を書く。環境固有の設定を書かない_
