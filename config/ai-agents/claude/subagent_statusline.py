#!/usr/bin/env python3
"""Subagent status line: agentパネルの各行に実行モデルを付記する."""

import json
import re
import sys
import time
from pathlib import Path

data = json.load(sys.stdin)

R = "\033[0m"
DIM = "\033[2m"


def find_model(transcript: Path) -> str | None:
    """Transcript内の最初のassistantメッセージからモデルIDを取得する(無ければNone)."""
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
    """モデルIDを表示用の短い名前にする(例: claude-haiku-4-5-20251001 -> haiku-4-5)."""
    m = re.match(r"claude-([a-z]+(?:-\d+)*?)(?:-\d{8})?$", model_id)
    return m.group(1) if m else model_id


def agent_type(meta_path: Path) -> str | None:
    """meta.jsonからagent種別(例: general-purpose)を取得する(読めなければNone)."""
    try:
        return json.loads(meta_path.read_text()).get("agentType")
    except (OSError, json.JSONDecodeError):
        return None


def humanize_tokens(count: int) -> str:
    """トークン数を短い表記にする(例: 12345 -> 12.3k)."""
    if count >= 1000:
        return f"{count / 1000:.1f}k"
    return str(count)


transcript_path = data.get("transcript_path")
session_id = data.get("session_id")
if not transcript_path or not session_id:
    sys.exit(0)

subagents_dir = Path(transcript_path).parent / session_id / "subagents"

for task in data.get("tasks", []):
    task_id = task.get("id")
    if not task_id:
        continue
    model = find_model(subagents_dir / f"agent-{task_id}.jsonl")
    if not model:
        continue
    name = task.get("name") or agent_type(subagents_dir / f"agent-{task_id}.meta.json")
    short = shorten(model)
    head = f"{name} {DIM}[{short}]{R}" if name else f"{DIM}[{short}]{R}"
    description = task.get("description") or task.get("label")
    content = f"{head}  {description}" if description else head
    right_parts = []
    start_time = task.get("startTime")
    if start_time:
        secs = max(int(time.time() - start_time / 1000), 0)
        right_parts.append(f"{secs // 60}m {secs % 60}s" if secs >= 60 else f"{secs}s")
    token_count = task.get("tokenCount")
    if token_count:
        right_parts.append(f"{humanize_tokens(token_count)} tokens")
    if right_parts:
        content += f" {DIM}· {' · '.join(right_parts)}{R}"
    print(json.dumps({"id": task_id, "content": content}, ensure_ascii=False))
