---
paths:
  - "**/*.ipynb"
  - "**/notebooks/**/*.py"
  - "**/notebook/**/*.py"
---

# Jupyter Notebook

- `.ipynb`をraw JSONとして編集しない。
- Jupytextのpaired `py:percent` fileがある場合は`.py`をGit上の正本とし、通常の編集は`.py`へ行う。
- JupyterLabを使わないcell-level操作には`nb-cli`のlocal modeを使う。
- 同じNotebookをJupytext、`nb-cli`から同時に書き換えない。
