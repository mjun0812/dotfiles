# Global Instructions

- 常に日本語で応答すること。
- 文章中に「?」、「？」などの疑問符がある場合や、文章が疑問形の場合には回答のみを行い、編集を行わないこと。
- 常に半角括弧を使用すること。全角括弧は使わないこと。
- ユーザーのタイムゾーンはJST (UTC+9)。時刻をユーザーに伝えるときはJSTに変換すること。

## Development Principles

### Simplicity First

問題を解決する最小限のコード。推測による実装はしない。

- 求められた以上の機能を追加しない。
- 起こり得ないケースのための過剰なエラー処理・エラーハンドリングをしない。

### Goal-Driven Execution

成功条件を定義する。検証されるまでループする。

- バグ修正: バグを再現するテストを書き、それを通す
- リファクタリング: 変更前後でテストが通ることを確認する

### Design Principles

- 設計や実装の前に、要件と関連コードを読み、入力から出力までの実際の処理経路を理解する。
- 後方互換性を維持しない。互換レイヤー、フォールバック、移行処理を追加するのではなく、不要になった処理経路は削除する。
- DBの変更は、既存のデータに影響を与えないように慎重に行う。取り返しのつかない変更は行わないこと。
- アーキテクチャ上の判断は長期的な視点で行う。後で置き換えることを前提とした、その場しのぎの実装を採用しない。
- 静的に検査できる規約は、プロンプトやドキュメントではなく、そのリポジトリのlinter設定(ruffなど)かスクリプトの実装、`ast-grep` のルールなど、機械的検査として記述する。

## SubAgent

- SubAgentの完了は `wait_agent` で待つ。`sleep` や `list_agents` の繰り返しでpollingしない。
- 実行中のSubAgentへ進捗確認の `send_message` を送らない。結果はSubAgentの最終応答で受け取る。
- SubAgentとして動くときは、親へ途中経過のmessageを送らず、結果は最終応答だけで返す。
- SubAgentへタスクを移譲する際は、タスクの性質に応じて呼び出し時にmodelとthinking effortを指定する
  - Luna: 決定的・機械的な定型作業や標準的な実装・調査。
  - Sol: 設計判断や曖昧な要件(アーキ設計、複数ファイル横断リファクタ、難しいデバッグ)を伴う作業。迷ったらこのモデルを作成する
  - Astra: Solが達成できない、またはSolの判断が不十分な場合、人間の専門家の判断を必要とする作業に使用する。SubAgentの結果が不十分な場合に、より高性能なモデルで再実行する。

## Tool

- skillや指示に登場する `AskUserQuestion` は `request_user_input` に読み替えること。
- 選択肢付きの質問には同期の `request_user_input` を使用し、`request_user_input_async` は使用しないこと。
- 選択肢付きの質問後は、回答を受け取るまで作業を進めないこと。
- ブラウザ操作では、ログイン状態が必要な操作とユーザーのChromeでの操作には `playwriter` skillを、ログインが不要な操作には `agent-browser` skillを使うこと。
- CSV・TSV・Parquet・JSONなどのデータファイルを集計・変換・調査するときは、awkやPythonのscriptを書かずにduckdb CLIを使うこと (`duckdb` skill)。プロジェクトのコードに組み込むデータ処理は、そのプロジェクトの既存の依存に従うこと。

## Glossary and ADR

- リポジトリに `.mjun/steering/` が存在する場合、配下の `*.md` をすべてプロジェクトメモリとして読み込むこと。
- steeringの作成・更新は `mjun-steering` skillで行うこと。
- 用語集 `CONTEXT.md` はセッション開始時にcontextへ注入される。注入された場合は、定義された語彙を使うこと。

## Git

GitHub操作は必ず `git, gh` CLIで行うこと。

- `gh` コマンドでCIやPRの完了などを長時間待機する場合は、Rate Limitの消費を抑えるため、適切な間隔を空けて明示的に状態を再取得すること。

## Python

- 環境およびパッケージ管理には `uv` を使用すること。
- コードのリンターには`uvx ruff check --fix` を使用すること。
- コードの型チェックには`uvx ty check` を使用すること。
- SQLAlchemy ORMは **2.0 スタイル**の記法を使用してください。

## Markdown

- 英数字と日本語の間、および半角括弧 `()` の外側に半角スペースを入れないこと。inline codeの前後には入れてよい。コードブロックの中は対象外
  - 良い例: MLflowサーバをECS(arm64)で動かす。`mlflow-server` のrepoを使う。
  - 悪い例: MLflow サーバを ECS (arm64) で動かす。
- 区切り線 `---` を多用しないこと。節の区切りは見出しで表す。文書の中で性質が大きく変わる境界(例: 現行の手順と旧構成の記録の間)にだけ使う
- コマンドがbashとzshで異なる場合は、同じコードブロックに `# bash` と `# zsh` のコメントで分けて両方を書くこと。共通の部分は1つにまとめる

## Japanese Writing

- チャットの応答にはtextlintをかけない。ファイルを経由せずに外部へ送る日本語 (PR本文、Issue、コメント、commitメッセージなど) だけ、送る前に `printf '%s\n' "<本文>" | textlint --stdin --stdin-filename body.md` にかけ、指摘箇所を文意を保ったまま書き直すこと。`--stdin` と `--fix` は併用しない (`--stdin-filename` の名前でファイルが書き出される)。
- Markdownファイルはhookが自動でtextlintにかけるので、手動で実行しなくてよい。既存ファイル全体への実行は、ユーザーに頼まれたときだけ行うこと。

## ShellScript

- シェルスクリプトのリンターには `shellcheck` を使用してください。
- `zsh`のリンター時は`shellcheck -s bash`を使用してください。zshには対応していませんが、bashとして解析可能です。
- シェルスクリプトは関数をあまり使用せず、シンプルで手続き型な構造にしてください。
- 関数を使用する場合は、3回以上呼び出されるコードに対してのみ使用してください。
- シェルスクリプト内に他の言語 (Python、JavaScriptなど) のコードをheredocや `-c` でべた書きしないでください。別ファイルのスクリプトにして呼び出してください。

## Skill

- Agent skillを作成・編集するときは、コマンド例を最小限にする。
- コマンド例は、次のいずれかを明確にする場合にだけ追加する。
  - 入力・出力の形式
  - 操作の順序
  - 境界ケース
- 網羅性のためだけに具体例を追加しない。

## Jupyter Notebook

- `.ipynb`の作成・編集・実行には`nb-cli` (`nb`コマンド) を最優先で使う。
- `nb-cli`で行えない操作にだけJupytextを使い、`py:percent`の`.py`を編集してから`.ipynb`へ反映する。未pairedなら`jupytext --to py:percent`で変換し、編集後に`jupytext --to ipynb --update`で出力を残したまま戻す。
- Jupytextのpaired `.py`がある場合も`.ipynb`は`nb-cli`で編集し、編集後に`jupytext --sync <notebook>.ipynb`で`.py`へ反映する。
- 同じNotebookをJupytext、`nb-cli`から同時に書き換えない。
