#!/usr/bin/env python3

"""agentsview の Filesystem Session Sync 用に、リモートの session を rsync で手元へ取得する。

aliases.zsh の agentsview() が `agentsview serve` の前に実行する。

取得するホストと agent は ~/.agentsview/remotes.toml (git管理外) に書く。
このファイルが無ければ templates/agentsview_remotes.toml の placeholder をコピーし、あれば上書きしない。
agentsview は config.toml を書き換えるときにコメントを消すため、ホストの定義は別ファイルに置く。

    [devbox1]
    agents = ["claude", "codex"]

テーブル名を ssh の接続先として扱い、agent ごとに決まったリモートのパスを
~/.agentsview/remote/<host>/<agent> へ同期する。config.toml に同じ host と agent の
[[session_sources]] が無ければ末尾へ追記し、あればその dir へ同期する。
接続できない host は警告を出して飛ばす。
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / "templates" / "agentsview_remotes.toml"

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
    """remotes.toml のホストから session を rsync で取得し、config.toml へ取得先を登録する。"""
    data_dir = Path(os.environ.get("AGENTSVIEW_DATA_DIR", Path.home() / ".agentsview"))
    remotes_file = data_dir / "remotes.toml"
    if not remotes_file.exists():
        data_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(TEMPLATE, remotes_file)
        print(f"agentsview: created {remotes_file}")
    with remotes_file.open("rb") as f:
        remotes = tomllib.load(f)

    config = data_dir / "config.toml"
    sources = []
    if config.is_file():
        with config.open("rb") as f:
            sources = tomllib.load(f).get("session_sources", [])
    registered = {
        (s["agent"], s.get("machine")): Path(s["dir"]).expanduser() for s in sources
    }

    targets: list[tuple[str, str, Path]] = []
    new_sources: list[tuple[str, str, Path]] = []
    for host, remote in remotes.items():
        for agent in remote.get("agents", []):
            if agent not in REMOTE_SOURCES:
                print(
                    f"agentsview: unsupported agent '{agent}' for {host}, skipped",
                    file=sys.stderr,
                )
                continue
            dest = registered.get((agent, host))
            if dest is None:
                dest = data_dir / "remote" / host / agent
                new_sources.append((host, agent, dest))
            targets.append((host, agent, dest))

    if new_sources:
        # agentsview は既存の config.toml の権限を変えずに cursor_secret などを書き込む
        config.touch(mode=0o600, exist_ok=True)
        with config.open("a") as f:
            for host, agent, dest in new_sources:
                f.write(
                    f"\n[[session_sources]]\nagent = {json.dumps(agent)}\n"
                    f"dir = {json.dumps(str(dest))}\nmachine = {json.dumps(host)}\n"
                )
                print(
                    f"agentsview: added session_sources for {agent} on {host} to {config}"
                )

    for host, agent, dest in targets:
        remote_path, rsync_filter = REMOTE_SOURCES[agent]
        dest.mkdir(parents=True, exist_ok=True)
        print(f"agentsview: {host}:~/{remote_path} -> {dest}")
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
                f"{host}:{remote_path}",
                f"{dest}/",
            ],
            check=False,
        )
        if result.returncode != 0:
            print(
                f"agentsview: failed to pull {agent} from {host}, skipped",
                file=sys.stderr,
            )


if __name__ == "__main__":
    main()
