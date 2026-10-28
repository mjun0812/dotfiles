#!/usr/bin/env python3
"""dotfiles の更新に local 環境が追従しているかを調べ、機械的に分かるずれを列挙する。

check (既定): ずれを [分類] 付きで1行ずつ表示する。ずれがあれば exit 1
mark: 確認を終えた commit (HEAD) を記録する。次回の check は、それ以降の commit を表示する

ずれをどう直すかは判断が要るため、このscriptは何も変更しない。
直し方の基準は .agents/skills/doctor/SKILL.md にある。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import tomllib
from collections.abc import Iterator
from pathlib import Path

DOTPATH = Path(__file__).resolve().parents[2]
HOME = Path.home()
STATE_FILE = (
    Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
    / "dotfiles/doctor-last-sync"
)
CODEX_TEMPLATE = "config/ai-agents/codex/config.toml"
APM_LOCK = HOME / ".apm/apm.lock.yaml"
# Codex が書くローカル状態で、テンプレートの管理外 (テンプレートには書かない)
CODEX_LOCAL_STATE_TABLES = frozenset({"desktop", "projects"})
# /model などlocalで選んだ値を mise dot apply のマージに上書きさせないため、テンプレートから外したキー。
# 値が昔のテンプレートと同じでも、消し忘れではない
CODEX_LOCAL_CHOICE_KEYS = frozenset({"model", "model_reasoning_effort", "service_tier"})
# apm が展開するskill・agentの置き場。dotfiles 自身のsymlinkも同じ場所に置かれる
SKILL_DIRS = (".agents/skills", ".claude/skills", ".gemini/antigravity-cli/skills")
AGENT_DIRS = (".claude/agents", ".codex/agents")
# 深い階層まで辿ると時間がかかるので、dotfiles がsymlinkを置く深さに限る
DANGLING_SCAN_DEPTH = 3
DANGLING_SCAN_SKIP = frozenset(
    {".cache", ".git", "node_modules", ".npm", ".bun", ".rustup", ".cargo", "go"}
)


def main() -> int:
    """ずれを表示するか、確認したcommitを記録する。"""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "command", nargs="?", choices=("check", "mark"), default="check"
    )
    args = parser.parse_args()

    if args.command == "mark":
        head = git("rev-parse", "HEAD")
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(head + "\n")
        print(f"{head[:7]} を確認済みとして {STATE_FILE} に記録した")
        return 0

    print_commits()
    findings = [
        *check_expected_links(),
        *check_dangling_links(),
        *check_mise(),
        *check_textlint(),
        *check_apm(),
        *check_codex_hooks(),
        *check_codex_stale_keys(),
    ]
    print("\n## ずれ")
    for finding in findings:
        print(finding)
    if not findings:
        print("なし")
    return 1 if findings else 0


def git(*args: str) -> str:
    """dotfilesのrepoでgitを実行し、標準出力を返す。"""
    return subprocess.run(
        ["git", "-C", str(DOTPATH), *args], capture_output=True, text=True, check=True
    ).stdout.strip()


def print_commits() -> None:
    """前回の確認以降のcommitと、変更されたファイルを表示する。"""
    last = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    if last:
        print(f"## 前回の確認 ({last[:7]}) 以降のcommit")
        revision = [f"{last}..HEAD"]
    else:
        print("## 確認したcommitの記録が無いため、直近2週間のcommit")
        revision = [f"{git('rev-list', '-1', '--before=2.weeks', 'HEAD')}..HEAD"]
    print(
        git("log", "--no-merges", "--format=%h %ad %s", "--date=short", *revision)
        or "なし"
    )
    print("\n## 変更されたファイル")
    print(git("diff", "--name-status", *revision) or "なし")


def check_expected_links() -> Iterator[str]:
    """宣言どおりに展開されていないものと、setupスクリプトが張るはずのsymlinkが無いものを探す。"""
    # conf.d/dotfiles.toml の宣言は、mise の判定に任せる
    status = json.loads(
        subprocess.run(
            ["mise", "dot", "status", "--json"],
            cwd=HOME,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    )
    for entry in status["files"]:
        if entry["state"] not in ("applied", "tracked"):
            reason = f" ({entry['reason']})" if "reason" in entry else ""
            yield f"[dotfiles-unapplied] {entry['target']} が {entry['state']}{reason}"
    for entry in status["edits"]:
        if entry["state"] != "applied":
            yield f"[dotfiles-unapplied] {entry['path']} の {entry['edit']} が {entry['state']}"

    for source, target in script_links():
        if not source.exists():
            continue
        if not (target.is_symlink() and target.resolve() == source.resolve()):
            yield f"[symlink-missing] {target} が {source} を指していない"


def script_links() -> Iterator[tuple[Path, Path]]:
    """Setupスクリプトが張るsymlinkの、dotfilesのファイルと展開先の組を返す。"""
    agents = DOTPATH / "config/ai-agents"
    for name in (
        "CLAUDE.md",
        "settings.json",
        "statusline.py",
        "subagent_statusline.py",
    ):
        yield agents / "claude" / name, HOME / ".claude" / name
    for source in sorted((agents / "rules").glob("*.md")):
        yield source, HOME / ".claude/rules" / source.name
    for source in sorted(
        path for path in (agents / "skills").iterdir() if path.is_dir()
    ):
        for skill_dir in SKILL_DIRS:
            yield source, HOME / skill_dir / source.name
    yield agents / "codex/hooks.json", HOME / ".codex/hooks.json"


def check_dangling_links() -> Iterator[str]:
    """Dotfiles から消したファイルを指したまま残ったsymlinkを探す。"""
    for root, dirs, files in os.walk(HOME):
        depth = len(Path(root).relative_to(HOME).parts)
        if depth >= DANGLING_SCAN_DEPTH:
            dirs.clear()
        dirs[:] = [name for name in dirs if name not in DANGLING_SCAN_SKIP]
        # os.walk はsymlinkのdirを dirs に入れるが辿らないので、files と合わせて調べる
        for name in (*dirs, *files):
            path = Path(root, name)
            if (
                path.is_symlink()
                and not path.exists()
                and os.readlink(path).startswith(f"{DOTPATH}/")
            ):
                yield f"[symlink-dangling] {path} -> {os.readlink(path)}"


def check_mise() -> Iterator[str]:
    """入っていないtoolと、固定版と違うmise本体を探す。"""
    missing = subprocess.run(
        ["mise", "ls", "--missing"], cwd=HOME, capture_output=True, text=True
    ).stdout.strip()
    for line in missing.splitlines():
        yield f"[mise-missing] {line}"

    pinned = re.search(
        r'^MISE_VERSION="(.+)"',
        (DOTPATH / "script/setup/install_mise.sh").read_text(),
        re.MULTILINE,
    )
    current = subprocess.run(
        ["mise", "--version"], capture_output=True, text=True
    ).stdout.split()[0]
    if pinned and pinned[1] != current:
        yield f"[mise-version] mise {current} が install_mise.sh の固定版 {pinned[1]} と違う"


def check_textlint() -> Iterator[str]:
    """設定が読めないと exit 2 になる。exit 1 は文章への指摘なので問題ない。"""
    samples = {".md": "# 確認\n\n本文です。\n", ".html": "<p>本文です。</p>\n"}
    with tempfile.TemporaryDirectory() as tmp:
        for mode in ("fix", "report"):
            for suffix, text in samples.items():
                if mode == "fix" and suffix == ".html":
                    continue
                sample = Path(tmp, f"sample{suffix}")
                sample.write_text(text)
                result = subprocess.run(
                    [
                        "zsh",
                        str(DOTPATH / "script/tools/textlint.sh"),
                        mode,
                        str(sample),
                    ],
                    capture_output=True,
                    text=True,
                )
                if result.returncode >= 2:
                    error = (result.stderr or result.stdout).strip().splitlines()
                    yield f"[textlint] {mode} の設定で {suffix} を検査できない: {error[1] if len(error) > 1 else error}"


def check_apm() -> Iterator[str]:
    """lockにあるのに展開されていないファイルと、apmの管理外のskill・agentを探す。"""
    if not APM_LOCK.exists():
        yield f"[apm-missing] {APM_LOCK} が無い"
        return
    deployed = apm_deployed_files()
    for path in sorted(deployed):
        if not (HOME / path).exists():
            yield f"[apm-missing] lockに記録された ~/{path} が無い"

    # apm 管理外のskill・agentは、apm の展開を止めるか、古い版のまま使われ続ける
    for skill_dir in SKILL_DIRS:
        root = HOME / skill_dir
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if entry.is_symlink() or not (entry / "SKILL.md").exists():
                continue
            if f"{skill_dir}/{entry.name}" not in deployed:
                yield f"[apm-unmanaged] {entry} はapmの管理外"
    for agent_dir in AGENT_DIRS:
        root = HOME / agent_dir
        if not root.is_dir():
            continue
        for entry in sorted(root.iterdir()):
            if (
                not entry.is_symlink()
                and entry.is_file()
                and f"{agent_dir}/{entry.name}" not in deployed
            ):
                yield f"[apm-unmanaged] {entry} はapmの管理外"


def apm_deployed_files() -> set[str]:
    """Lock の deployed_files を集める。YAMLを読むためだけに依存を増やさず、行の形で取り出す。"""
    deployed: set[str] = set()
    in_list = False
    for line in APM_LOCK.read_text().splitlines():
        if line.strip() == "deployed_files:":
            in_list = True
            continue
        if in_list and line.startswith("  - "):
            deployed.add(line.removeprefix("  - ").strip())
            continue
        in_list = False
    return deployed


def check_codex_hooks() -> Iterator[str]:
    """hooks.json の各hookに承認の記録があるかを見る。定義の変更による承認切れは検出できない。"""
    hooks_file = HOME / ".codex/hooks.json"
    config_file = HOME / ".codex/config.toml"
    if not (hooks_file.exists() and config_file.exists()):
        return
    trusted = tomllib.loads(config_file.read_text()).get("hooks", {}).get("state", {})
    for event, groups in json.loads(hooks_file.read_text())["hooks"].items():
        snake = re.sub(r"(?<!^)(?=[A-Z])", "_", event).lower()
        for group_index, group in enumerate(groups):
            for hook_index, hook in enumerate(group["hooks"]):
                if f"{hooks_file}:{snake}:{group_index}:{hook_index}" not in trusted:
                    yield f"[codex-hook-untrusted] {event}[{group_index}][{hook_index}] {hook['command'][:60]}"


def check_codex_stale_keys() -> Iterator[str]:
    """テンプレートから消したキーを探す。mise dot apply のマージはキーを足すだけで消さないため、手で消す必要がある。

    Codex やユーザーが書き換えたキーと区別するため、過去のテンプレートと値まで一致するものだけを報告する。
    """
    config_file = HOME / ".codex/config.toml"
    if not config_file.exists():
        return
    current = flatten_keys(tomllib.loads((DOTPATH / CODEX_TEMPLATE).read_text()))
    past: dict[str, list[object]] = {}
    for commit in git("log", "--format=%H", "--", CODEX_TEMPLATE).splitlines():
        try:
            template = tomllib.loads(git("show", f"{commit}:{CODEX_TEMPLATE}"))
        except (subprocess.CalledProcessError, tomllib.TOMLDecodeError):
            continue
        for key, value in flatten_keys(template).items():
            past.setdefault(key, []).append(value)
    # apm が書き込むMCPサーバーは、テンプレートから消した後も apm の管理下にある
    apm_mcp = set(
        re.findall(
            r"^\s+- name: (\S+)",
            (DOTPATH / "config/ai-agents/apm.yml").read_text(),
            re.MULTILINE,
        )
    )
    for key, value in sorted(
        flatten_keys(tomllib.loads(config_file.read_text())).items()
    ):
        parts = key.split(".")
        if (
            key in current
            or value not in past.get(key, [])
            or parts[0] in CODEX_LOCAL_STATE_TABLES
            or key in CODEX_LOCAL_CHOICE_KEYS
        ):
            continue
        if parts[0] == "mcp_servers" and parts[1] in apm_mcp:
            continue
        yield f"[codex-stale-key] ~/.codex/config.toml の {key} はテンプレートから消えている"


def flatten_keys(table: dict, prefix: str = "") -> dict[str, object]:
    """入れ子のtableを、ドットでつないだキーと値の組にする。"""
    keys: dict[str, object] = {}
    for key, value in table.items():
        path = f"{prefix}{key}"
        if isinstance(value, dict):
            keys |= flatten_keys(value, f"{path}.")
        else:
            keys[path] = value
    return keys


if __name__ == "__main__":
    sys.exit(main())
