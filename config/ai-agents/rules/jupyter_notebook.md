---
paths:
  - "**/*.ipynb"
  - "**/notebooks/**/*.py"
  - "**/notebook/**/*.py"
---

# Jupyter Notebook

- `.ipynb`の作成・編集・実行には`nb-cli`(`nb`コマンド)を最優先で使う。
- `nb-cli`で行えない操作にだけJupytextを使い、`py:percent`の`.py`を編集してから`.ipynb`へ反映する。未pairedなら`jupytext --to py:percent`で変換し、編集後に`jupytext --to ipynb --update`で出力を残したまま戻す。
- Jupytextのpaired `.py`がある場合も`.ipynb`は`nb-cli`で編集し、編集後に`jupytext --sync <notebook>.ipynb`で`.py`へ反映する。
- 同じNotebookをJupytext、`nb-cli`から同時に書き換えない。
