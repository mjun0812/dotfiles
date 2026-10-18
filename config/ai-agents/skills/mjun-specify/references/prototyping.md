# Prototyping

実物を見ないと決められないdecisionの証拠を、使い捨てのコードで得る。1回の試作で答える質問は1つにし、「何が分かればdecisionを決められるか」を1文で言えなければ、試作せずに論点を見直す。試作品は証拠であり、specやコードの基準として扱わない。

## モード

- **試作**: UI (見比べないと選べない画面・レイアウト)、状態 (頭の中で保持できない遷移・エッジケース)、ロジック (挙動を想像しきれないアルゴリズム・データ変換)。一時ディレクトリ (`mktemp -d`) で作る。既存コードの上で動かす必要があれば、最小実装と同じ一時worktreeを使う
- **最小実装** (trial implementation): 現行コードで実装方針が成り立つか。branch `specify/<slug>-trial` のworktreeを `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>` に作り (衝突すれば末尾に `-2`, `-3`)、`ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る。`.mjun/` はgit管理外なので、symlinkが無いとworktree内からのspec更新が失われる。`--skip-trial` 指定時は使わない

ユーザーのworking treeでは作業しない。未commitの変更を壊すおそれがあるためである。

## 進め方

質問に答える最小のものを作り、production品質 (エラー処理、テスト、整形) は目指さない。ただし最小実装ではテストも実行する。UIは案を見比べ、状態は遷移を操作し、ロジックは代表入力と境界入力の結果を観察する。人間の判断が要る比較は、観察結果を示して選んでもらう。

結果は、答え・決め手になった観察・見つかった問題・方針の修正点に要約し、試作なら該当decisionのEvidenceへ、最小実装なら `design.md` のTrial Implementation Notesへ書く。diff全文は載せず、鍵になる数行だけを引く。操作できる状態機械やUI比較のように試作品そのものが文章より伝わる場合だけ、コピーを `.mjun/specs/<slug>/prototype/` に残して記録から参照する。方針に問題が見つかれば、該当decisionを解決し直して `design.md` を更新する。

見た目や操作感を人間に選んでもらった試作では、比べた各案のスクリーンショットか動画を `.mjun/specs/<slug>/prototype/` に必ず残す (動きの差は動画で撮る)。選ばれた案の画像は、判断シートの「動作の例」と、Test Strategyの目視の確認シナリオの見本になる。実装後の目視では、この見本と実装の画像を並べて比べる。

一時ディレクトリ・worktree・branchは、試作の成否や中断にかかわらず削除する (`git worktree remove --force <path>` → `git branch -D <branch>`、一時ディレクトリは `rm -rf`。worktreeの親に空のディレクトリが残ったら、それも消す)。残すと次の試作のbranch名と衝突するうえ、使い捨てのコードと本物の作業の区別がつかなくなる。削除できなければユーザーへ伝える。
