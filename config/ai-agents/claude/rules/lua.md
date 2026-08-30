---
paths:
  - "**/*.lua"
---

# Lua

- コードのフォーマットには `stylua` を使用すること。
- リポジトリに `.editorconfig` または `stylua.toml` (`.stylua.toml`) がある場合はその設定を優先し、オプションを付けずに実行すること。
- どちらも無い場合は、インデント2スペース・1行120桁をオプションで明示すること。

```bash
# リポジトリに設定がある場合
stylua .
stylua --check .
# リポジトリに設定が無い場合
stylua --indent-type Spaces --indent-width 2 --column-width 120 .
stylua --check --indent-type Spaces --indent-width 2 --column-width 120 .
```
