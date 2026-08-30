# Jupyter Notebooks

The dotfiles install Euporie as the terminal notebook frontend. Euporie is
installed in an isolated pipx environment managed by mise.

## Euporie

Run Euporie inside tmux so a dropped SSH connection does not terminate the
notebook session:

```bash
tmux new-session -A -s notebook
euporie-nb notebook.ipynb
```

The checked-in Euporie configuration enables vi editing, OSC52 clipboard
access over SSH, Neovim as the external cell editor, automatic completion,
smart suggestions, contextual help, relative line numbers, LSP support through
`pylsp`, and control over automatic formatting and execution after external
editing.

Euporie also offers a `Local Python` kernel. This kernel runs code inside the
Python process which launched Euporie instead of starting a separate Jupyter
kernel. With the mise installation, its interpreter is located under:

```text
~/.local/share/mise/installs/pipx-euporie/<version>/euporie/bin/python
```

An active `VIRTUAL_ENV` lets `Local Python` add that environment's
`site-packages`, but it does not switch to the environment's Python
interpreter. Use a registered project kernel when notebook code depends on the
environment created by `uv sync`.

`install.sh` installs `ipykernel` into `~/.venv` and registers it as the user
kernelspec `home-venv`, displayed as `Python (~/.venv)`. This shared kernel is
available to Euporie regardless of the current project, but it does not include
dependencies installed into a project's `.venv`.

## Project kernels

`uv sync` creates or updates the project `.venv`, but it does not register that
environment as a Jupyter kernel. The project environment must contain
`ipykernel` before running the registration command.

Register the virtual environment once from the project root, then select that
kernelspec from Euporie:

```bash
kernel_name="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-')"

uv run ipython kernel install \
    --user \
    --name "$kernel_name" \
    --display-name "Python ($kernel_name)" \
    --env VIRTUAL_ENV "$PWD/.venv"

uv run jupyter kernelspec list
```

For an existing notebook, open Euporie's command palette with `Ctrl+Space`,
run `Change kernel`, and select `Python (<kernel-name>)`. For a new notebook,
the kernelspec name can also be passed on the command line:

```bash
euporie-nb --kernel project-name notebook.ipynb
```

Confirm the interpreter from a notebook cell after selecting the kernel:

```python
import sys

print(sys.executable)
```

The output should point to the project's `.venv/bin/python`, not the Euporie
pipx environment.
