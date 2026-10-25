#!/usr/bin/env python3
"""mise の [bootstrap.macos.defaults] と、appのUIで変えた設定のずれを報告する。

[differs] などは宣言したキーの値が違うもの、[undeclared] は宣言していないキーを表す。
TOMLへの反映は人が判断する。
"""

import json
import plistlib
import re
import subprocess

# 設定ではなくappやAppKitが記録する状態のキー (更新確認・ウィンドウ位置・起動回数など)。keyの先頭から照合する
IGNORED_PATTERNS = ("Apple", "MSAppCenter", "NS", "SU")
IGNORED_PATTERNS_BY_DOMAIN = {
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
    # key@対象 はディスプレイなどの機器ごとの情報や状態で、別のMacでは合わない
    "pro.betterdisplay.BetterDisplay": (
        ".*@",
        "Paddle-",
        "appAlreadyLaunched",
        "buildNumber",
        "displayConfigurationId",
        "displayTagIDs",
        "onboarding",
        "overrideSettingsLast",
        "settings.*Pane",
        "sheetSizeSaveEntries",
        "showProLicenseError",
        "singleMoreMenuTagID",
        "tagIDCounter",
        "tools(MenuCollapsed|MoreOptions)",
        "update(Build|Found|Version)",
    ),
    "com.clipy-app.Clipy": ("appMigrationUserDefaultsCodable", "kCPYMigrate"),
}


def is_ignored(domain: str, key: str) -> bool:
    """keyが設定ではなく状態のキーならTrueを返す。"""
    patterns = IGNORED_PATTERNS + IGNORED_PATTERNS_BY_DOMAIN.get(domain, ())
    return any(re.match(p, key) for p in patterns)


def read_domain(domain: str) -> dict:
    """domainの現在の設定を読む。domainが無ければ空のdictを返す。"""
    out = subprocess.run(
        ["defaults", "export", domain, "-"], capture_output=True, check=False
    )
    return plistlib.loads(out.stdout) if out.returncode == 0 else {}


def main() -> None:
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
            # バイナリの値はmiseで宣言できないので報告しない (Clipyのショートカットなど)
            if (
                key not in keys
                and not isinstance(value, bytes)
                and not is_ignored(domain, key)
            ):
                print(f"[undeclared] {domain} {key} = {value!r}")


if __name__ == "__main__":
    main()
