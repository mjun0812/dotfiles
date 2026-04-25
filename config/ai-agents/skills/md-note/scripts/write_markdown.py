#!/usr/bin/env python3
"""Markdown を YYYYMMDD_<topic>.md 形式で保存する補助スクリプト。

使い方:
  python scripts/write_markdown.py --stdin --slug research-summary
  python scripts/write_markdown.py --input draft.md --slug market-overview
  python scripts/write_markdown.py --stdin --slug ai-regulation --dir .

デフォルトではカレントディレクトリに保存します。
"""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", help="入力元の Markdown ファイル")
    parser.add_argument(
        "--stdin", action="store_true", help="標準入力から Markdown を読む"
    )
    parser.add_argument(
        "--slug",
        default="research-summary",
        help="ファイル名の topic 部分。英小文字・数字・ハイフンに正規化される",
    )
    parser.add_argument(
        "--dir",
        default=".",
        help="保存先ディレクトリ。省略時はカレントディレクトリ",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="同名ファイルが既に存在する場合でも上書きする",
    )
    return parser.parse_args()


def normalize_slug(text: str) -> str:
    text = text.strip().lower()
    text = text.replace("_", "-")
    text = re.sub(r"[^a-z0-9\-]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return text or "research-summary"


def read_content(args: argparse.Namespace) -> str:
    if args.stdin == bool(args.input):
        raise SystemExit("--stdin か --input のどちらか一方だけを指定してください")
    if args.stdin:
        content = sys.stdin.read()
    else:
        content = pathlib.Path(args.input).read_text(encoding="utf-8")
    if not content.strip():
        raise SystemExit("Markdown の内容が空です")
    return content


def main() -> int:
    args = parse_args()
    content = read_content(args)
    slug = normalize_slug(args.slug)
    ymd = dt.date.today().strftime("%Y%m%d")

    out_dir = pathlib.Path(args.dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{ymd}_{slug}.md"

    if out_path.exists() and not args.force:
        raise SystemExit(
            f"ファイルが既に存在します: {out_path}\n上書きするには --force を指定してください"
        )

    out_path.write_text(content, encoding="utf-8")

    if out_path.stat().st_size <= 0:
        raise SystemExit("ファイル作成に失敗しました")

    print(str(out_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
