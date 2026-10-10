#!/usr/bin/env python3

"""agentsview の Filesystem Session Sync 用に、リモートの session を rsync で手元へ取得する。

aliases.zsh の agentsview() が `agentsview serve` の前に実行する。

取得対象は ~/.agentsview/config.toml (git管理外) の [[session_sources]] のうち machine を持つ entry。
machine を ssh の接続先として扱い、agent ごとに決まったリモートのパスを dir へ同期する。
対応する agent は REMOTE_SOURCES のキー。host ごとに必要な agent の entry を書く。

    [[session_sources]]
    agent = "claude"
    dir = "~/.agentsview/remote/devbox1/claude"
    machine = "devbox1"

    [[session_sources]]
    agent = "codex"
    dir = "~/.agentsview/remote/devbox1/codex"
    machine = "devbox1"

接続できない host は警告を出して飛ばす。
"""

from __future__ import annotations

import os
import subprocess
import sys
import tomllib
from pathlib import Path

# agent ごとの、リモートの home からのパスと rsync の filter
REMOTE_SOURCES: dict[str, tuple[str, list[str]]] = {
    "claude": (".claude/projects/", []),
    "codex": (".codex/sessions/", []),
    # ~/.gemini には認証情報もあるため、agentsview が読む session と project 対応表だけを取る
    "gemini": (
        ".gemini/",
        [
            "--include=/projects.json",
            "--include=/trustedFolders.json",
            "--include=/tmp/",
            "--include=/tmp/*/",
            "--include=/tmp/*/chats/",
            "--include=/tmp/*/chats/session-*",
            "--exclude=*",
        ],
    ),
}


def main() -> None:
    """config.toml の machine 付き session_sources を順に rsync で取得する。"""
    data_dir = Path(os.environ.get("AGENTSVIEW_DATA_DIR", Path.home() / ".agentsview"))
    config = data_dir / "config.toml"
    if not config.is_file():
        return
    with config.open("rb") as f:
        sources = tomllib.load(f).get("session_sources", [])

    for source in sources:
        if "machine" not in source:
            continue
        agent, machine = source["agent"], source["machine"]
        if agent not in REMOTE_SOURCES:
            print(
                f"agentsview: unsupported agent '{agent}' for {machine}, skipped",
                file=sys.stderr,
            )
            continue
        remote_path, rsync_filter = REMOTE_SOURCES[agent]
        dest = Path(source["dir"]).expanduser()
        dest.mkdir(parents=True, exist_ok=True)
        print(f"agentsview: {machine}:~/{remote_path} -> {dest}")
        result = subprocess.run(
            [
                "rsync",
                "-a",
                "--delete",
                "--delay-updates",
                "-m",
                "-e",
                "ssh -o ConnectTimeout=10",
                *rsync_filter,
                f"{machine}:{remote_path}",
                f"{dest}/",
            ],
            check=False,
        )
        if result.returncode != 0:
            print(
                f"agentsview: failed to pull {agent} from {machine}, skipped",
                file=sys.stderr,
            )


if __name__ == "__main__":
    main()
