# Security Standards

[目的: バリデーション・認可・secret・データ保護のパターンでセキュリティ方針を定める]

## Philosophy

- 多層防御。最小権限。デフォルトで安全。fail closed
- 境界でバリデーションし、出力先に応じてサニタイズする。入力を信用しない
- 認証 (誰か) と認可 (何ができるか) を分離する

## Input & Output

- API境界とUIフォームでバリデーションし、型と制約を強制する
- 出力先 (HTML、SQL、shell、ログ) に応じてサニタイズ・エスケープする
- block-listよりallow-listを優先する。早期に、最小限の情報で拒否する

## Authentication & Authorization

- 認証: 身元を検証し、短命なtoken/sessionを発行する
- 認可: 操作の前に権限を確認する。デフォルトで拒否する
- ポリシーは一元管理し、チェックをコード中に重複させない

パターン:

```typescript
if (!user.hasPermission("resource:action")) throw ForbiddenError();
```

## Secrets & Configuration

- secretはcommitしない。secret managerまたは環境変数に置く
- 定期的にローテーションし、アクセスを監査し、スコープを最小にする
- 必須の環境変数は起動時に検証し、欠けていれば即座に失敗させる

## Sensitive Data

- 収集を最小化する。ログではマスク・秘匿する。保存時・転送時に暗号化する
- ロール・need-to-knowでアクセスを制限し、機密レコードへのアクセスを記録する

## Session/Token Security

- 可能な限りhttpOnly+secure cookie。常にTLS
- 有効期限は短く。refresh時にローテーション。logout・漏洩時に失効
- tokenをaudience/issuerに束縛し、claimは最小限にする

## Logging (security-aware)

- 認証試行、権限拒否、機密操作をログに残す
- パスワード、token、secret、PII全体はログに書かない。bodyの全文も避ける
- requestIdとcontextを含めてイベントを相関できるようにする

## Headers & Transport

- TLSを強制する。HSTS
- securityヘッダを設定する (CSP、X-Frame-Options、X-Content-Type-Options)
- モダンな暗号を使い、弱いプロトコル・cipherを無効化する

## Vulnerability Posture

- 安全なライブラリを選び、依存を最新に保つ
- CIで静的・動的スキャンを行い、追跡して修正する
- よくある脆弱性クラスをチームに周知し、上記のパターンとして明文化する

---

_パターンと原則を書く。具体的な設定はopsドキュメントへのリンクに留める_
