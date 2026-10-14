# Personal textlint

textlint and its rules are installed together by the `npm:textlint` entry in
`config/dot_config/mise/config.toml`. The `bun_args` option adds the rules to the
same installation as the CLI, so they remain resolvable outside this repository.
This requires mise 2026.4.27 or newer and `npm.package_manager = "bun"`.
Do not register each rule as a separate `npm:` tool: separate prefixes do not
make their modules available to textlint automatically.

## Install or migrate

From the dotfiles checkout:

```sh
mise install npm:textlint
mise reshim
zsh script/setup/setup_textlint.sh
```

The full `install.sh` also performs these steps. The setup script removes only
`~/.local/bin/textlint` links pointing at this checkout's former
`config/textlint/node_modules/.bin/textlint`, including dangling links. It leaves
unrelated executables and symlinks alone. An unrelated command earlier on PATH
can still shadow mise's CLI; inspect `command -v textlint` and `mise which textlint`.
The old `config/textlint/node_modules` directory is no longer used and is not
removed automatically.

`~/.textlintrc.js` still combines the fix and report configurations. It is found
when running `textlint` from a directory below HOME without a nearer project
configuration. Project configurations retain precedence. The file being checked
can be outside HOME. Do not pass this JavaScript configuration to `--config`;
use the JSON profiles through the wrapper for explicit configuration selection.

```sh
textlint document.md
printf '%s\n' '日本語の本文です。' | textlint --stdin --stdin-filename body.md

# Agent hooks use these explicit profiles from any working directory.
~/.dotfiles/script/tools/textlint.sh fix --fix document.md
~/.dotfiles/script/tools/textlint.sh report --format json document.md
```

The wrapper resolves mise's installation from the dotfiles checkout, rather than
from the calling project. Both profiles and `prh.yml` keep their existing rules.
Changing the package-manager backend also requires adapting the wrapper's
`bin/textlint` and `node_modules` paths and the installation arguments.

## Update

```sh
# Update the CLI following the configured "latest" selector.
mise upgrade npm:textlint

# After editing the pinned rule versions in bun_args, reinstall the bundle.
mise install --force npm:textlint
```

Rules in `bun_args` are installation arguments, not separately tracked mise
tools. `mise upgrade` does not bump their pinned versions. The migration preserves
the four direct rule versions from the former `bun.lock`; transitive dependencies
are no longer frozen by a repository lockfile. This is a personal global-tool
setup, not a fully locked project dependency graph. Installation stays outside
agent hooks; ordinary lint invocations do not install or update packages.

## Verify

With mise, Node.js, Bun, zsh and Python 3.11+ available:

```sh
python script/tests/test_textlint_mise.py
```

The integration tests download packages into a temporary mise data directory and
use a temporary HOME. They never run the full dotfiles installer or modify the
real HOME. GitHub Actions runs them on Ubuntu and macOS.
