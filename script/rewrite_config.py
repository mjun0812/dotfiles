#!/usr/bin/env python3

"""Codex の設定ファイルにある dotfiles-managed ブロックを書き換える。"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

START_MARKER = "# dotfiles-managed:start"
END_MARKER = "# dotfiles-managed:end"
BLOCK_PATTERN = re.compile(
    rf"(?ms)^{re.escape(START_MARKER)}\n.*?^{re.escape(END_MARKER)}\n?"
)


def extract_managed_block(text: str, source: str) -> str:
    """テキストから managed ブロックを抽出する。

    Args:
        text: managed ブロックを含む想定の入力テキスト。
        source: エラーメッセージに表示する入力元の識別子。

    Returns:
        末尾の空行を除いた managed ブロック。

    Raises:
        ValueError: managed ブロックが見つからない場合。
    """

    match = BLOCK_PATTERN.search(text)
    if match is None:
        raise ValueError(f"{source} に {START_MARKER} と {END_MARKER} が必要です。")
    return match.group(0).rstrip()


def replace_managed_block(target_text: str, managed_block: str, source: str) -> str:
    """対象テキスト内の managed ブロックを置き換える。

    Args:
        target_text: 既存の設定テキスト。
        managed_block: テンプレートから抽出した managed ブロック。
        source: エラーメッセージに表示する入力元の識別子。

    Returns:
        managed ブロックを置き換えた後の設定テキスト。

    Raises:
        ValueError: managed ブロックが見つからない場合。
    """

    if BLOCK_PATTERN.search(target_text) is None:
        raise ValueError(f"{source} に {START_MARKER} と {END_MARKER} が必要です。")
    return BLOCK_PATTERN.sub(f"{managed_block}\n", target_text, count=1)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """コマンドライン引数を解析する。

    Args:
        argv: プログラム名を含むコマンドライン引数。

    Returns:
        解析済みのコマンドライン引数。
    """

    parser = argparse.ArgumentParser(
        description="Codex の設定ファイルにある dotfiles-managed ブロックを書き換えます。"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="ファイルは更新せず、書き換え結果を標準出力へ表示します。",
    )
    parser.add_argument("template", help="managed 設定テンプレートのパス。")
    parser.add_argument("target", help="その場で書き換えるローカル設定ファイルのパス。")
    return parser.parse_args(argv[1:])


def main(argv: list[str]) -> int:
    """CLI のエントリーポイントを実行する。

    Args:
        argv: プログラム名を含むコマンドライン引数。

    Returns:
        終了ステータスコード。
    """

    try:
        args = parse_args(argv)
        template_path = Path(args.template)
        target_path = Path(args.target)

        template_text = template_path.read_text(encoding="utf-8")
        target_text = target_path.read_text(encoding="utf-8")
        managed_block = extract_managed_block(template_text, str(template_path))
        rendered_text = replace_managed_block(
            target_text,
            managed_block,
            str(target_path),
        )
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1

    if args.dry_run:
        print(rendered_text, end="")
        return 0

    if target_path.is_symlink():
        target_path.unlink()
    target_path.write_text(rendered_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
