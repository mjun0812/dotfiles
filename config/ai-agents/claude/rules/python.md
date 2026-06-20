---
paths:
  - "**/*.py"
---

# Python

- 環境およびパッケージ管理には `uv` を使用すること。
- コードのフォーマットには `uvx ruff format`を使ってください．
- コードのリンターには`uvx ruff check --fix` を使用すること。
- コードの型チェックには`uvx ty check` を使用すること。

## f-string

文字列リテラルに変数を埋め込むときは，f-stringを使ってください．

```python
# Good
log.info(f"Info: {info}")
# Bad1
log.info("Info: {}".format(info))
# Bad2
log.info("Info: %s" % (info))
```

## SQLAlchemy

SQLAlchemy ORM は **2.0 スタイル**の記法を使用してください。

```python
# Good: 2.0 スタイル
from sqlalchemy import select

stmt = select(VectorModel).where(VectorModel.id == model_id)
result = session.execute(stmt).scalar_one_or_none()

# Bad: 1.x スタイル
result = session.query(VectorModel).filter(VectorModel.id == model_id).first()
```

## 型ヒント

**型ヒント**を必ず記述してください。Anyの使用は避け、具体的な型を指定してください。

```python
# Good: 型ヒントあり
def get_model_by_id(session: Session, model_id: int) -> VectorModel | None:
    stmt = select(VectorModel).where(VectorModel.id == model_id)
    return session.execute(stmt).scalar_one_or_none()

# Bad: 型ヒントなし
def get_model_by_id(session, model_id):
    stmt = select(VectorModel).where(VectorModel.id == model_id)
    return session.execute(stmt).scalar_one_or_none()
```

## Docstring

全ての関数やクラスにDocstringを記述してください．
記述スタイルは**Google スタイル**で記述してください。

## pytestモックライブラリ

モックには **pytest-mock** を使用し、`unittest.mock` は直接使用しないでください。

```python
# Good: pytest-mock の mocker fixture を使用
def test_example(mocker):
    mock_func = mocker.patch("module.function")
    mock_func.return_value = "mocked"

# Bad: unittest.mock を直接使用
from unittest.mock import patch

def test_example():
    with patch("module.function") as mock_func:
        mock_func.return_value = "mocked"
```
