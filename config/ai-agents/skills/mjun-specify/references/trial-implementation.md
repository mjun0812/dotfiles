# Trial Implementation

実装方針の実現可能性を、一時worktreeでの最小実装で確かめる手順。

1. branch `specify/<slug>-trial` のworktreeを `<repo-root>/.tmp/<repo-name>-worktrees/<branch-name>` に作る (衝突すれば末尾に `-2`, `-3`)。作成後に `ln -s <repo-root>/.mjun <worktree-path>/.mjun` を張る (`.mjun/` はgit管理外のため、無いとworktree内からのspec更新が失われる)
2. 方針の最小実装を行い、テストを実行する
3. 実行したテスト、結果、見つかった問題、方針の修正点を `design.md` のTrial Implementation Notesに要約する。diff全文は載せず、鍵になる数行のスニペットだけを許す
4. 方針に問題があれば、該当decisionを解決し直して `design.md` を更新する
5. **成功でも中断でも、worktreeとbranchを必ず削除する** (`git worktree remove --force <path>` → `git branch -D <branch>`)。削除に失敗したらユーザーに警告する
