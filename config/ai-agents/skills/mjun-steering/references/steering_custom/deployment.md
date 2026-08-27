# Deployment Standards

[目的: 環境とpipelineのパターンを明確にし、安全で再現可能なリリースを実現する]

## Philosophy

- 自動化する。デプロイ前にテストし、デプロイ後に検証する
- 段階的なrolloutと高速なrollbackを優先する
- 本番の変更は観測可能かつ可逆でなければならない

## Environments

- Dev: 高速なイテレーション。デバッグ有効
- Staging: 本番のミラー。リリース検証
- Prod: 堅牢化。監視。最小権限

## CI/CD Flow

```
Code → Test → Build → Scan → Deploy (staged) → Verify
```

原則:

- テスト・スキャンの失敗で即座に止め、デプロイをブロックする
- 成果物のビルドは再現可能にする (lockfile、バージョン固定)
- 本番へは手動承認を挟み、監査可能な記録を残す

## Deployment Strategies

- Rolling: インスタンスを段階的に置き換える
- Blue-Green: 2系統の間でトラフィックを切り替える
- Canary: まず少数ユーザーに出し、健全なら拡大する

リスクプロファイルに応じて選び、デフォルトを文書化する。

## Zero-Downtime & Migrations

- health checkでトラフィックを制御する。graceful shutdown
- rollout中のDB変更は後方互換にする
- migrationは独立したステップにし、rollback経路をテストする

## Rollback

- 直前のバージョンを即時復帰できる状態に保ち、revertを自動化する
- fix-forwardよりrollbackを速くする。発動条件を文書化する

## Configuration & Secrets

- 12-factorに従い設定は環境変数で。secretはcommitしない
- secret managerを使い、ローテーション・最小権限・アクセス監査を行う
- 必須の環境変数は起動時に検証する

## Health & Monitoring

- エンドポイント: `/health`、`/health/live`、`/health/ready`
- レイテンシ・エラー率・スループット・飽和度を監視する
- SLO違反・スパイクでアラートする。アラート疲れを避けて調整する

## Incident Response & DR

- 標準playbook: 検知 → 評価 → 緩和 → 周知 → 解決 → post-mortem
- 保持期間付きバックアップ。リストアをテストする。RPO/RTOを定義する

---

_rolloutのパターンと安全策を書く。プロバイダ固有の手順を書かない_
