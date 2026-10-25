#!/usr/bin/env python3
"""mise の [bootstrap.macos.defaults] と、UIで変えた設定を突き合わせる。

report (既定): 宣言とのずれを報告する。[differs] などは宣言したキーの値が違うもの、
    [undeclared] は宣言していないキーを表す。macOS自身のdomainは状態のキーが多いため、[undeclared] を報告しない
snapshot: 全domainの今の設定を保存する。System Settingsなどで設定を変える前に実行する
changes: snapshotから変わったキーを、TOMLに貼れる形で表示する

TOMLへの反映は人が判断する。
"""

import argparse
import datetime
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path

SNAPSHOT = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "dotfiles"
    / "mac_defaults_snapshot.plist"
)

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


def is_system_domain(domain: str) -> bool:
    """domainがappではなくmacOS自身の設定ならTrueを返す。"""
    return domain == "NSGlobalDomain" or domain.startswith("com.apple.")


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


def read_all_domains() -> dict:
    """ユーザーの全domainの今の設定を読む。"""
    out = subprocess.run(
        ["defaults", "domains"], capture_output=True, check=True, text=True
    )
    domains = ["NSGlobalDomain", *out.stdout.strip().split(", ")]
    return {d: read_domain(d) for d in domains}


def toml_key(key: str) -> str:
    """TOMLのkeyとして書く。bare keyにできない文字を含めば引用する。"""
    return key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else json.dumps(key)


def is_declarable(value: object) -> bool:
    """TOMLで書ける値ならTrueを返す。日時とバイナリは、入れ子の中にあっても書けない。"""
    if isinstance(value, (bytes, datetime.datetime)):
        return False
    if isinstance(value, list):
        return all(is_declarable(v) for v in value)
    if isinstance(value, dict):
        return all(is_declarable(v) for v in value.values())
    return True


def toml_value(value: object) -> str:
    """plistの値をTOMLの値として書く。型 (整数と実数など) を保つ。"""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return f"{value:.1f}" if value.is_integer() else repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(v) for v in value) + "]"
    if isinstance(value, dict):
        items = ", ".join(f"{toml_key(k)} = {toml_value(v)}" for k, v in value.items())
        return "{ " + items + " }"
    raise TypeError(type(value))


def snapshot() -> None:
    """全domainの今の設定を保存する。"""
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_bytes(plistlib.dumps(read_all_domains(), fmt=plistlib.FMT_BINARY))
    print(f"Saved a snapshot to {SNAPSHOT}. Change settings, then run `changes`.")


def changes() -> None:
    """snapshotから変わったキーを、domainごとのTOMLの表として表示する。"""
    if not SNAPSHOT.exists():
        raise SystemExit(f"No snapshot at {SNAPSHOT}. Run `snapshot` first.")
    before = plistlib.loads(SNAPSHOT.read_bytes())
    for domain, after in sorted(read_all_domains().items()):
        old = before.get(domain, {})
        lines = []
        for key in sorted(old.keys() | after.keys(), key=str.lower):
            if old.get(key) == after.get(key) or (
                not is_system_domain(domain) and is_ignored(domain, key)
            ):
                continue
            value = after.get(key)
            # 日時は状態のキーで、miseでも宣言できない
            if isinstance(value, datetime.datetime):
                continue
            if key not in after:
                lines.append(f"# removed: {key} (mise cannot delete it)")
            elif not is_declarable(value):
                lines.append(f"# contains binary or dates, cannot be declared: {key}")
            else:
                lines.append(f"{toml_key(key)} = {toml_value(value)}")
        if lines:
            print(f'[bootstrap.macos.defaults."{domain}"]', *lines, "", sep="\n")


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
        if is_system_domain(domain):
            continue
        for key, value in sorted(read_domain(domain).items()):
            # バイナリの値はmiseで宣言できないので報告しない (Clipyのショートカットなど)
            if (
                key not in keys
                and not isinstance(value, bytes)
                and not is_ignored(domain, key)
            ):
                print(f"[undeclared] {domain} {key} = {value!r}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "command",
        nargs="?",
        default="report",
        choices=["report", "snapshot", "changes"],
    )
    {"report": report, "snapshot": snapshot, "changes": changes}[
        parser.parse_args().command
    ]()
