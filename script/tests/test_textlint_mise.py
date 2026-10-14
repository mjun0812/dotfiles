"""Exercise the personal textlint bundle in an isolated HOME (requires network)."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[2]


class TextlintMiseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for tool in ("mise", "node", "bun", "zsh"):
            if not shutil.which(tool):
                raise RuntimeError(f"Required test tool is missing: {tool}")
        cls.mise = shutil.which("mise")
        cls.zsh = shutil.which("zsh")
        # Resolve runtime binaries before changing mise's HOME and data directory.
        runtime_dirs = []
        for tool in ("node", "bun"):
            resolved = subprocess.run(
                [cls.mise, "which", tool], check=True, capture_output=True, text=True
            ).stdout.strip()
            runtime_dirs.append(str(Path(resolved).parent))

        tmp = tempfile.TemporaryDirectory(prefix="textlint mise ")
        cls.addClassCleanup(tmp.cleanup)
        cls.home = Path(tmp.name) / "home"
        cls.repo = cls.home / ".dotfiles"
        cls.repo.mkdir(parents=True)
        for name in (
            "config/textlint/textlintrc.js",
            "config/textlint/textlintrc.fix.json",
            "config/textlint/textlintrc.report.json",
            "config/textlint/prh.yml",
            "script/setup/setup_textlint.sh",
            "script/tools/textlint.sh",
        ):
            target = cls.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)

        source = tomllib.loads(
            (ROOT / "config/dot_config/mise/config.toml").read_text(encoding="utf-8")
        )
        cls.bundle = source["tools"]["npm:textlint"]
        if source["settings"]["npm"]["package_manager"] != "bun":
            raise RuntimeError("textlint's bundle requires the Bun backend")
        # Use the real bundle definition, not a second list of test dependencies.
        config = cls.home / ".config/mise/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text(
            '[tools."npm:textlint"]\n'
            + "\n".join(f"{k} = {json.dumps(v)}" for k, v in cls.bundle.items())
            + '\n[settings]\nnpm.package_manager = "bun"\n'
            + f'trusted_config_paths = [{json.dumps(str(cls.home))}]\n'
            + f'minimum_release_age = {json.dumps(source["settings"]["minimum_release_age"])}\n',
            encoding="utf-8",
        )
        cls.env = {
            k: v for k, v in os.environ.items()
            if not k.startswith(("MISE_", "XDG_", "BUN_INSTALL"))
        }
        cls.env.update(
            HOME=str(cls.home),
            ZDOTDIR=str(cls.home),
            XDG_CONFIG_HOME=str(cls.home / ".config"),
            XDG_CACHE_HOME=str(cls.home / ".cache"),
            XDG_DATA_HOME=str(cls.home / ".local/share"),
            MISE_DATA_DIR=str(cls.home / ".local/share/mise"),
            MISE_GLOBAL_CONFIG_FILE=str(config),
            MISE_YES="1",
            PATH=os.pathsep.join(runtime_dirs + [os.environ["PATH"]]),
        )
        subprocess.run(
            [cls.mise, "install", "npm:textlint"], cwd=cls.repo, env=cls.env,
            check=True, timeout=600,
        )
        cls.prefix = Path(cls.run_command([cls.mise, "where", "npm:textlint"]).stdout.strip())
        cls.setup = [cls.zsh, "-f", str(cls.repo / "script/setup/setup_textlint.sh")]
        cls.wrapper = [cls.zsh, "-f", str(cls.repo / "script/tools/textlint.sh")]
        cls.cli = [cls.mise, "exec", "--", "textlint"]
        cls.run_command(cls.setup)

    @classmethod
    def run_command(cls, command, *, cwd=None, input=None, codes=(0,)):
        result = subprocess.run(
            command, cwd=cwd or cls.home, env=cls.env, input=input,
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode not in codes:
            raise AssertionError(
                f"{command!r}: exit {result.returncode}\n{result.stdout}\n{result.stderr}"
            )
        return result

    def test_rules_share_the_textlint_prefix(self):
        for spec in shlex.split(self.bundle["bun_args"]):
            name, version = spec.rsplit("@", 1)
            manifest = self.prefix / "node_modules" / name / "package.json"
            self.assertEqual(json.loads(manifest.read_text())["version"], version)
        self.run_command(self.cli + ["--version"])

    def test_normal_cli_finds_home_configuration(self):
        result = self.run_command(
            self.cli + ["--stdin", "--stdin-filename", "body.md", "--format", "json"],
            input="この API（確認用）を使います。\n", codes=(1,),
        )
        rules = {m["ruleId"] for item in json.loads(result.stdout) for m in item["messages"]}
        self.assertIn("prh", rules)
        self.assertIn("ja-space-between-half-and-full-width", rules)
        self.assertFalse((self.home / "body.md").exists())

    def test_fix_and_report_profiles(self):
        document = self.home / "原稿 with spaces.md"
        document.write_text("この API（確認用）を使います。\n", encoding="utf-8")
        self.run_command(self.wrapper + ["fix", "--fix", str(document)])
        expected = "このAPI(確認用)を使います。\n"
        self.assertEqual(document.read_text(encoding="utf-8"), expected)
        result = self.run_command(
            self.wrapper + ["report", "--format", "json", str(document)], codes=(0, 1)
        )
        self.assertIsInstance(json.loads(result.stdout), list)
        self.assertEqual(document.read_text(encoding="utf-8"), expected)

    def test_wrapper_ignores_callers_mise_tool_override(self):
        project = self.home / "caller"
        project.mkdir(exist_ok=True)
        (project / "mise.toml").write_text('[tools]\n"npm:textlint" = "0.0.0"\n')
        result = self.run_command(
            self.wrapper + ["fix", "--stdin", "--stdin-filename", "body.md", "--format", "json"],
            cwd=project, input="API（確認用）\n", codes=(1,),
        )
        self.assertTrue(json.loads(result.stdout)[0]["messages"])

    def test_project_textlint_configuration_keeps_precedence(self):
        project = self.home / "project-config"
        project.mkdir(exist_ok=True)
        (project / ".textlintrc.json").write_text(json.dumps({"rules": {
            "ja-space-between-half-and-full-width": {"space": "never"}
        }}))
        result = self.run_command(
            self.cli + ["--stdin", "--stdin-filename", "body.md", "--format", "json"],
            cwd=project, input="この API（確認用）を使います。\n", codes=(1,),
        )
        rules = {m["ruleId"] for item in json.loads(result.stdout) for m in item["messages"]}
        self.assertEqual(rules, {"ja-space-between-half-and-full-width"})

    def test_migration_removes_only_legacy_link_and_is_idempotent(self):
        legacy = self.home / ".local/bin/textlint"
        legacy.parent.mkdir(parents=True, exist_ok=True)
        legacy.symlink_to(self.repo / "config/textlint/node_modules/.bin/textlint")
        self.assertTrue(legacy.is_symlink())
        self.assertFalse(legacy.exists())
        self.run_command(self.setup)
        self.run_command(self.setup)
        self.assertFalse(legacy.is_symlink())
        self.assertEqual(
            (self.home / ".textlintrc.js").resolve(),
            self.repo / "config/textlint/textlintrc.js",
        )
        legacy.write_text("user-owned command\n")
        self.run_command(self.setup)
        self.assertEqual(legacy.read_text(), "user-owned command\n")
        legacy.unlink()
        legacy.symlink_to(self.home / "another-cli")
        self.run_command(self.setup)
        self.assertEqual(os.readlink(legacy), str(self.home / "another-cli"))
        legacy.unlink()

    def test_invalid_profile_fails(self):
        self.run_command(self.wrapper, codes=(2,))
        self.run_command(self.wrapper + ["unknown"], codes=(2,))

    def test_shell_syntax(self):
        for script in ("install.sh", "script/setup/setup_textlint.sh", "script/tools/textlint.sh"):
            self.run_command([self.zsh, "-n", str(ROOT / script)])


if __name__ == "__main__":
    unittest.main(verbosity=2)
