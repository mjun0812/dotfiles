# Testing Standards

[目的: 何をテストするか、テストをどこに置くか、どう構成するかを定める]

## Philosophy

- 実装ではなく振る舞いをテストする
- 速く安定したテストを優先し、壊れやすいmockを最小化する
- クリティカルパスを深くカバーする。100%の追求より幅を優先する

## Organization

配置の選択肢:

- Co-located: `component.tsx` + `component.test.tsx`
- 分離: `/src/...` と `/tests/...`

どちらかをデフォルトに決め、例外には理由を求める。

命名:

- ファイル: `*.test.*` または `*.spec.*`
- Suite: テスト対象を表す名前。Case: 期待する振る舞いを表す名前

## Test Types

- Unit: 単一ユニット。依存はmock。非常に高速
- Integration: 複数ユニットの結合。外部のみmock
- E2E: フロー全体。mock最小。クリティカルな導線のみ

## Structure (AAA)

```typescript
it("does X when Y", () => {
  // Arrange
  const input = setup();
  // Act
  const result = act(input);
  // Assert
  expect(result).toEqual(expected);
});
```

## Mocking & Data

- 外部 (API/DB) はmockする。テスト対象自体はmockしない
- factory・fixtureを使い、テスト間で状態をリセットする
- テストデータは最小限にし、意図が読み取れるものにする

## Coverage

- 目標: [全体の%]。クリティカルなドメインはより高く
- CIで閾値を強制する。例外にはレビューで理由を求める

---

_パターンと決定を書く。ツール固有の設定は別の場所に置く_
