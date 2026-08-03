# Authentication & Authorization Standards

[目的: 認証モデル・token/sessionのライフサイクル・権限チェック・セキュリティを統一する]

## Philosophy

- 明確な分離: 認証 (誰か) と認可 (何ができるか)
- デフォルトで安全: 最小権限、fail closed、短命なtoken
- UXへの配慮: リスクが高い所にだけ摩擦を置き、それ以外は滑らかに

## Authentication

### Method (選択+理由)

- 選択肢: JWT、Session、OAuth2、ハイブリッド
- 選定: [採用した方式]。理由: [根拠]

### Flow (概要)

```
1) ユーザーが身元を証明する (資格情報またはprovider)
2) サーバーが検証し、token/sessionを発行する
3) クライアントがリクエストごとにtokenを送る
4) サーバーがtokenを検証して処理を進める
```

### Token/Session Lifecycle

- 保存場所: httpOnly cookieまたはAuthorization header
- 有効期限: accessは短命。refreshは長め (使う場合)
- Refresh: tokenをローテーションし、失効を尊重する
- 失効: logout・漏洩時にblacklist化またはローテーション

### Security Pattern

- TLSを強制する。可能な限りtokenをJSに晒さない
- tokenをaudience/issuerに束縛し、claimは最小限にする
- 機密操作にはdevice binding・IP/リスク評価を検討する

## Authorization

### Permission Model

- どれか1つを選ぶ: RBAC / ABAC / 所有権ベース / ハイブリッド
- ロール・属性は一元管理し、コード中へのハードコードを避ける

### Checks (どこで強制するか)

- Route/middleware: 粗粒度のゲート
- Domain/service: 細粒度の判断
- UI: 条件付き表示のみ (セキュリティを依存させない)

パターン例:

```typescript
requirePermission("resource:action"); // route
if (!user.can("resource:action")) throw ForbiddenError(); // domain
```

### Ownership

- パターン: 所有者または特権ロールのみが操作できる
- 変更の前にエンティティ境界で検証する

## Passwords & MFA

- パスワード: 強度ポリシー。ハッシュ化 (bcrypt/argon2)。平文禁止
- リセット: 時間制限付き・使い捨てのtoken。ユーザーへ通知
- MFA: リスクの高い操作にstep-up (ポリシー駆動)

## API-to-API Auth

- API keyまたはOAuth client credentialsを使う
- keyのスコープは最小にし、ローテーションと利用監査を行う
- 識別子 (user/key) 単位でrate limitする

---

_パターンと決定を書く。ライブラリ固有のコードを書かない_
