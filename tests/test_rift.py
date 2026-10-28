"""Static config and mocked CLI tests; no macOS window operations are performed."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
RIFT = ROOT / "config/dot_config/rift"
# CI uses zsh on both platforms. Bash can test this helper's portable subset
# in a development container without zsh; this does not validate macOS behavior.
SHELL = os.environ.get("RIFT_TEST_SHELL") or shutil.which("zsh") or shutil.which("bash")


def screen(uuid, x, y=0, *, active=False, managed=True):
    return {
        "uuid": uuid,
        "frame": {"origin": {"x": x, "y": y}},
        "is_active_context": active,
        "is_active_space": managed,
    }


class ConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = tomllib.loads((RIFT / "config.toml").read_text())

    def test_traditional_without_animation_or_hooks(self):
        settings = self.config["settings"]
        self.assertEqual(settings["layout"]["mode"], "traditional")
        self.assertFalse(settings["animate"])
        self.assertFalse(settings["default_disable"])
        self.assertEqual(settings["run_on_start"], [])
        for values in settings["layout"]["gaps"].values():
            self.assertTrue(all(value == 0 for value in values.values()))

    def test_workspace_keys_and_follow(self):
        workspaces = self.config["virtual_workspaces"]
        self.assertEqual(workspaces["mode"], "per_display")
        self.assertEqual(workspaces["default_workspace_count"], 9)
        self.assertEqual(workspaces["workspace_names"], [str(i) for i in range(1, 10)])
        keys = self.config["keys"]
        for i in range(1, 10):
            self.assertEqual(keys[f"Alt + {i}"], {"switch_to_workspace": i - 1})
            self.assertEqual(
                keys[f"Alt + Shift + {i}"],
                {"move_window_to_workspace": {"workspace": i - 1, "follow": True}},
            )

    def test_focus_move_and_service_keys(self):
        keys = self.config["keys"]
        for key, direction in zip("HJKL", ("left", "down", "up", "right")):
            self.assertEqual(keys[f"Alt + Ctrl + {key}"], {"move_focus": direction})
            self.assertEqual(keys[f"Alt + Shift + {key}"], {"move_node": direction})
        for commands in self.config["binding_modes"]["service"].values():
            self.assertEqual(commands[-1], {"binding_mode": "default"})
        self.assertIn("move-next-display.sh", keys["Alt + Shift + Tab"]["exec"][-1])
        self.assertEqual(keys["Alt + Shift + Tab"]["exec"][0], "/bin/zsh")

    def test_floating_rules(self):
        rules = self.config["virtual_workspaces"]["app_rules"]
        self.assertEqual(len(rules), 8)
        self.assertEqual(sum(rule["floating"] for rule in rules), 7)
        ghostty = next(rule for rule in rules if rule["app_id"] == "com.mitchellh.ghostty")
        self.assertFalse(ghostty["floating"])

    def test_mise_registration(self):
        links = tomllib.loads((ROOT / "config/dot_config/mise/conf.d/dotfiles.toml").read_text())
        self.assertEqual(links["dotfiles"]["~/.config/rift"], "~/.dotfiles/config/dot_config/rift")
        macos = tomllib.loads((ROOT / "config/dot_config/mise/config.macos.toml").read_text())
        self.assertIn("brew:acsandmann/tap/rift", macos["bootstrap"]["packages"])
        self.assertIn("brew:jq", macos["bootstrap"]["packages"])
        self.assertIn("acsandmann/tap", macos["bootstrap"]["brew"]["taps"])
        self.assertIn("brew-cask:nikitabobko/tap/aerospace", macos["bootstrap"]["packages"])


@unittest.skipUnless(SHELL and shutil.which("jq"), "zsh (or bash) and jq are required")
class DisplayHelperTests(unittest.TestCase):
    def run_helper(self, payload, *, query_status=0, move_status=0, raw=False):
        with tempfile.TemporaryDirectory(prefix="rift test ") as directory:
            temp = Path(directory)
            response = temp / "displays.json"
            response.write_text(payload if raw else json.dumps(payload))
            calls = temp / "calls"
            # Mock only rift-cli. Execute the real helper and jq filter.
            cli = temp / "rift-cli"
            cli.write_text(
                "#!/bin/sh\n"
                'if [ "$1" = "query" ]; then\n'
                '  cat "$RIFT_TEST_RESPONSE"\n'
                '  exit "$RIFT_TEST_QUERY_STATUS"\n'
                "fi\n"
                'printf "%s\\n" "$*" >> "$RIFT_TEST_CALLS"\n'
                'if [ "$3" = "move-window" ]; then exit "$RIFT_TEST_MOVE_STATUS"; fi\n'
            )
            cli.chmod(0o755)
            # Exercise locating the filter through a config symlink too.
            config_link = temp / "rift config"
            config_link.symlink_to(RIFT, target_is_directory=True)
            env = dict(os.environ, PATH=f"{temp}:{os.environ['PATH']}")
            env.update(
                RIFT_TEST_RESPONSE=str(response),
                RIFT_TEST_CALLS=str(calls),
                RIFT_TEST_QUERY_STATUS=str(query_status),
                RIFT_TEST_MOVE_STATUS=str(move_status),
            )
            result = subprocess.run(
                [SHELL, str(config_link / "move-next-display.sh")],
                env=env, capture_output=True, text=True, timeout=10,
            )
            return result, calls.read_text().splitlines() if calls.exists() else []

    def assert_target(self, payload, target):
        result, calls = self.run_helper(payload)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [
            f"execute display move-window --uuid {target}",
            f"execute display focus --uuid {target}",
        ])

    def test_next_display_and_wrap(self):
        self.assert_target([screen("right", 100), screen("left", -100, active=True)], "right")
        self.assert_target([screen("right", 100, active=True), screen("left", -100)], "left")

    def test_vertical_order(self):
        self.assert_target([screen("bottom", 0, 100), screen("top", 0, -100, active=True)], "bottom")

    def test_three_displays(self):
        self.assert_target([screen("c", 100), screen("a", -100), screen("b", 0, active=True)], "c")

    def test_envelopes(self):
        screens = [screen("a", 0, active=True), screen("b", 100)]
        for payload in ({"data": screens}, {"displays": screens}, {"data": {"displays": screens}}):
            with self.subTest(payload=payload):
                self.assert_target(payload, "b")

    def test_unmanaged_display_is_skipped(self):
        self.assert_target([
            screen("a", 0, active=True), screen("disabled", 50, managed=False), screen("b", 100),
        ], "b")

    def test_zero_or_one_managed_display_is_noop(self):
        for screens in ([], [screen("a", 0, active=True)], [screen("a", 0, managed=False)]):
            with self.subTest(screens=screens):
                result, calls = self.run_helper(screens)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls, [])

    def test_ambiguous_context_fails_closed(self):
        for active_a, active_b in ((False, False), (True, True)):
            result, calls = self.run_helper([
                screen("a", 0, active=active_a), screen("b", 100, active=active_b),
            ])
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(calls, [])

    def test_invalid_response_fails_closed(self):
        for payload in ({"error": "offline"}, {}, None, [screen("a", 0), {"is_active_space": True}]):
            with self.subTest(payload=payload):
                result, calls = self.run_helper(payload)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    def test_duplicate_uuid_fails_closed(self):
        result, calls = self.run_helper([screen("a", 0, active=True), screen("a", 100)])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_invalid_json_fails_closed(self):
        for text in ("", "not json"):
            result, calls = self.run_helper(text, raw=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(calls, [])

    def test_query_failure_does_not_move(self):
        result, calls = self.run_helper([screen("a", 0, active=True), screen("b", 100)], query_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_move_failure_does_not_focus(self):
        result, calls = self.run_helper([screen("a", 0, active=True), screen("b", 100)], move_status=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, ["execute display move-window --uuid b"])


if __name__ == "__main__":
    unittest.main()
