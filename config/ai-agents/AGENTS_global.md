# Global Instructions

常に日本語で応答すること。

## Tools

以下のCLIツールが使用可能：

- fd
- ripgrep
- gh
- bat
- eza
- uvx
- bunx

## Versioning

- バージョン番号を扱う際は Semantic Versioning 2.0.0 に従うこと。

## Git

- コミットメッセージは常に Conventional Commits 形式に従うこと。
- 2行目は必ず空行とし、コミットの説明は3行目から記述すること。
- Gitタグを使用する際は "v1.0.0" や "v2.1.3" の形式を使用すること。

## Post accept plan

Plan modeのplanが承認された後は、planファイルの名前を `YYYY-MM-DD-<short description>.md` の形式に変更すること。
設定でplanファイルの場所が変更されている場合があるので注意すること。

例: `2024-06-15-add-github-issue-create-command.md`

## Python

- 環境およびパッケージ管理には `uv` を使用すること。
- コードのフォーマットとリントには `uvx ruff format` と `uvx ruff check --fix` を使用すること。

### SQLAlchemy

SQLAlchemy ORM は **2.0 スタイル**の記法を使用してください。

```python
# ✅ Good: 2.0 スタイル
from sqlalchemy import select

stmt = select(VectorModel).where(VectorModel.id == model_id)
result = session.execute(stmt).scalar_one_or_none()

# ❌ Bad: 1.x スタイル
result = session.query(VectorModel).filter(VectorModel.id == model_id).first()
```

参考: [SQLAlchemy 2.0 Migration Guide](https://docs.sqlalchemy.org/en/20/changelog/migration_20.html)

### 型ヒント

可能な限り**型ヒント**を記述してください。

```python
# ✅ Good: 型ヒントあり
def get_model_by_id(session: Session, model_id: int) -> VectorModel | None:
    stmt = select(VectorModel).where(VectorModel.id == model_id)
    return session.execute(stmt).scalar_one_or_none()

# ❌ Bad: 型ヒントなし
def get_model_by_id(session, model_id):
    stmt = select(VectorModel).where(VectorModel.id == model_id)
    return session.execute(stmt).scalar_one_or_none()
```

### Docstring

Docstring は **Google スタイル**で記述してください。

参考: [Google Python Style Guide - Docstrings](https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings)

### pytestモックライブラリ

モックには **pytest-mock** を使用し、`unittest.mock` は直接使用しないでください。

```python
# ✅ Good: pytest-mock の mocker fixture を使用
def test_example(mocker):
    mock_func = mocker.patch("module.function")
    mock_func.return_value = "mocked"

# ❌ Bad: unittest.mock を直接使用
from unittest.mock import patch

def test_example():
    with patch("module.function") as mock_func:
        mock_func.return_value = "mocked"
```

理由:

- pytest との統合が優れている
- fixture スコープで自動クリーンアップされる
- テストコードの一貫性を保てる

参考: [pytest-mock documentation](https://pytest-mock.readthedocs.io/)
