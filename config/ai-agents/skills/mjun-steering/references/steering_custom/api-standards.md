# API Standards

[目的: 命名・構造・認証・バージョニング・エラーに関する一貫したAPIパターンを定める]

## Philosophy

- 予測可能でリソース指向な設計を優先する
- 契約は明示的にし、破壊的変更を最小化する
- デフォルトで安全に (認証を先に、最小権限で)

## Endpoint Pattern

```
/{version}/{resource}[/{id}][/{sub-resource}]
```

例:

- `/api/v1/users`
- `/api/v1/users/:id`
- `/api/v1/users/:id/posts`

HTTP verb:

- GET (読み取り。safe・冪等)
- POST (作成)
- PUT/PATCH (更新)
- DELETE (削除。冪等)

## Request/Response

Request (典型例):

```json
{ "data": { ... }, "metadata": { "requestId": "..." } }
```

成功時:

```json
{ "data": { ... }, "meta": { "timestamp": "...", "version": "..." } }
```

エラー時:

```json
{ "error": { "code": "ERROR_CODE", "message": "...", "field": "optional" } }
```

(詳細ルールはerror-handlingを参照)

## Status Codes

- 2xx: 成功 (200 読み取り、201 作成、204 削除)
- 4xx: クライアント起因 (400 バリデーション、401/403 認証認可、404 未存在)
- 5xx: サーバー起因 (500 一般、503 利用不可)

結果を最もよく表すstatusを選ぶ。

## Authentication

- 資格情報は標準の場所に置く

```
Authorization: Bearer {token}
```

- ビジネスロジックの前に未認証を拒否する

## Versioning

- URL・header・media-typeのいずれかでバージョンを表す
- 破壊的変更 → 新バージョン
- 非破壊的変更 → 同一バージョン
- 廃止までの猶予期間と周知方法を用意する

## Pagination/Filtering (該当する場合)

- Pagination: `page`+`pageSize` またはcursorベース
- Filtering: 明示的なquery param
- Sorting: `sort=field:asc|desc`

paginationのメタ情報は `meta` で返す。

---

_パターンと決定を書く。endpointのカタログを書かない_
