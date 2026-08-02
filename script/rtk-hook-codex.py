#!/usr/bin/env python3
"""Rewrite safe Codex Bash tool calls through RTK."""

import json
import shlex
import subprocess
import sys
from typing import cast

RTK_TIMEOUT_SECONDS = 3.0
SHELL_PUNCTUATION = frozenset(";&|<>()")
READ_ONLY_COMMANDS = frozenset(
    {
        "cat",
        "du",
        "find",
        "grep",
        "ls",
        "rg",
        "tail",
        "tree",
        "wc",
    }
)
MUTATING_FIND_ARGUMENTS = frozenset(
    {
        "-delete",
        "-exec",
        "-execdir",
        "-fls",
        "-fprint",
        "-fprint0",
        "-fprintf",
        "-ok",
        "-okdir",
    }
)
READ_ONLY_GIT_SUBCOMMANDS = frozenset(
    {
        "blame",
        "diff",
        "grep",
        "log",
        "show",
        "status",
    }
)
UNSAFE_GIT_ARGUMENTS = frozenset({"--ext-diff", "--output", "--textconv"})
READ_ONLY_GH_SUBCOMMANDS = frozenset(
    {
        ("issue", "list"),
        ("issue", "status"),
        ("issue", "view"),
        ("pr", "checks"),
        ("pr", "diff"),
        ("pr", "list"),
        ("pr", "status"),
        ("pr", "view"),
        ("release", "list"),
        ("release", "view"),
        ("repo", "list"),
        ("repo", "view"),
        ("run", "list"),
        ("run", "view"),
        ("run", "watch"),
        ("workflow", "list"),
        ("workflow", "view"),
    }
)


def read_hook_input() -> dict[str, object] | None:
    """Read and validate the hook input from standard input."""
    try:
        value: object = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return None

    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        return None

    return cast(dict[str, object], value)


def extract_bash_input(
    hook_input: dict[str, object],
) -> tuple[str, dict[str, object]] | None:
    """Extract a Codex PreToolUse Bash command and its tool input."""
    if hook_input.get("hook_event_name") != "PreToolUse":
        return None
    if hook_input.get("tool_name") != "Bash":
        return None

    tool_input_value = hook_input.get("tool_input")
    if not isinstance(tool_input_value, dict) or not all(
        isinstance(key, str) for key in tool_input_value
    ):
        return None

    tool_input = cast(dict[str, object], tool_input_value)
    command = tool_input.get("command")
    if not isinstance(command, str) or not command.strip():
        return None

    return command, tool_input


def tokenize_simple_command(command: str) -> list[str] | None:
    """Tokenize a command while rejecting shell composition and substitution."""
    if "\n" in command or "\r" in command:
        return None

    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>()")
        lexer.whitespace_split = True
        lexer.commenters = ""
        tokens = list(lexer)
    except ValueError:
        return None

    if not tokens:
        return None
    if any(token and set(token) <= SHELL_PUNCTUATION for token in tokens):
        return None
    if any("$(" in token or "`" in token for token in tokens):
        return None

    return tokens


def is_safe_command(command: str) -> bool:
    """Return whether a command is safe to rewrite and auto-allow."""
    tokens = tokenize_simple_command(command)
    if tokens is None:
        return False

    executable = tokens[0]
    if executable in READ_ONLY_COMMANDS:
        if executable == "find":
            return not any(
                argument in MUTATING_FIND_ARGUMENTS for argument in tokens[1:]
            )
        return True

    if executable == "git":
        if any(
            argument in UNSAFE_GIT_ARGUMENTS
            or argument.startswith(("--output=", "--open-files-in-pager"))
            for argument in tokens[2:]
        ):
            return False
        return len(tokens) >= 2 and tokens[1] in READ_ONLY_GIT_SUBCOMMANDS

    if executable == "gh":
        if "--web" in tokens[1:]:
            return False
        if len(tokens) >= 2 and tokens[1] == "status":
            return True
        return len(tokens) >= 3 and (tokens[1], tokens[2]) in READ_ONLY_GH_SUBCOMMANDS

    return False


def rewrite_command(command: str) -> str | None:
    """Ask RTK to rewrite a command with a short fail-open timeout."""
    try:
        result = subprocess.run(
            ["rtk", "rewrite", command],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=RTK_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    # RTK may return a non-zero permission status with a valid rewrite on stdout.
    rewritten = result.stdout.strip()
    return rewritten or None


def write_hook_output(tool_input: dict[str, object], command: str) -> None:
    """Write a Codex PreToolUse response containing the rewritten command."""
    updated_input = dict(tool_input)
    updated_input["command"] = command
    output: dict[str, object] = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": updated_input,
        }
    }
    json.dump(output, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


def main() -> int:
    """Run the Codex RTK hook adapter and fail open on errors."""
    hook_input = read_hook_input()
    if hook_input is None:
        return 0

    bash_input = extract_bash_input(hook_input)
    if bash_input is None:
        return 0

    command, tool_input = bash_input
    if not is_safe_command(command):
        return 0

    rewritten = rewrite_command(command)
    if rewritten is None or rewritten == command:
        return 0

    write_hook_output(tool_input, rewritten)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
