---
paths:
  - "**/*.ipynb"
  - "**/notebooks/**/*.py"
---

# Jupyter Notebook

- `.ipynb`をraw JSONとして編集しない。
- Jupytextのpaired `py:percent` fileがある場合は`.py`をGit上の正本とし、通常の編集は`.py`へ行う。
- JupyterLabを使わないcell-level操作には`nb-cli`のlocal modeを使う。
- live kernel、plot、rich outputを扱う場合は`jupyter-mcp-server`を使う。
- 同じNotebookをJupytext、`nb-cli`、Jupyter MCPから同時に書き換えない。
- Jupyter MCPがactiveな間は`nb connect`、`nb-cli` local write、Jupytext syncを行わない。
- 部分実行だけで完了とせず、最後にfresh kernelで全セルを上から実行する。
- Jupyter KernelはAgentの通常sandboxとは別のcode execution境界として扱う。
