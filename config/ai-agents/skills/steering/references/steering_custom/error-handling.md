# Error Handling Standards

[目的: エラーの分類・形式・伝播・ログ・監視の方法を統一する]

## Philosophy

- 可能な限りfail fast。システム境界ではgraceful degradation
- スタック全体で一貫したエラー形式 (人間にも機械にも読める)
- 既知のエラーは発生源の近くで処理し、未知のエラーはglobal handlerへ委ねる

## Classification (発生源で処理を決める)

- Client: 入力・バリデーション・ユーザー操作の問題 → 4xx
- Server: システム障害・予期しない例外 → 5xx
- Business: ルール・状態の違反 → 4xx (例: 409)
- External: サードパーティ・ネットワーク障害 → contextを付けて5xxまたは4xxへマップ

## Error Shape (正規形式は1つ)

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "requestId": "trace-id",
    "timestamp": "ISO-8601"
  }
}
```

原則: codeは安定したenum。secretを含めない。trace情報を含める。

## Propagation (どの層で変換するか)

- API層: ドメインエラー → HTTP status+正規形式のbodyへ変換
- Service層: 型付きのbusiness errorをthrowする。文字列ベースのエラーを避ける
- Data・外部層: プロバイダのエラーを安全で実用的なcodeでラップする
- 未知のエラー: global handlerまで伝播 → 500+汎用メッセージ

パターン例:

```typescript
try {
  return await useCase();
} catch (e) {
  if (e instanceof BusinessError) return respondMapped(e);
  logError(e);
  return respondInternal();
}
```

## Logging (ノイズよりcontext)

- ログに書く: 操作、userId (あれば)、code、message、stack、requestId、最小限のcontext
- ログに書かない: パスワード、token、secret、PII全体、機密を含むbody全文
- レベル: ERROR (障害)、WARN (回復可能・エッジ)、INFO (主要イベント)、DEBUG (診断)

## Retry (安全な場合のみ)

- retryする: ネットワーク・タイムアウト・一時的な5xx、かつ操作が冪等な場合
- retryしない: 4xx、business error、非冪等なフロー
- 戦略: exponential backoff+jitter、試行回数上限、冪等キーの要求

## Monitoring & Health

- 追跡: code・カテゴリ別のエラー率、レイテンシ、飽和度。スパイクやSLI違反でアラート
- health公開: `/health` (live)、`/health/ready` (ready)。エラーをtraceに紐付ける

---

_パターンと決定を書く。実装詳細や網羅的なリストを書かない_
