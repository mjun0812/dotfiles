#!/usr/bin/env python3
"""旧形式の decisions.md を 1件1ファイル (NNNN-<slug>.md) の決定記録へ分割する.

usage:
  migrate_decisions.py plan <repo-root> <plan.tsv>   # 移行計画を作る (slug列は空)
  migrate_decisions.py apply <repo-root> <plan.tsv>  # 計画に従ってファイルを作成し、D番号の参照を書き換える
"""

import re
import sys
from pathlib import Path
from typing import NoReturn, TypedDict

SOURCES = [
    (Path(".mjun/steering/decisions.md"), Path(".mjun/steering/adr")),
    (Path("docs/adr/decisions.md"), Path("docs/adr")),
]
ENTRY_RE = re.compile(r"^## (D-\d+): *(.*)$")
FILE_RE = re.compile(r"^(\d{4})-.*\.md$")
SLUG_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SUPERSEDED_RE = re.compile(r"^- Status: superseded by (D-\d+)")


class Entry(TypedDict):
    """decisions.mdの1entry."""

    id: str
    title: str
    body: list[str]


def fail(message: str) -> NoReturn:
    """エラーを表示して終了する.

    Args:
        message: 表示するメッセージ.
    """
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def resolve_source(root: Path) -> tuple[Path, Path]:
    """移行元のdecisions.mdと移行先ディレクトリを決める.

    Args:
        root: repository root.

    Returns:
        rootからの相対パスで (移行元, 移行先ディレクトリ).
    """
    found = [(src, dst) for src, dst in SOURCES if (root / src).is_file()]
    if not found:
        fail(
            "decisions.md が見つからない (.mjun/steering/decisions.md, docs/adr/decisions.md)"
        )
    if len(found) > 1:
        fail(
            "decisions.md が2箇所にある。旧形式のGit管理への移行が未完了なので、どちらを正とするか人間に確認する"
        )
    return found[0]


def parse_entries(text: str) -> tuple[list[Entry], list[str]]:
    """decisions.mdを `## D-NNN:` 単位のentryへ分ける.

    Args:
        text: decisions.mdの内容.

    Returns:
        entryの一覧と、どのentryにも属さない行 (先頭のH1を除く).
    """
    entries: list[Entry] = []
    unparsed: list[str] = []
    current: Entry | None = None
    for line in text.splitlines():
        match = ENTRY_RE.match(line)
        if match:
            current = {"id": match.group(1), "title": match.group(2), "body": []}
            entries.append(current)
        elif line.startswith("## "):
            current = None
            unparsed.append(line)
        elif current is not None:
            current["body"].append(line)
        elif line.strip() and not (
            line.startswith("# ") and not entries and not unparsed
        ):
            unparsed.append(line)
    ids = [entry["id"] for entry in entries]
    duplicates = sorted({entry_id for entry_id in ids if ids.count(entry_id) > 1})
    if duplicates:
        fail(f"D番号が重複している: {', '.join(duplicates)}")
    return entries, unparsed


def existing_numbers(target: Path) -> dict[int, list[str]]:
    """移行先に既にある `NNNN-*.md` の番号を集める.

    Args:
        target: 移行先ディレクトリ.

    Returns:
        番号からファイル名一覧への対応.
    """
    if not target.is_dir():
        return {}
    numbers: dict[int, list[str]] = {}
    for path in sorted(target.iterdir()):
        match = FILE_RE.match(path.name)
        if match:
            numbers.setdefault(int(match.group(1)), []).append(path.name)
    return numbers


def plan(root: Path, plan_path: Path) -> None:
    """移行計画のTSV (D番号, 新番号, slug, タイトル) を書き出す.

    Args:
        root: repository root.
        plan_path: 書き出すTSVのパス.
    """
    source, target = resolve_source(root)
    entries, unparsed = parse_entries((root / source).read_text())
    if not entries:
        fail(f"{source} に `## D-NNN:` のentryが無い")
    existing = existing_numbers(root / target)
    used = set(existing)
    rows = []
    for entry in entries:
        number = int(entry["id"].split("-")[1])
        if number in used or number == 0:
            number = max(used | {0}) + 1
        used.add(number)
        rows.append((entry["id"], f"{number:04d}", "", entry["title"]))

    plan_path.write_text("".join("\t".join(row) + "\n" for row in rows))
    print(f"source: {source}")
    print(f"target: {target}/")
    print(f"entries: {len(entries)}")
    print(
        "existing:",
        ", ".join(name for names in existing.values() for name in names) or "none",
    )
    renumbered = [
        f"{old}->D-{new}"
        for old, new, _, _ in rows
        if int(old.split("-")[1]) != int(new)
    ]
    print("renumbered:", ", ".join(renumbered) or "none")
    print("unparsed:", "none" if not unparsed else "")
    for line in unparsed:
        print(f"  {line}")
    print(f"plan: {plan_path}")


def read_plan(plan_path: Path) -> list[tuple[str, str, str]]:
    """slugを記入済みの移行計画を読む.

    Args:
        plan_path: 移行計画のTSV.

    Returns:
        (旧D番号, 新番号, slug) の一覧.
    """
    rows = []
    for number, line in enumerate(plan_path.read_text().splitlines(), 1):
        if not line.strip():
            continue
        cols = line.split("\t")
        if len(cols) != 4:
            fail(f"plan {number}行目: 列数が4ではない")
        old, new, slug, _ = cols
        if not re.fullmatch(r"\d{4}", new):
            fail(f"plan {number}行目: 番号 `{new}` が4桁ではない")
        if not SLUG_RE.match(slug):
            fail(
                f"plan {number}行目: slug `{slug}` は英小文字・数字・ハイフンだけにする"
            )
        rows.append((old, new, slug))
    return rows


def rewrite_ids(text: str, mapping: dict[str, str]) -> str:
    """旧D番号を新D番号へ置き換える.

    Args:
        text: 対象の文字列.
        mapping: 旧D番号から新D番号への対応.

    Returns:
        置換後の文字列.
    """
    if not mapping:
        return text
    pattern = re.compile(
        r"(?<![\w-])(" + "|".join(re.escape(old) for old in mapping) + r")(?!\d)"
    )
    return pattern.sub(lambda match: mapping[match.group(1)], text)


def apply(root: Path, plan_path: Path) -> None:
    """移行計画に従ってentryファイルを作り、.mjun/ とCONTEXT.mdの参照を書き換える.

    Args:
        root: repository root.
        plan_path: slugを記入済みの移行計画.
    """
    source, target = resolve_source(root)
    entries, unparsed = parse_entries((root / source).read_text())
    rows = read_plan(plan_path)
    by_id = {entry["id"]: entry for entry in entries}
    if sorted(row[0] for row in rows) != sorted(by_id):
        fail("planのD番号がdecisions.mdのentryと一致しない。planを作り直す")
    numbers = [int(row[1]) for row in rows]
    existing = existing_numbers(root / target)
    clashes = sorted({n for n in numbers if numbers.count(n) > 1 or n in existing})
    if clashes:
        fail(f"番号が衝突している: {', '.join(f'{n:04d}' for n in clashes)}")

    mapping = {old: f"D-{new}" for old, new, _ in rows}
    (root / target).mkdir(parents=True, exist_ok=True)
    created: list[Path] = []
    for old, new, slug in rows:
        entry = by_id[old]
        body = rewrite_ids("\n".join(entry["body"]), mapping).strip("\n")
        title = rewrite_ids(entry["title"], mapping)
        path = root / target / f"{new}-{slug}.md"
        path.write_text(f"# D-{new}: {title}\n\n{body}\n")
        created.append(path)

    rewritten: list[Path] = []
    candidates = [root / "CONTEXT.md", *sorted((root / ".mjun").rglob("*.md"))]
    for path in candidates:
        if not path.is_file() or path == root / source or path in created:
            continue
        text = path.read_text()
        updated = rewrite_ids(text, mapping)
        if updated != text:
            path.write_text(updated)
            rewritten.append(path)

    new_ids = set(mapping.values())
    problems: list[str] = []
    for path in created:
        for line in path.read_text().splitlines():
            match = SUPERSEDED_RE.match(line)
            if match and match.group(1) not in new_ids:
                problems.append(
                    f"{path.relative_to(root)}: superseded先 {match.group(1)} が存在しない"
                )
    for path in [*created, *rewritten]:
        leftover = re.findall(r"(?<![\w-])D-\d{1,3}(?!\d)", path.read_text())
        if leftover:
            problems.append(
                f"{path.relative_to(root)}: 旧形式のD番号が残っている ({', '.join(sorted(set(leftover)))})"
            )

    print(f"created: {len(created)}")
    for path in created:
        print(f"  {path.relative_to(root)}")
    print(f"rewritten: {len(rewritten)}")
    for path in rewritten:
        print(f"  {path.relative_to(root)}")
    print("unparsed:", "none" if not unparsed else "")
    for line in unparsed:
        print(f"  {line}")
    print("problems:", "none" if not problems else "")
    for problem in problems:
        print(f"  {problem}")
    print(f"source (未削除): {source}")


def main() -> None:
    """コマンドライン引数を解釈して実行する."""
    if len(sys.argv) != 4 or sys.argv[1] not in ("plan", "apply"):
        fail("usage: migrate_decisions.py plan|apply <repo-root> <plan.tsv>")
    root, plan_path = Path(sys.argv[2]).resolve(), Path(sys.argv[3])
    if sys.argv[1] == "plan":
        plan(root, plan_path)
    else:
        apply(root, plan_path)


if __name__ == "__main__":
    main()
