"""Render the Codex terminal footer over stdio MCP."""

import json
import os
import subprocess
import sys
from typing import Any

URI = "ui://dotfiles-statusline/footer"
TOOL = {
    "name": "statusline",
    "title": "Dotfiles status line",
    "description": "Show the current model, usage, and workspace in the Codex footer.",
    "inputSchema": {"type": "object", "properties": {}},
    "_meta": {
        "openai/ui": {"entrypoints": [{"type": "statusline", "resourceUri": URI}]}
    },
}
# Codex softens the built-in footer's Catppuccin Mocha colors; MCP theme roles use raw colors.
MODEL_COLOR = "#f6e2b7"
USAGE_COLOR = "#f2b590"
LIMIT_COLOR = "#e990a9"
PATH_COLOR = "#abdfa7"
BRANCH_COLOR = "#8fb3ef"
MODE_COLOR = "#c8a9ee"
# Codex trims ordinary spaces at the edges of text nodes, including bar padding.
BRAILLE = "\N{BRAILLE PATTERN BLANK}⣀⣄⣤⣦⣶⣷⣿"
Leaf = str | dict[str, object]


def _main() -> None:
    for line in sys.stdin.buffer:
        reply: dict[str, object] = {"jsonrpc": "2.0", "id": None}
        try:
            request = json.loads(line)
            if "id" not in request:
                continue
            reply["id"] = request["id"]
            reply["result"] = _respond(request["method"], request.get("params", {}))
        except json.JSONDecodeError:
            reply["error"] = {"code": -32700, "message": "Parse error"}
        except KeyError:
            reply["error"] = {"code": -32601, "message": "Method not found"}
        except (TypeError, ValueError, AttributeError):
            reply["error"] = {"code": -32602, "message": "Invalid parameters"}
        print(json.dumps(reply), flush=True)


def _respond(method: str, params: dict[str, Any]) -> dict[str, object]:
    if method == "initialize":
        return {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}, "resources": {}},
            "serverInfo": {"name": "dotfiles-statusline", "version": "1.0"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        if params.get("name") != TOOL["name"]:
            raise ValueError("Unknown tool name")
        return {"content": [{"type": "text", "text": f"Footer resource: {URI}"}]}
    if method == "resources/list":
        return {
            "resources": [
                {"name": "footer", "uri": URI, "mimeType": "application/json"}
            ]
        }
    if method == "resources/templates/list":
        return {"resourceTemplates": []}
    if method == "resources/read":
        if params.get("uri") != URI:
            raise ValueError("Unknown resource URI")
        state = params.get("_meta", {}).get("com.openai/codex-statusline-state", {})
        return {
            "contents": [
                {
                    "uri": URI,
                    "mimeType": "application/json",
                    "text": json.dumps(_render(state), ensure_ascii=False),
                }
            ]
        }
    raise KeyError(method)


def _render(state: dict[str, Any]) -> dict[str, object]:
    thread = state.get("thread", {})
    model = thread.get("model", {})
    model_label = model.get("display_name", "Codex")
    if effort := model.get("reasoning_level"):
        model_label += f" {effort}"
    if (service_tier := model.get("service_tier")) in ("fast", "ultrafast"):
        model_label += f" {service_tier}"

    context = thread.get("usage", {}).get("context", {})
    groups: list[Leaf] = [
        _colored(model_label, MODEL_COLOR),
        _usage(
            "ctx",
            context.get("used_percentage", 0),
            USAGE_COLOR,
            context.get("used_tokens", 0),
        ),
    ]
    limits = state.get("account", {}).get("rate_limits", [])
    if limits:
        windows = {
            window["window_minutes"]: window["used_percent"]
            for window in (limits[0]["primary_limit"], limits[0]["secondary_limit"])
            if window is not None
        }
        for minutes, label in ((5 * 60, "5h"), (7 * 24 * 60, "7d")):
            if minutes in windows:
                groups.append(_usage(label, windows[minutes], LIMIT_COLOR))

    if cwd := thread.get("workspace", {}).get("cwd"):
        groups.append(_colored(f" {_short_path(cwd)}", PATH_COLOR))
        if branch := _git_branch(cwd):
            groups.append(_colored(f" {branch}", BRANCH_COLOR))

    if permissions := thread.get("permissions"):
        permission_label = permissions["display_name"]
        if (
            permissions["type"] == "disabled"
            and thread.get("approval", {}).get("policy") == "never"
        ):
            permission_label = "YOLO"
        groups.append(_colored(permission_label, MODE_COLOR))

    children = [groups[0]]
    for group in groups[1:]:
        children.append("│")
        children.append(group)
    return _row(children)


def _usage(
    label: str, pct: float, text_color: str, used_tokens: int | None = None
) -> dict[str, object]:
    bounded = min(max(pct, 0), 100)
    if bounded < 50:
        color = f"#{int(bounded * 5.1):02x}c850"
    else:
        color = f"#ff{int(200 - (bounded - 50) * 4):02x}3c"

    filled = bounded * 6 / 100
    bar = "".join(BRAILLE[int(min(max(filled - i, 0), 1) * 7)] for i in range(6))
    usage = f"{round(pct)}%"
    if used_tokens is not None:
        usage += f" {_format_token_count(used_tokens)}"
    return _row(
        [
            _colored(label, text_color),
            _colored(bar, color),
            _colored(usage, text_color),
        ]
    )


def _format_token_count(tokens: int) -> str:
    # Promote values that would round to 1000.0 in the smaller unit.
    if tokens >= 999_950_000:
        return f"{tokens / 1_000_000_000:.1f}b"
    if tokens >= 999_950:
        return f"{tokens / 1_000_000:.1f}m"
    if tokens >= 1_000:
        return f"{tokens / 1_000:.1f}k"
    return str(tokens)


def _row(children: list[Leaf]) -> dict[str, object]:
    return {"type": "row", "props": {"gap": 1}, "children": children}


def _colored(value: str, color: str) -> dict[str, object]:
    return {"type": "text", "props": {"color": color}, "children": [value]}


def _short_path(path: str, max_len: int = 30) -> str:
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
    shortened = os.sep.join([head] + [p[:1] for p in parts[1:-1] if p] + [tail])
    if len(shortened) <= max_len:
        return shortened
    return tail or path


def _git_branch(cwd: str) -> str | None:
    try:
        for args in (
            ("symbolic-ref", "-q", "--short", "HEAD"),
            ("rev-parse", "--short", "HEAD"),
        ):
            result = subprocess.run(
                ["git", *args],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=0.25,
                check=False,
            )
            if result.returncode == 0:
                return result.stdout.strip()
            if result.returncode != 1:
                break
    except (subprocess.SubprocessError, OSError):
        pass
    return None


if __name__ == "__main__":
    _main()
