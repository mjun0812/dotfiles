# 軽微な修正

速さと、既存を壊さないことを重視する。SubAgentは使わず、このセッションで直す。

## 進め方

1. 作業する場所を決める。現在のcheckoutで作業し、commitするのは自分が変更したファイルだけにする。直すファイルにユーザーの未commitの変更が既にあれば、混ぜてcommitしないよう、触る前に止めて確認する。PRを作る場合は、現在のbranchがbase branchなら `<type>/<slug>` のbranchを切ってから作業する (`<type>` はConventional Commitsの種別、`<slug>` は英語kebab-case)。`github-pr-create` は、base branch上の変更をbranchへ移す前に確認を挟むので、先に切っておけば止まらずに済む
2. 依頼の範囲だけを直す
3. 変更したファイルに関係するlint、型検査、テストを、repositoryの自動化 (CI設定、タスクランナー、manifest) から選ぶ。それを1行1コマンドのファイルに書き、`zsh <skill-dir>/../mjun-implement/scripts/run_checks.sh <repo-root> <repo-root>/.mjun/runs/minor minor <commands-file>` で実行する。`.mjun/lint/` があれば、`zsh <skill-dir>/../mjun-rule-lint/scripts/run_local_lint.sh <repo-root> HEAD` も同じファイルへ加える (repositoryに含めないlocalのlintで、未commitの変更だけを見る)。関係するテストが無ければ、lintと型検査だけでよい。失敗したら直し、範囲内で直せなければ重い種類へ切り替える
4. `zsh <skill-dir>/../mjun-implement/scripts/check_internal_ids.sh diff HEAD` を実行する。repositoryに `.mjun/` のパスやspec内部の識別子を残さないためである
5. 差分を読み直す。依頼したことだけが変わっているか、関係の無い変更や消し忘れが無いか、振る舞いが変わっていないかを見る。振る舞いが変わっていれば、重い種類へ切り替える
6. `git-commit` skillで、自分の変更だけをcommitする。PRを作る場合は、続けて `github-pr-create` skillを呼び (sourceがIssueならその番号を `spec` として渡す)、作成後に元のbranchへ戻る

## 重い種類へ切り替える合図

- 直してみると振る舞いが変わる、または振る舞いの誤りを直していると分かった
- 依頼で指定されていない、人間が決めるべき点 (外から見える名前、既定値、仕様の解釈) が新しく出てきた。依頼で値まで指定されていれば、その判断は済んでいる
- 変更が局所的でなくなった (複数のmoduleに広がる)
