#!/usr/bin/env python3

"""Euporieの管理設定をローカル設定ファイルへマージする。"""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path


def merge_config(target: dict[str, object], managed: dict[str, object]) -> None:
    """管理対象の値を既存設定へ再帰的にマージする。

    Args:
        target: Euporieが更新する既存のローカル設定。
        managed: dotfilesで管理する設定。
    """

    for key, managed_value in managed.items():
        target_value = target.get(key)
        if isinstance(managed_value, dict) and isinstance(target_value, dict):
            merge_config(target_value, managed_value)
            continue
        target[key] = deepcopy(managed_value)


def main(argv: list[str]) -> int:
    """管理設定をローカル設定へマージする。

    Args:
        argv: プログラム名を含むコマンドライン引数。

    Returns:
        終了ステータスコード。
    """

    parser = argparse.ArgumentParser(
        description="Euporieの管理設定を既存のローカル設定へマージします。"
    )
    parser.add_argument("template", help="dotfilesで管理する設定テンプレートのパス。")
    parser.add_argument("target", help="Euporieが更新するローカル設定のパス。")
    args = parser.parse_args(argv[1:])

    template_path = Path(args.template)
    target_path = Path(args.target)

    try:
        managed_config: dict[str, object] = json.loads(
            template_path.read_text(encoding="utf-8")
        )
        target_config: dict[str, object] = json.loads(
            target_path.read_text(encoding="utf-8")
        )
        merge_config(target_config, managed_config)
        rendered_text = f"{json.dumps(target_config, indent=2)}\n"
    except (OSError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1

    if target_path.is_symlink():
        target_path.unlink()
    target_path.write_text(rendered_text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
