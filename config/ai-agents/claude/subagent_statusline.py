#!/usr/bin/env python3
"""Subagent status line: agentパネルの各行に実行モデルを付記する."""

import json
import re
import sys
import time
import unicodedata
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

data = json.load(sys.stdin)

R = "\033[0m"
DIM = "\033[2m"


def find_model(transcript: Path) -> str | None:
    """Transcript内の最初のassistantメッセージからモデルIDを取得する.

    Args:
        transcript: subagentのtranscript(JSONL)のパス。

    Returns:
        モデルID。まだassistantメッセージがない場合はNone。
    """
    try:
        with transcript.open() as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                model = entry.get("message", {}).get("model")
                if model and model != "<synthetic>":
                    return model
    except OSError:
        pass
    return None


def shorten(model_id: str) -> str:
    """モデルIDを表示用の短い名前にする(例: claude-haiku-4-5-20251001 -> haiku-4-5).

    Args:
        model_id: APIのモデルID。

    Returns:
        短縮したモデル名。形式が想定外の場合はそのまま返す。
    """
    m = re.match(r"claude-([a-z]+(?:-\d+)*?)(?:-\d{8})?$", model_id)
    return m.group(1) if m else model_id


def agent_type(meta_path: Path) -> str | None:
    """meta.jsonからagent種別(例: general-purpose)を取得する.

    Args:
        meta_path: subagentのmeta.jsonのパス。

    Returns:
        agent種別。ファイルが無い/読めない場合はNone。
    """
    try:
        return json.loads(meta_path.read_text()).get("agentType")
    except (OSError, json.JSONDecodeError):
        return None


def display_width(text: str) -> int:
    """端末上の表示幅を返す(全角文字は2桁として数える).

    Args:
        text: 対象の文字列(ANSIエスケープを含まないこと)。

    Returns:
        表示幅。
    """
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


def humanize_tokens(count: int) -> str:
    """トークン数を短い表記にする(例: 12345 -> 12.3k).

    Args:
        count: トークン数。

    Returns:
        表示用の文字列。
    """
    if count >= 1000:
        return f"{count / 1000:.1f}k"
    return str(count)


transcript_path = data.get("transcript_path")
session_id = data.get("session_id")
if not transcript_path or not session_id:
    sys.exit(0)

subagents_dir = Path(transcript_path).parent / session_id / "subagents"
columns = data.get("columns") or 80

for task in data.get("tasks", []):
    task_id = task.get("id")
    if not task_id:
        continue
    model = find_model(subagents_dir / f"agent-{task_id}.jsonl")
    if not model:
        continue
    name = task.get("name") or agent_type(subagents_dir / f"agent-{task_id}.meta.json")
    short = shorten(model)
    head_plain = f"{name} [{short}]" if name else f"[{short}]"
    head = f"{name} {DIM}[{short}]{R}" if name else f"{DIM}[{short}]{R}"
    description = task.get("description") or task.get("label")
    left_plain = f"{head_plain}  {description}" if description else head_plain
    content = f"{head}  {description}" if description else head
    right_parts = []
    start_time = task.get("startTime")
    if start_time:
        secs = max(int(time.time() - start_time / 1000), 0)
        right_parts.append(f"{secs // 60}m {secs % 60}s" if secs >= 60 else f"{secs}s")
    token_count = task.get("tokenCount")
    if token_count:
        right_parts.append(f"↓ {humanize_tokens(token_count)} tokens")
    if right_parts:
        right_plain = " · ".join(right_parts)
        pad = max(columns - display_width(left_plain) - display_width(right_plain), 1)
        content += f"{' ' * pad}{DIM}{right_plain}{R}"
    print(json.dumps({"id": task_id, "content": content}, ensure_ascii=False))
