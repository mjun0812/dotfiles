# refactoringの観点

このgroupはrefactoringである。振る舞いを変えずに構造を変え、振る舞いが変わっていないことを、変更の前後で同じ検査が同じく通ることで示す。

## implementer

- 整理する箇所が検査で覆われているかを、先に確かめる。覆われていなければ、今の振る舞いを固定するテストを先に書き、整理の前に通ることを確かめる。そうしないと、整理で振る舞いが変わっても気付けない
- 公開interface (関数の署名、入出力、エラーの形) を変えない。既存のテストの期待値も変えない。期待値を変える必要が出たら、振る舞いが変わっているので、変えずに `BLOCKED` で返す
- 小さな段階で進め、段階ごとに関係する検査を通す
- 整理の向かう先は、briefの目的に加えて、読み手の負担を減らすことである (`principles/minimize-reader-load.md`)。消せるものを先に消し (`principles/subtract-before-you-add.md`)、APIを置き換えるなら呼び出し元を移して古いものを消す (`principles/migrate-callers-then-delete-legacy-apis.md`)

## reviewer

次のどれかに証拠付きで反していれば、Acceptance Criterionの未充足 (項目9) としてREJECTする。

- 既存の検査の期待値が変わっていない (`git diff` でテストの変更を読む)。足したテストは、今の振る舞いを固定するものになっている
- 公開interfaceの署名、入出力、エラーの形が変わっていない
- briefの目的が、観察できる形で達成されている

整理の結果、読み手の負担 (`principles/minimize-reader-load.md` の、辿る層の数と頭に置く状態の量) が減っていなければ、REJECTにはせず、どこが減っていないかを `NOTES` に書く。振る舞いを保った整理なら、効果の薄さは差し戻すほどの誤りではないからである。
