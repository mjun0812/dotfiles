# Prototyping

実物を見ないと決められないdecisionの証拠を、使い捨てのコードで得る手順。1回の試作で答える質問は1つだけとし、試作品をspecやコードの正本にしない。

## モード

- **試作**: UI (見比べないと選べない画面・レイアウト)、状態 (頭の中で保持できない遷移・エッジケース)、ロジック (挙動が想像しきれないアルゴリズム・データ変換)。一時ディレクトリ (`mktemp -d`) で作る。既存コードの上で動かす必要があれば、下の最小実装と同じ一時worktreeを使う
- **最小実装** (trial implementation): 現行コードでの実装方針の実現可能性。branch `specify/<slug>-trial` のworktreeを `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>` に作り (衝突すれば末尾に `-2`, `-3`)、`ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る (`.mjun/` はgit管理外のため、無いとworktree内からのspec更新が失われる)。`--skip-trial` 指定時は使わない

## 手順

1. 質問を1文にする。「何が分かればdecisionを決められるか」が言えなければ、試作せずにdecisionの論点を見直す
2. 質問に答える最小のものを作る。ユーザーのworking treeでは作業しない。一般化せず、production品質 (エラー処理・テスト・整形) を目指さない。最小実装ではテストも実行する
3. 動かして答えを得る。UIは案を見比べ、状態は遷移を操作し、ロジックは代表入力と境界入力の結果を観察する。人間の判断が必要な比較は、観察結果を提示して選んでもらう
4. 結果を記録する。試作は該当decisionのEvidenceに、最小実装は `design.md` のTrial Implementation Notesに、答え、決め手になった観察、見つかった問題、方針の修正点を要約する。diff全文は載せず、鍵になる数行のスニペットだけを許す。試作品そのものが記録の文章より雄弁な場合 (操作できる状態機械、UI比較など) だけ、コピーを `.mjun/specs/<slug>/prototype/` に残して記録から参照する
5. 方針に問題があれば、該当decisionを解決し直して `design.md` を更新する
6. **成功でも中断でも、一時ディレクトリ・worktree・branchを必ず削除する** (`git worktree remove --force <path>` → `git branch -D <branch>`、一時ディレクトリは `rm -rf`)。削除に失敗したらユーザーに警告する
