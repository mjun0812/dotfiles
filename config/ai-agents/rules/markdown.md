---
paths:
  - "**/*.md"
---

# Markdown

- 区切り線 `---` を多用しないこと。節の区切りは見出しで表す。文書の中で性質が大きく変わる境界(例: 現行の手順と旧構成の記録の間)にだけ使う。
- コマンドがbashとzshで異なる場合は、同じコードブロックに `# bash` と `# zsh` のコメントで分けて両方を書くこと。共通の部分は1つにまとめる。

```sh
# bash
read -rs -p "Password: " V && echo
# zsh
read -s "V?Password: " && echo

some-command --password "$V" && unset V
```
