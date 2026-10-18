# 型で不正な状態を表せなくする (Type System Discipline)

ありえない状態、取り違えたprimitive、扱っていないvariantを、型checkerが拒むようにする。特別な場合をhandlerで増やすより、型で起きないようにする。

型で拒める誤りは、実行やテストより前に見つかる。

## 基準

- 意味の違う値は、元が同じprimitiveでも別の型にする (利用者のIDと注文のIDなど)。作るときに1回だけ検証し、以後は型を信じる
- 外部のデータ (APIの応答、JSON、CLIの引数、設定、環境変数、DBの行) は、境界でparseして型付きのmodelにしてから使う ([境界に検証を集める](boundary-discipline.md))
- variantはすべて扱い、扱っていないものが型checkerで見つかる書き方にする
- 形を定める権威あるもの (API schema、DBのmigration、生成元の定義) があれば、型はそこから導く。同じ形を別に手で書かない

## 当てはめないとき

repositoryの言語や規約が型を使わない場合は、その規約に従う。

## 飛ばした合図

常に値が入るoptionalのfield、型checkerの指摘を消すためだけのcast、何でも受け入れる型が増える。
