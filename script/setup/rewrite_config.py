#!/usr/bin/env python3

"""Codex の管理設定をローカル設定ファイルへマージする。"""

from __future__ import annotations

import argparse
from copy import deepcopy
import sys
from pathlib import Path

from tomlkit import TOMLDocument, dumps, parse
from tomlkit.container import Container
from tomlkit.exceptions import TOMLKitError
from tomlkit.items import Table

LOCAL_STATE_TABLES = frozenset({"desktop", "projects"})
LEGACY_MARKERS = frozenset({"# dotfiles-managed:start", "# dotfiles-managed:end"})


def validate_managed_config(config: TOMLDocument, source: str) -> None:
    """管理設定にローカル状態テーブルが含まれないことを確認する。

    Args:
        config: dotfiles で管理する Codex 設定。
        source: エラーメッセージに表示する設定ファイルの識別子。

    Raises:
        ValueError: ローカル状態テーブルが含まれる場合。
    """

    managed_state_tables = sorted(LOCAL_STATE_TABLES.intersection(config))
    if managed_state_tables:
        table_names = ", ".join(managed_state_tables)
        raise ValueError(
            f"{source} にローカル状態テーブルを含めないでください: {table_names}"
        )


def merge_tables(target: Container, managed: Container) -> None:
    """管理対象の値だけを既存設定へ再帰的にマージする。

    Args:
        target: Codex が更新する既存のローカル設定。
        managed: dotfiles で管理する設定。
    """

    for key, managed_value in managed.items():
        target_value = target.get(key)
        if isinstance(managed_value, Table) and isinstance(target_value, Table):
            merge_tables(target_value, managed_value)
            continue
        target[key] = deepcopy(managed_value)


def remove_legacy_markers(text: str) -> str:
    """旧方式の管理マーカーを設定テキストから除去する。

    Args:
        text: TOML として整形済みの設定テキスト。

    Returns:
        旧方式の管理マーカーを含まない設定テキスト。
    """

    lines = (line for line in text.splitlines() if line not in LEGACY_MARKERS)
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    """コマンドライン引数を解析する。

    Args:
        argv: プログラム名を含むコマンドライン引数。

    Returns:
        解析済みのコマンドライン引数。
    """

    parser = argparse.ArgumentParser(
        description="Codex の管理設定を既存のローカル設定へマージします。"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="ファイルは更新せず、マージ結果を標準出力へ表示します。",
    )
    parser.add_argument("template", help="dotfiles で管理する設定テンプレートのパス。")
    parser.add_argument("target", help="Codex が更新するローカル設定ファイルのパス。")
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

        managed_config = parse(template_path.read_text(encoding="utf-8"))
        target_config = parse(target_path.read_text(encoding="utf-8"))
        validate_managed_config(managed_config, str(template_path))
        merge_tables(target_config, managed_config)
        rendered_text = remove_legacy_markers(dumps(target_config))
    except (OSError, TOMLKitError, ValueError) as error:
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
