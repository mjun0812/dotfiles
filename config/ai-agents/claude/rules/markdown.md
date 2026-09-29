---
paths:
  - "**/*.md"
---

# Markdown

フォマッターに`oxfmt`を使ってください．

```bash
# カレントディレクトリ以下すべてをフォーマット
oxfmt
# ファイル指定
oxfmt [PATH]
```

英数字と日本語の間，および半角括弧 `()` の外側に半角スペースを入れないでください．inline codeの前後には入れて構いません．コードブロックの中は対象外です．

- 良い例: MLflowサーバをECS(arm64)で動かす．`mlflow-server` のrepoを使う．
- 悪い例: MLflow サーバを ECS (arm64) で動かす．

コマンドがbashとzshで異なる場合は，同じコードブロックに `# bash` と `# zsh` のコメントで分けて両方を書いてください．共通の部分は1つにまとめます．

```sh
# bash
read -rs -p "Password: " V && echo
# zsh
read -s "V?Password: " && echo

some-command --password "$V" && unset V
```

区切り線 `---` を多用しないでください．見出しで節を分ければ十分です．文書の中で性質が大きく変わる境界(例: 現行の手順と旧構成の記録の間)にだけ使います．
