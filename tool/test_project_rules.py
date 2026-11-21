"""Tests for tool/check_rules.py and .claude/hooks/guard.py.

Run with: python3 -m unittest discover -s tool -p 'test_*.py'
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_rules  # noqa: E402

GUARD = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "guard.py"


def violations(path: str, line: str) -> list[str]:
    return check_rules.check_text(path, line)


class CheckRulesTest(unittest.TestCase):
    def test_material_import_in_app_ui_is_flagged(self):
        self.assertTrue(violations("apps/flutter_client/lib/a.dart", "import 'package:material_ui/material_ui.dart';"))

    def test_material_import_in_viewer_adapter_is_allowed(self):
        self.assertFalse(violations(
            "packages/resource_renderers/lib/src/adapters/pdf.dart",
            "import 'package:material_ui/material_ui.dart';"))

    def test_lfs_flag_turned_on_is_flagged(self):
        self.assertTrue(violations("apps/edge_api/wrangler.jsonc", '"LFS_DIRECT_UPLOAD_ENABLED": "true"'))
        self.assertFalse(violations("apps/edge_api/wrangler.jsonc", '"LFS_DIRECT_UPLOAD_ENABLED": "false"'))

    def test_browser_storage_is_flagged_unless_marked(self):
        self.assertTrue(violations("apps/flutter_client/lib/a.dart", "window.localStorage['t'] = token;"))
        self.assertFalse(violations("apps/flutter_client/lib/a.dart", "localStorage['tab'] = '1'; // rule-ok: no-browser-credential-storage UI tab only"))
        self.assertTrue(violations("apps/flutter_client/lib/a.dart", "localStorage['t'] = token; // rule-ok:"))

    def test_eval_in_worker_is_flagged(self):
        self.assertTrue(violations("apps/edge_api/src/x.ts", "const f = new Function(body);"))

    def test_worker_fetch_to_unknown_host_is_flagged(self):
        self.assertTrue(violations("apps/edge_api/src/x.ts", 'await fetch("https://evil.example/a")'))
        self.assertTrue(violations("apps/edge_api/src/x.ts", "await fetch(repoUrl)"))
        self.assertFalse(violations("apps/edge_api/src/net/fetch.ts", "return fetch(url, init)"))

    def test_lfs_flag_split_across_lines_is_flagged(self):
        self.assertTrue(violations("apps/edge_api/wrangler.jsonc", '"LFS_DIRECT_UPLOAD_ENABLED":\n    "true"'))

    def test_html_widget_package_is_flagged(self):
        self.assertTrue(violations("apps/flutter_client/lib/a.dart", "import 'package:flutter_html/flutter_html.dart';"))


class GuardTest(unittest.TestCase):
    def run_guard(self, event: dict) -> int:
        return subprocess.run(
            [sys.executable, str(GUARD)], input=json.dumps(event), text=True, capture_output=True,
        ).returncode

    def bash(self, command: str) -> int:
        return self.run_guard({"tool_name": "Bash", "tool_input": {"command": command}})

    def test_blocks_owner_only_commands(self):
        for command in [
            "git push --force origin feat/x",
            "git push origin main",
            "npx wrangler deploy",
            "wrangler d1 migrations apply lectale --remote",
            "wrangler secret put GITHUB_KEY",
            "cat .dev.vars",
            "sed -i s/a/b/ spec/v4.0/README.md",
            "rm -rf .git",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.bash(command), 2)

    def test_allows_ordinary_work(self):
        for command in [
            "git push -u origin claude/m0-foundations",
            "npx wrangler deploy --dry-run",
            "wrangler d1 migrations apply lectale --local",
            "cat spec/v4.0/README.md",
            "rm -rf build",
            "cat .env.example",
            "git push origin claude/m1-validator:main",
            "rg 'git push origin main' docs",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.bash(command), 0)

    def test_blocks_edits_to_the_normative_spec(self):
        self.assertEqual(self.run_guard({"tool_name": "Edit", "tool_input": {"file_path": "/r/spec/v4.0/x.md"}}), 2)
        self.assertEqual(self.run_guard({"tool_name": "Edit", "tool_input": {"file_path": "spec/v4.0/README.md"}}), 2)


if __name__ == "__main__":
    unittest.main()
