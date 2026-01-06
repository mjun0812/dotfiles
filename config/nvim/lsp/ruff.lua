-- Ruff LSP configuration
-- https://docs.astral.sh/ruff/editors/setup/#neovim
return {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "ruff.toml",
    ".ruff.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  },
  settings = {
    -- Ruff language server settings
    -- https://docs.astral.sh/ruff/editors/settings/
  },
}
