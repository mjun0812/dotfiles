#!/usr/bin/env python3

"""agentsviewのFilesystem Session Sync用に、リモートのsessionをrsyncで手元へ取得する。

aliases.zshのagentsview() が`agentsview serve`の前に実行する。

取得するホストとagentは~/.agentsview/remotes.toml (git管理外) に書く。
このファイルが無ければtemplates/agentsview_remotes.tomlのplaceholderをコピーし、あれば上書きしない。
agentsviewはconfig.tomlを書き換えるときにコメントを消すため、ホストの定義は別ファイルに置く。

    [devbox1]
    agents = ["claude", "codex"]

テーブル名をsshの接続先として扱い、agentごとに決まったリモートのパスを
~/.agentsview/remote/<host>/<agent>へ同期する。config.tomlに同じhostとagentの
[[session_sources]]が無ければ末尾へ追記し、あればそのdirへ同期する。
接続できないhostは警告を出して飛ばす。
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

# agentごとの、リモートのhomeからのパスとrsyncのfilter
REMOTE_SOURCES: dict[str, tuple[str, list[str]]] = {
    "claude": (".claude/projects/", []),
    "codex": (".codex/sessions/", []),
    # ~/.geminiには認証情報もあるため、agentsviewが読むsessionとproject対応表だけを取る
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
    # 認証トークンや実行ファイルを除き、agentsviewが読む会話とproject対応表だけを取る
    "antigravity-cli": (
        ".gemini/antigravity-cli/",
        [
            "--include=/history.jsonl",
            "--include=/cache/",
            "--include=/cache/last_conversations.json",
            "--include=/conversations/***",
            "--include=/implicit/***",
            "--include=/brain/***",
            "--exclude=*",
        ],
    ),
    # auth.jsonやsnapshotを除き、sessionのSQLiteと旧形式のstorageだけを取る
    "opencode": (
        ".local/share/opencode/",
        [
            "--include=/opencode*.db",
            "--include=/opencode*.db-wal",
            "--include=/storage/",
            "--include=/storage/project/***",
            "--include=/storage/session/***",
            "--include=/storage/message/***",
            "--include=/storage/part/***",
            "--exclude=*",
        ],
    ),
    "pi": (".pi/agent/sessions/", []),
}


def main() -> None:
    """remotes.tomlのホストからsessionをrsyncで取得し、config.tomlへ取得先を登録する。"""
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
        # agentsviewは既存のconfig.tomlの権限を変えずにcursor_secretなどを書き込む
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
