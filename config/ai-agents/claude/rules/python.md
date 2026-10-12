---
paths:
  - "**/*.py"
---

# Python

- 環境およびパッケージ管理には `uv` を使用すること。
- コードのフォーマットには `uvx ruff format`を使ってください．
- コードのリンターには`uvx ruff check --fix` を使用すること。
- コードの型チェックには`uvx ty check` を使用すること。
- SQLAlchemy ORM は **2.0 スタイル**の記法を使用してください。
