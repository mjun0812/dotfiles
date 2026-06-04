#!/usr/bin/env python3
"""Pattern 5: Braille dots - dotted progress bar using braille characters"""

import json
import os
import subprocess
import sys

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

data = json.load(sys.stdin)

BRAILLE = " ⣀⣄⣤⣦⣶⣷⣿"
R = "\033[0m"
DIM = "\033[2m"


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


def git_branch(cwd):
    try:
        result = subprocess.run(
            ["git", "symbolic-ref", "--short", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=1,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=1,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.SubprocessError, OSError):
        pass
    return None


model = data.get("model", {}).get("display_name", "Claude")
effort = data.get("effort", {}).get("level")
parts = [f"{model} {effort}" if effort else model]

ctx = data.get("context_window", {}).get("used_percentage", 0)
parts.append(fmt("ctx", ctx))

five = data.get("rate_limits", {}).get("five_hour", {}).get("used_percentage")
if five is not None:
    parts.append(fmt("5h", five))

week = data.get("rate_limits", {}).get("seven_day", {}).get("used_percentage")
if week is not None:
    parts.append(fmt("7d", week))

cwd = data.get("workspace", {}).get("current_dir") or data.get("cwd")
if cwd:
    parts.append(f"{DIM}{R} {short_path(cwd)}")
    branch = git_branch(cwd)
    if branch:
        parts.append(f"{DIM}{R} {branch}")

print(f" {DIM}│{R} ".join(parts), end="")
