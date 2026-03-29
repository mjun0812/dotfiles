# Global Instructions

- 常に日本語で応答すること。
- 語尾が「?」や疑問形の場合には回答のみを行い、編集を行わないこと。

## Versioning

- バージョン番号を扱う際は Semantic Versioning 2.0.0 に従うこと。

## Git

- コミットメッセージは常に Conventional Commits 形式に従うこと。
- 2行目は必ず空行とし、コミットの説明は3行目から記述すること。
- Gitタグを使用する際は "v1.0.0" や "v2.1.3" といったSemantic Versioningの形式を使用すること。
- コミットメッセージは変更内容を具体的に記述すること。「レビュー対応」「修正」「更新」のような曖昧な表現は禁止。何を・なぜ変更したかが分かるメッセージにすること。

## Post accept plan

Plan modeのplanファイルはPostToolUse hookにより自動的に `YYYY-MM-DD-<english-slug>.md` 形式にリネームされる。
自動リネームが失敗した場合は、手動でリネームすること。
設定でplanファイルの場所が変更されている場合があるので注意すること。

例: `2024-06-15-add-github-issue-create-command.md`

## Python

- 環境およびパッケージ管理には `uv` を使用すること。
- コードのフォーマットには `uvx ruff format`を使ってください．
- コードのリンターには`uvx ruff check --fix` を使用すること。
- コードの型チェックには`uvx ty check` を使用すること。

### f-string

文字列リテラルに変数を埋め込むときは，f-stringを使ってください．

```python
# Good
log.info(f"Info: {info}")
# Bad1
log.info("Info: {}".format(info))
# Bad2
log.info("Info: %s" % (info))
```

### SQLAlchemy

SQLAlchemy ORM は **2.0 スタイル**の記法を使用してください。

```python
# Good: 2.0 スタイル
from sqlalchemy import select

stmt = select(VectorModel).where(VectorModel.id == model_id)
result = session.execute(stmt).scalar_one_or_none()

# Bad: 1.x スタイル
result = session.query(VectorModel).filter(VectorModel.id == model_id).first()
```

### 型ヒント

可能な限り**型ヒント**を記述してください。

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

### Docstring

全ての関数やクラスにDocstringを記述してください．
記述スタイルは**Google スタイル**で記述してください。

### pytestモックライブラリ

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

## Markdown

フォマッターに`oxfmt`を使ってください．

```bash
# カレントディレクトリ以下すべてをフォーマット
oxfmt
# ファイル指定
oxfmt [PATH]
```

