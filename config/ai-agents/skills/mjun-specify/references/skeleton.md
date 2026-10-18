# Skeleton

設計のうち、型・関数の署名・moduleの配置を、文章ではなくコードで書く。文章のInterfaces & Seamsがコードベースに合うかは、読み手が想像するしかない。骨組みなら、buildと型検査が通るかで確かめられる。実装はこの骨組みの中身を埋める形で進むので、設計と実装がずれない。

## 作るとき

`design.md` のModulesに新設があるとき、またはInterfaces & Seamsが既存の公開interfaceの署名を変えるときに作る。それ以外の変更は既存の署名の中で済み、骨組みにする構造が無い。worktreeを使うので、`--skip-trial` 指定時は作らない。

## 作り方

1. base branchから、branch `specify/<slug>-skeleton` のworktreeを作る。場所と `.mjun` のsymlinkは、[prototyping.md](prototyping.md) の最小実装と同じにする
2. 呼び出す側から決める。足す型と関数の形 (引数、戻り値、エラー) を、それを呼ぶコードでの使い方から決める。使う側から見て不自然な形は、呼ぶコードを書こうとした時点で分かる。呼ぶコードのうち骨組みに入れられるのは、手順4の範囲だけである。入れられない呼び出しは、design.mdのData Flowに書く
3. 中身は、その言語で未実装を表す標準の書き方 (例外を投げる、未実装を表すmacroを呼ぶ) にし、そのmessageかcommentに `skeleton: not implemented` を入れる。実装の後に、埋め残しをscriptで数えるためである
4. 既存のテストが通るままにする。既存の関数に足してよいのは、新しい引数、flag、型のように、今の呼び方の結果を変えないものだけである。今の呼び方が新しい未実装を通るようになる変更 (既存の処理を新しい関数の呼び出しに置き換えるなど) は入れない。既存のテストが落ち、骨組みのcommitが検査を通らなくなる。足したflagや引数は、未実装の間は何もしなくてよい。働くかどうかは、Acceptance Criteriaの検査が確かめる。既存の公開interfaceの署名を変えるなら、呼び出し側も合わせる
5. repositoryのbuild、型検査、lintと既存のテストを実行し、通るまで直す。直すには設計を変えるしかないなら、設計がコードベースに合っていないので、`design.md` の該当箇所とdecisionを直す。テストは書かない。検査は、mjun-implementがAcceptance Criteriaから作る
6. `git add -A` と `git rm -r --cached -q --ignore-unmatch .mjun` の後に `git diff --cached --binary > .mjun/specs/<slug>/skeleton.patch` で保存し、worktreeとbranchを、prototyping.mdの規則どおり削除する。`.mjun` のsymlinkは、ignoreの書き方によっては `git add -A` に入るので、indexから外す

## design.mdへの書き方

- Interfaces & Seamsには、Seamと、骨組みに置いたmoduleの外から呼ばれる型・関数を、名前とpatchの中の場所 (ファイルと型・関数の名前) だけで書く。型と引数はpatchが正しく、文章に写すと食い違う
- Change Outlineには、patchが触るパスをすべて含める
- 骨組みの後でdecisionが変わったら、patchも作り直す

## 実装での扱い

mjun-implementが、最初のgroupの前に `git apply --3way` でworktreeへ当て、検査を通してから1つのcommitにする。当たらなければ、patchを参照としてimplementerに渡す。
