---
paths:
  - "**/*.md"
---

# Markdown

コマンドがbashとzshで異なる場合は，同じコードブロックに `# bash` と `# zsh` のコメントで分けて両方を書いてください．共通の部分は1つにまとめます．

```sh
# bash
read -rs -p "Password: " V && echo
# zsh
read -s "V?Password: " && echo

some-command --password "$V" && unset V
```

区切り線 `---` を多用しないでください．見出しで節を分ければ十分です．文書の中で性質が大きく変わる境界(例: 現行の手順と旧構成の記録の間)にだけ使います．
