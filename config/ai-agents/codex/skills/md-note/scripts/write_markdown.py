#!/usr/bin/env python3
"""Markdown を YYYYMMDD_<topic>.md 形式で保存する補助スクリプト。

使い方:
    uv run ~/.codex/skills/md-note/scripts/write_markdown.py --stdin --slug research-summary
    uv run ~/.codex/skills/md-note/scripts/write_markdown.py --input draft.md --slug market-overview
    uv run ~/.codex/skills/md-note/scripts/write_markdown.py --stdin --slug ai-regulation --dir .

デフォルトではカレントディレクトリに保存する。
"""

from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import sys


def parse_args() -> argparse.Namespace:
    """コマンドライン引数を解析する。

    Returns:
        解析済みの引数。
    """

    parser = argparse.ArgumentParser()
    parser.add_argument("--input", help="入力元の Markdown ファイル")
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="標準入力から Markdown を読む",
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
    """slug をファイル名に使える形式へ正規化する。

    Args:
        text: ユーザーが指定した topic 文字列。

    Returns:
        正規化済みの slug。空になった場合は ``research-summary`` を返す。
    """

    text = text.strip().lower()
    text = text.replace("_", "-")
    text = re.sub(r"[^a-z0-9-]+", "-", text)
    text = re.sub(r"-+", "-", text).strip("-")
    return text or "research-summary"


def read_content(args: argparse.Namespace) -> str:
    """入力ソースから Markdown 本文を読む。

    Args:
        args: 解析済みのコマンドライン引数。

    Returns:
        読み込んだ Markdown 文字列。

    Raises:
        SystemExit: 入力指定が不正、または本文が空の場合。
    """

    if args.stdin == bool(args.input):
        raise SystemExit("--stdin か --input のどちらか一方だけを指定してください")
    if args.stdin:
        content = sys.stdin.read()
    else:
        content = pathlib.Path(args.input).read_text(encoding="utf-8")
    if not content.strip():
        raise SystemExit("Markdown の内容が空です")
    return content


def build_output_path(output_dir: str, slug: str) -> pathlib.Path:
    """出力先の Markdown パスを組み立てる。

    Args:
        output_dir: 保存先ディレクトリ。
        slug: 正規化済みの topic slug。

    Returns:
        出力先ファイルパス。
    """

    ymd = dt.date.today().strftime("%Y%m%d")
    directory = pathlib.Path(output_dir)
    directory.mkdir(parents=True, exist_ok=True)
    return directory / f"{ymd}_{slug}.md"


def write_markdown(content: str, out_path: pathlib.Path, force: bool) -> pathlib.Path:
    """Markdown をファイルへ書き出す。

    Args:
        content: 保存する Markdown 本文。
        out_path: 出力先ファイルパス。
        force: 既存ファイルを上書きするかどうか。

    Returns:
        実際に保存したファイルパス。

    Raises:
        SystemExit: 既存ファイルがあり上書き不可、または保存に失敗した場合。
    """

    if out_path.exists() and not force:
        raise SystemExit(
            f"ファイルが既に存在します: {out_path}\n"
            "上書きするには --force を指定してください"
        )

    out_path.write_text(content, encoding="utf-8")

    if out_path.stat().st_size <= 0:
        raise SystemExit("ファイル作成に失敗しました")

    return out_path


def main() -> int:
    """エントリーポイント。"""

    args = parse_args()
    content = read_content(args)
    slug = normalize_slug(args.slug)
    out_path = build_output_path(args.dir, slug)
    saved_path = write_markdown(content, out_path, args.force)
    print(str(saved_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
