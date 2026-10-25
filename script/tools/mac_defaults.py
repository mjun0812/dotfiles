#!/usr/bin/env python3
"""macOSのapp設定 (defaults) を、dotfilesでの管理に合わせて扱う。

report: mise の [bootstrap.macos.defaults] とUIで変えた設定のずれを報告する
strip:  stdinのplistから状態のキー (更新確認・ウィンドウ位置など) を除き、stdoutへ書く
"""

import json
import plistlib
import subprocess
import sys

# 設定ではなくappやAppKitが記録する状態のキーの接頭辞 (更新確認・ウィンドウ位置・起動回数など)
IGNORED_PREFIXES = ("Apple", "MSAppCenter", "NS", "SU")
IGNORED_PREFIXES_BY_DOMAIN = {
    "com.lwouis.alt-tab-macos": ("preferencesVersion",),
    "com.superultra.Homerow": ("activation-count",),
    # プロファイルはDynamic Profilesで管理する。NoSyncはiTerm2自身が同期対象から外している状態のキー
    "com.googlecode.iterm2": (
        "HotkeyMigratedFromSingleToMulti",
        "New Bookmarks",
        "NoSync",
        "PrefsCustomFolder",
        "findMode_iTerm",
        "iTerm Version",
        "kCPK",
    ),
}


def is_ignored(domain: str, key: str) -> bool:
    """keyが設定ではなく状態のキーならTrueを返す。"""
    return key.startswith(IGNORED_PREFIXES + IGNORED_PREFIXES_BY_DOMAIN.get(domain, ()))


def read_domain(domain: str) -> dict:
    """domainの現在の設定を読む。domainが無ければ空のdictを返す。"""
    out = subprocess.run(["defaults", "export", domain, "-"], capture_output=True, check=False)
    return plistlib.loads(out.stdout) if out.returncode == 0 else {}


def report() -> None:
    """宣言と値が違うキーと、宣言していないキーを表示する。"""
    status = subprocess.run(
        ["mise", "bootstrap", "macos", "defaults", "status", "--json"],
        capture_output=True,
        check=True,
        text=True,
    )
    entries = json.loads(status.stdout)["macos_defaults"]["entries"]

    declared = {}
    for e in entries:
        declared.setdefault(e["domain"], set()).add(e["key"])
        if e["state"] != "set":
            print(
                f"[{e['state']}] {e['domain']} {e['key']}: declared={e['value']!r} current={e['current']!r}"
            )

    for domain, keys in declared.items():
        for key, value in sorted(read_domain(domain).items()):
            if key not in keys and not is_ignored(domain, key):
                print(f"[undeclared] {domain} {key} = {value!r}")


def strip() -> None:
    """stdinのplistから状態のキーを除いてstdoutへ書く。"""
    data = plistlib.loads(sys.stdin.buffer.read())
    domain = sys.argv[2]
    kept = {k: v for k, v in data.items() if not is_ignored(domain, k)}
    plistlib.dump(kept, sys.stdout.buffer, fmt=plistlib.FMT_XML)


if __name__ == "__main__":
    {"report": report, "strip": strip}[sys.argv[1]]()
