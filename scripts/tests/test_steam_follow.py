import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "steam-follow.py"
spec = importlib.util.spec_from_file_location("steam_follow", SCRIPT)
follow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(follow)


class SteamFollowTests(unittest.TestCase):
    def test_latest_steam_window_selects_output(self):
        windows = [
            {"id": 1, "app_id": "steam", "workspace_id": 1, "focus_timestamp": {"secs": 3}},
            {"id": 2, "app_id": "steam", "workspace_id": 2, "focus_timestamp": {"secs": 9}},
            {"id": 3, "app_id": "other", "workspace_id": 1, "focus_timestamp": {"secs": 99}},
        ]
        workspaces = [{"id": 1, "output": "internal"}, {"id": 2, "output": "external"}]
        self.assertEqual(follow.launcher_output(windows, workspaces), "external")
        self.assertIsNone(follow.launcher_output(windows, []))

    def test_new_game_only_and_never_undo_manual_move(self):
        def window(id, app_id, workspace=1):
            return {"id": id, "app_id": app_id, "workspace_id": workspace}
        game_id = "steam_app_3548580"
        events = [
            {"WindowsChanged": {"windows": [window(1, game_id), window(2, "other")]}},
            {"WindowOpenedOrChanged": {"window": window(3, "")}},
            {"WindowOpenedOrChanged": {"window": window(3, game_id)}},
            # Moving it back manually must not trigger a second placement.
            {"WindowOpenedOrChanged": {"window": window(3, game_id)}},
            {"WindowOpenedOrChanged": {"window": window(4, game_id, 2)}},
        ]
        stream = io.StringIO("\n".join(map(json.dumps, events)))
        workspaces = [{"id": 1, "output": "external"}, {"id": 2, "output": "internal"}]
        with patch.object(follow, "niri", return_value=workspaces), patch.object(follow.subprocess, "run") as run:
            follow.watch(stream, {1}, game_id, "internal")
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][-3:], ["--id", "3", "internal"])

    def test_disconnected_output_does_not_move_game(self):
        stream = io.StringIO(json.dumps({"WindowOpenedOrChanged": {"window": {
            "id": 5, "app_id": "steam_app_1", "workspace_id": 1,
        }}}))
        with patch.object(follow, "niri", return_value=[{"id": 1, "output": "external"}]), patch.object(follow.subprocess, "run") as run:
            follow.watch(stream, set(), "steam_app_1", "internal")
        run.assert_not_called()

    def test_plasma_passthrough_preserves_arguments_environment_and_exit(self):
        env = dict(os.environ, SteamAppId="3548580", PROBE="unchanged")
        env.pop("NIRI_SOCKET", None)
        result = subprocess.run([
            sys.executable, str(SCRIPT), sys.executable, "-c",
            "import os,sys; print(repr(sys.argv[1:])); print(os.environ['PROBE']); sys.exit(7)",
            "a b", "$(not-a-command)", "--flag",
        ], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 7)
        self.assertIn("['a b', '$(not-a-command)', '--flag']", result.stdout)
        self.assertIn("unchanged", result.stdout)

    def test_niri_failure_still_launches_game(self):
        env = dict(os.environ, NIRI_SOCKET="/missing", SteamAppId="3548580", PATH="/missing")
        result = subprocess.run([
            sys.executable, str(SCRIPT), sys.executable, "-c", "raise SystemExit(9)",
        ], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 9)
        self.assertIn("launching without placement", result.stderr)


if __name__ == "__main__":
    unittest.main()
