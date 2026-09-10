"""Exercise updater isolation using real Git and mocked downloads/builds."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "codex-update.sh"
GIT = shutil.which("git")
REV = "a" * 40


class UpdateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = os.environ | {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "XDG_STATE_HOME": str(self.root / "state"),
            "HOME": str(self.root),
            "DISPLAY": "", "WAYLAND_DISPLAY": "",
            "TEST_REPO": str(self.repo),
            "TEST_ROOT": str(self.root),
            "TEST_MODE": "success",
        }
        self.git("init", "-b", "main")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Updater Test")
        (self.repo / "pkgs").mkdir()
        (self.repo / "pkgs/codex.nix").write_text(
            'version = "1.0.0";\nsha256 = "sha256:' + "0" * 64 + '";\n'
        )
        (self.repo / "flake.lock").write_text(json.dumps({"nodes": {
            "root": {"inputs": {"codex-desktop-linux": "desktop-renamed"}},
            "desktop-renamed": {"locked": {"rev": REV}, "original": {
                "type": "github", "owner": "ilysenko", "repo": "codex-desktop-linux"
            }},
        }}))
        self.git("add", ".")
        self.git("commit", "-m", "Initial")
        self.base = self.git("rev-parse", "HEAD")
        self.stub("git", f'''if [ "$1" = ls-remote ]; then
if [ "$TEST_MODE" = desktop-update ]; then
echo "{'b' * 40} refs/heads/main"
else
echo "{REV} refs/heads/main"
fi
else
exec {shlex.quote(GIT)} "$@"
fi
''')
        self.stub("gh", '''printf '%s\n' '{"tag_name":"rust-v1.1.0","assets":[{"name":"codex-package-x86_64-unknown-linux-musl.tar.zst","browser_download_url":"https://example.invalid/bundle"}]}'
''')
        self.stub("curl", '''[ "$TEST_MODE" != download-failure ] || exit 22
printf 'test bundle'
''')
        self.stub("nix", '''printf '%s\n' "$*" >> "$TEST_ROOT/nix-calls"
if [ "$1" = flake ] && [ "$2" = check ]; then exit 0; fi
if [ "$1" = flake ] && [ "$2" = update ]; then
  rev="${@: -1}"
  rev="${rev##*/}"
  jq --arg rev "$rev" '.nodes[.nodes.root.inputs["codex-desktop-linux"]] |= (.locked.rev = $rev | .original.rev = $rev)' flake.lock > flake.tmp
  mv flake.tmp flake.lock
  exit 0
fi
if [ "$TEST_MODE" = build-failure ]; then exit 1; fi
if [ "$TEST_MODE" = concurrent-edit ]; then echo user-edit > "$TEST_REPO/user-file"; fi
if [ "$TEST_MODE" = concurrent-commit ] && [ ! -e "$TEST_REPO/user-file" ]; then
  echo user-edit > "$TEST_REPO/user-file"
  git -C "$TEST_REPO" add user-file
  git -C "$TEST_REPO" commit -m "User change" >/dev/null
fi
case "$*" in
  *print-out-paths*) printf '%s\n' "$TEST_ROOT/cli" ;;
esac
''')
        cli = self.root / "cli"
        (cli / "bin").mkdir(parents=True)
        (cli / "codex-resources").mkdir()
        for name, body in [("codex", "echo 'codex-cli 1.1.0'"), ("codex-code-mode-host", ":")]:
            target = cli / "bin" / name
            target.write_text("#!/bin/sh\n" + body + "\n")
            target.chmod(0o755)

    def git(self, *args):
        return subprocess.check_output([GIT, "-C", str(self.repo), *args], env=self.env, stderr=subprocess.DEVNULL, text=True).strip()

    def stub(self, name, body):
        p = self.bin / name
        p.write_text(f"#!{shutil.which('bash')}\nset -eu\n" + body)
        p.chmod(0o755)

    def run_update(self, mode="success"):
        result = subprocess.run(["bash", "-c", f"repo={shlex.quote(str(self.repo))}; source {shlex.quote(str(SCRIPT))}"], env=self.env | {"TEST_MODE": mode})
        self.assertEqual(self.git("worktree", "list", "--porcelain").count("worktree "), 1)
        return result.returncode

    def test_success(self):
        self.assertEqual(self.run_update(), 0)
        self.assertNotEqual(self.git("rev-parse", "HEAD"), self.base)
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertIn('version = "1.1.0"', (self.repo / "pkgs/codex.nix").read_text())
        self.assertNotIn("toplevel", (self.root / "nix-calls").read_text())

    def test_desktop_revision_and_tracking_url(self):
        self.assertEqual(self.run_update("desktop-update"), 0)
        node = json.loads((self.repo / "flake.lock").read_text())["nodes"]["desktop-renamed"]
        self.assertEqual(node["locked"]["rev"], "b" * 40)
        self.assertNotIn("rev", node["original"])
        self.assertIn("--override-input", (self.root / "nix-calls").read_text())

    def test_failures_leave_checkout_intact(self):
        for mode in ["build-failure", "download-failure"]:
            with self.subTest(mode=mode):
                self.assertNotEqual(self.run_update(mode), 0)
                self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
                self.assertEqual(self.git("status", "--porcelain"), "")

    def test_concurrent_edit_is_preserved(self):
        self.assertEqual(self.run_update("concurrent-edit"), 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)
        self.assertEqual((self.repo / "user-file").read_text(), "user-edit\n")

    def test_concurrent_commit_is_preserved(self):
        self.assertEqual(self.run_update("concurrent-commit"), 0)
        self.assertEqual(self.git("log", "-1", "--format=%s"), "User change")
        self.assertIn('version = "1.0.0"', (self.repo / "pkgs/codex.nix").read_text())

    def test_dirty_checkout_skips_network(self):
        (self.repo / "user-file").write_text("unsaved work")
        self.stub("gh", "exit 99\n")
        self.assertEqual(self.run_update(), 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)

    def test_unchanged_release_skips_download(self):
        self.stub("gh", "echo '{\"tag_name\":\"rust-v1.0.0\"}'\n")
        self.stub("curl", "exit 99\n")
        self.assertEqual(self.run_update(), 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)


if __name__ == "__main__":
    unittest.main()
