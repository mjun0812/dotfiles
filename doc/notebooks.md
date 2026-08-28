# Jupyter Notebooks

The dotfiles install three terminal-first notebook workflows:

| Command                      | Backend           | File format                          |
| ---------------------------- | ----------------- | ------------------------------------ |
| `euporie-nb notebook.ipynb`  | Euporie TUI       | Direct `.ipynb` editing              |
| `nvim-ipynb notebook.ipynb`  | `ipynb.nvim`      | Direct `.ipynb` editing              |
| `nvim-molten notebook.ipynb` | Jupytext + Molten | `py:percent` view backed by `.ipynb` |

Euporie is installed as a normal mise-managed CLI tool. The two Neovim
backends are installed together but enabled through separate
`NVIM_NOTEBOOK` profiles so they never register competing `.ipynb` handlers
in the same Neovim process.

Set `NVIM_NOTEBOOK_IMAGES=0` before either Neovim command to disable inline
image rendering over an incompatible SSH or tmux connection.

## Euporie

Run Euporie inside tmux so a dropped SSH connection does not terminate the
notebook session:

```bash
tmux new-session -A -s notebook
euporie-nb notebook.ipynb
```

The checked-in Euporie configuration enables vi editing, OSC52 clipboard
access over SSH, Neovim as the external cell editor, completion, LSP support,
and automatic terminal graphics detection.

## ipynb.nvim

```bash
nvim-ipynb notebook.ipynb
```

Main mappings use the local leader (`\`):

| Mapping | Action                                       |
| ------- | -------------------------------------------- |
| `\ks`   | Start kernel                                 |
| `\rc`   | Execute current cell                         |
| `\rn`   | Execute and move to the next cell            |
| `\rN`   | Execute and insert a cell below              |
| `\rb`   | Execute the current cell and all cells below |
| `\rA`   | Execute all cells                            |
| `\ko`   | Open the current output                      |
| `\ki`   | Interrupt the kernel                         |
| `\kr`   | Restart the kernel                           |
| `\kS`   | Shut down the kernel                         |
| `\kh`   | Inspect the variable under the cursor        |
| `\kv`   | Inspect variables in the current cell        |

The Python bridge always runs from `~/.venv`, where `jupyter_client` is
installed by `install.sh`. The notebook kernelspec controls the environment
in which code is actually executed.

## Jupytext + Molten

```bash
nvim-molten notebook.ipynb
```

The notebook is presented as a Python percent-format buffer. Code cells are
delimited by `# %%`.

| Mapping | Action                                            |
| ------- | ------------------------------------------------- |
| `\mi`   | Select and initialize a kernel                    |
| `\rc`   | Execute the current `# %%` cell                   |
| `\rn`   | Execute the current cell and move to the next one |
| `\rl`   | Execute the current line                          |
| `\rr`   | Re-run the active Molten cell                     |
| `\ro`   | Open the output window                            |
| `\ri`   | Interrupt execution                               |
| `\oi`   | Import outputs from the notebook                  |
| `\oe`   | Export Molten outputs back to the notebook        |
| `\kr`   | Restart the kernel                                |
| `\r`    | Execute the visual selection                      |

Jupytext preserves existing outputs when the buffer is saved. New Molten
outputs are written to the `.ipynb` file only after `\oe`
(`:MoltenExportOutput!`).

## Project kernels

Register a project virtual environment once, then select that kernelspec from
Euporie, ipynb.nvim, or Molten:

```bash
uv venv --allow-existing .venv
uv pip install --python .venv/bin/python ipykernel

kernel_name="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"

.venv/bin/python -m ipykernel install \
    --user \
    --name "$kernel_name" \
    --display-name "Python ($kernel_name)"

jupyter kernelspec list
```

Do not edit the same notebook simultaneously in multiple backends. Use copies
when comparing them, especially while evaluating the alpha-stage
`ipynb.nvim`.
