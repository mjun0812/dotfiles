#!/usr/bin/env python3
"""Subagent status line: agentパネルの各行に実行モデルを付記する."""

import json
import re
import sys
import time

data = json.load(sys.stdin)

R = "\033[0m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"

STATUS_GLYPHS = {
    "running": f"{CYAN}●{R}",
    "completed": f"{GREEN}✓{R}",
    "failed": f"{RED}✗{R}",
}


def shorten(model_id: str) -> str:
    """モデルIDを表示用の短い名前にする(例: claude-haiku-4-5-20251001 -> haiku-4-5)."""
    m = re.match(r"claude-([a-z]+(?:-\d+)*?)(?:-\d{8})?$", model_id)
    return m.group(1) if m else model_id


def humanize_tokens(count: int) -> str:
    """トークン数を短い表記にする(例: 12345 -> 12.3k)."""
    if count >= 1000:
        return f"{count / 1000:.1f}k"
    return str(count)


for task in data.get("tasks", []):
    task_id = task.get("id")
    model = task.get("model")
    if not task_id or not model:
        continue
    name = task.get("name") or task.get("type")
    short = shorten(model)
    head = f"{name} {DIM}[{short}]{R}" if name else f"{DIM}[{short}]{R}"
    glyph = STATUS_GLYPHS.get(task.get("status"))
    if glyph:
        head = f"{glyph} {head}"
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
