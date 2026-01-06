-- ty LSP configuration
-- https://github.com/astral-sh/ty
return {
  cmd = { "ty", "server" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "ty.toml",
    ".ty.toml",
    "setup.py",
    "setup.cfg",
    ".git",
  },
  settings = {
    -- ty language server settings
  },
}
