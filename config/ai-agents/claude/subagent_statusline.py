#!/usr/bin/env python3
"""Subagent status line: agentパネルの各行をメインのstatus lineと同じ表記で描画する."""

import json
import os
import re
import sys
import time

data = json.load(sys.stdin)

BRAILLE = " ⣀⣄⣤⣦⣶⣷⣿"
R = "\033[0m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
RED = "\033[31m"
SEP = f" {DIM}│{R} "

STATUS_GLYPHS = {
    "running": f"{CYAN}●{R}",
    "completed": f"{GREEN}✓{R}",
    "failed": f"{RED}✗{R}",
}


def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f"\033[38;2;{r};200;80m"
    else:
        g = int(200 - (pct - 50) * 4)
        return f"\033[38;2;255;{max(g, 0)};60m"


def braille_bar(pct, width=6):
    pct = min(max(pct, 0), 100)
    level = pct / 100
    bar = ""
    for i in range(width):
        seg_start = i / width
        seg_end = (i + 1) / width
        if level >= seg_end:
            bar += BRAILLE[7]
        elif level <= seg_start:
            bar += BRAILLE[0]
        else:
            frac = (level - seg_start) / (seg_end - seg_start)
            bar += BRAILLE[min(int(frac * 7), 7)]
    return bar


def fmt(label, pct):
    p = round(pct)
    return f"{DIM}{label}{R} {gradient(pct)}{braille_bar(pct)}{R} {p}%"


def short_path(path, max_len=30):
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        path = "~" + path[len(home) :]
    if len(path) <= max_len:
        return path
    parts = path.split(os.sep)
    if len(parts) <= 2:
        return os.path.basename(path) or path
    head, tail = parts[0], parts[-1]
    shortened = os.sep.join(
        [head] + [p[:1] for p in parts[1:-1] if p] + [tail]
    )
    if len(shortened) <= max_len:
        return shortened
    return tail or path


def shorten(model_id: str) -> str:
    """モデルIDを表示用の短い名前にする(例: claude-haiku-4-5-20251001 -> haiku-4-5, claude-opus-5-5[1m] -> opus-5-5[1m])."""
    m = re.match(r"claude-([a-z]+(?:-\d+)*?)(?:-\d{8})?(\[\w+\])?$", model_id)
    return m.group(1) + (m.group(2) or "") if m else model_id


def humanize_tokens(count: int) -> str:
    """トークン数を短い表記にする(例: 12345 -> 12.3k)."""
    if count >= 1000:
        return f"{count / 1000:.1f}k"
    return str(count)


for task in data.get("tasks") or []:
    task_id = task.get("id")
    model = task.get("model")
    if not task_id or not model:
        continue
    # effortはlevel文字列か数値のトークン予算で、未指定なら項目自体が無い
    effort = task.get("effort")
    if isinstance(effort, int):
        effort = humanize_tokens(effort)
    model_label = f"{shorten(model)} {effort}" if effort else shorten(model)
    name = task.get("name") or task.get("type")
    head = f"{name} {DIM}[{model_label}]{R}" if name else f"{DIM}[{model_label}]{R}"
    glyph = STATUS_GLYPHS.get(task.get("status"))
    if glyph:
        head = f"{glyph} {head}"
    description = task.get("description") or task.get("label")
    parts = [f"{head}  {description}" if description else head]

    token_count = task.get("tokenCount") or 0
    window = task.get("contextWindowSize")
    if window:
        parts.append(fmt("ctx", token_count / window * 100))

    cwd = task.get("cwd")
    if cwd:
        parts.append(f"{DIM}{R} {short_path(cwd)}")

    right_parts = []
    start_time = task.get("startTime")
    if start_time:
        secs = max(int(time.time() - start_time / 1000), 0)
        right_parts.append(f"{secs // 60}m {secs % 60}s" if secs >= 60 else f"{secs}s")
    if token_count:
        right_parts.append(f"{humanize_tokens(token_count)} tokens")
    if right_parts:
        parts.append(f"{DIM}{' · '.join(right_parts)}{R}")

    print(json.dumps({"id": task_id, "content": SEP.join(parts)}, ensure_ascii=False))
