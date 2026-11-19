#!/usr/bin/env python3

"""Run ccusage with local and AgentsView remote session logs."""

import os
import subprocess
import sys
import tempfile
import tomllib
from collections import defaultdict
from pathlib import Path

REMOTE_ROOTS = {
    "claude": ("CLAUDE_CONFIG_DIR", ""),
    "codex": ("CODEX_HOME", ""),
    "gemini": ("GEMINI_DATA_DIR", "tmp"),
    "antigravity-cli": ("ANTIGRAVITY_DATA_DIR", "conversations"),
    "opencode": ("OPENCODE_DATA_DIR", ""),
    "pi": ("PI_AGENT_DIR", ""),
}


def main() -> int:
    """Add synced session paths for this invocation and forward CLI arguments."""
    home = Path.home()
    agentsview_dir = Path(os.environ.get("AGENTSVIEW_DATA_DIR", home / ".agentsview"))
    config = agentsview_dir / "config.toml"
    try:
        with config.open("rb") as file:
            sources = tomllib.load(file).get("session_sources", [])
    except FileNotFoundError:
        sources = []

    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    data_home = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    local_paths = {
        "CLAUDE_CONFIG_DIR": [config_home / "claude", home / ".claude"],
        "CODEX_HOME": [home / ".codex"],
        "GEMINI_DATA_DIR": [home / ".gemini/tmp"],
        "ANTIGRAVITY_DATA_DIR": [
            home / ".gemini" / profile / "conversations"
            for profile in (
                "antigravity",
                "antigravity-cli",
                "antigravity-ide",
                "antigravity-backup",
                "antigravity-acp",
            )
        ]
        + [home / ".config/antigravity/conversations"],
        "OPENCODE_DATA_DIR": [data_home / "opencode"],
        "PI_AGENT_DIR": [home / ".pi/agent/sessions"],
    }

    with tempfile.TemporaryDirectory(prefix="ccusage-all-") as temporary_dir:
        remote_paths: dict[str, list[str]] = defaultdict(list)
        for index, source in enumerate(sources):
            agent = source["agent"]
            if not source.get("machine") or agent not in REMOTE_ROOTS:
                continue
            variable, relative_path = REMOTE_ROOTS[agent]
            path = Path(source["dir"]).expanduser().absolute() / relative_path
            if not path.is_dir():
                continue
            if agent == "claude" and path.name != "projects":
                # rsync copies the contents of projects/, which ccusage expects by name.
                claude_root = Path(temporary_dir) / str(index)
                claude_root.mkdir()
                (claude_root / "projects").symlink_to(path, target_is_directory=True)
                path = claude_root
            remote_paths[variable].append(str(path))

        env = os.environ.copy()
        for variable, paths in remote_paths.items():
            local = env.get(variable, ",".join(map(str, local_paths[variable])))
            env[variable] = ",".join(filter(None, [local, *paths]))
        return subprocess.run(
            ["ccusage", *sys.argv[1:]], env=env, check=False
        ).returncode


if __name__ == "__main__":
    sys.exit(main())
