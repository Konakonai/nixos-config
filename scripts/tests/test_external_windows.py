"""Fail closed when the external Windows launcher cannot confirm disk or guest state."""

from pathlib import Path
import os
import shutil
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/external-windows.sh"
VIRT = ROOT / "modules/system/external-windows-domain-xml.nix"


class ExternalWindowsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.trace = self.root / "trace.log"
        self.mounts = self.root / "mounts"
        self.mounts.write_text("")
        self.env = os.environ | {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.root),
            "EXTERNAL_WINDOWS_DOMAIN": "external-windows-11",
            "EXTERNAL_WINDOWS_DISK": "/dev/disk/by-id/usb-test",
            "EXTERNAL_WINDOWS_CONNECTION": "qemu:///system",
            "TRACE": str(self.trace),
            "MOUNTS": str(self.mounts),
            "LSBLK_FAIL": "0",
            "LSBLK_INVALID": "0",
            "VIRSH_LIST_FAIL": "0",
            "VIRSH_START_FAIL": "0",
            "VM_RUNNING": "0",
            "UNMOUNT_FAIL": "0",
            "KEEP_MOUNTED": "0",
            "LSBLK_COUNT": str(self.root / "lsblk.count"),
            "INSERT_MOUNT_ON": "0",
            "REMOUNT_ON_START": "0",
        }
        self._install_fakes()

    def _install_fakes(self):
        self._write_cmd("notify-send", 'echo "notify $*" >> "$TRACE"')
        self._write_cmd("zenity", 'echo "zenity $*" >> "$TRACE"')
        self._write_cmd("virt-viewer", 'echo "virt-viewer $*" >> "$TRACE"')
        self._write_cmd(
            "lsblk",
            r'''
echo "lsblk $*" >> "$TRACE"
count_file="${LSBLK_COUNT:-/tmp/lsblk.count}"
count=0
if [ -f "$count_file" ]; then
  count=$(cat "$count_file")
fi
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"
if [ "${INSERT_MOUNT_ON:-0}" != 0 ] && [ "$count" = "${INSERT_MOUNT_ON:-0}" ]; then
  printf '%s\n' "/dev/sdb1" >> "$MOUNTS"
fi
if [ "${LSBLK_FAIL:-0}" = 1 ]; then
  exit 1
fi
if [ "${LSBLK_INVALID:-0}" = 1 ]; then
  printf '%s\n' '{"not":'
  exit 0
fi
printf '%s' '{"blockdevices":[{"name":"/dev/sdb","mountpoints":[null],"children":['
first=1
while IFS= read -r name; do
  [ -n "$name" ] || continue
  [ "$first" = 1 ] || printf '%s' ','
  first=0
  printf '{"name":"%s","mountpoints":["%s-mnt"]}' "$name" "$name"
done < "$MOUNTS"
printf '%s\n' ']}]}'
''',
        )
        self._write_cmd(
            "udisksctl",
            r'''
echo "udisksctl $*" >> "$TRACE"
if [ "${UNMOUNT_FAIL:-0}" = 1 ]; then
  exit 1
fi
device=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--block-device" ]; then
    device="$2"
    break
  fi
  shift
done
if [ "${KEEP_MOUNTED:-0}" != 1 ]; then
  tmp="$(mktemp)"
  grep -Fvx "$device" "$MOUNTS" > "$tmp" || true
  mv "$tmp" "$MOUNTS"
fi
''',
        )
        self._write_cmd(
            "virsh",
            r'''
echo "virsh $*" >> "$TRACE"
while [ $# -gt 0 ]; do
  case "$1" in
    --connect) shift 2 ;;
    list)
      if [ "${VIRSH_LIST_FAIL:-0}" = 1 ]; then
        exit 1
      fi
      if [ "${VM_RUNNING:-0}" = 1 ]; then
        printf '%s\n' "$EXTERNAL_WINDOWS_DOMAIN"
      fi
      exit 0
      ;;
    start)
      echo "START-ATTEMPT $2" >> "$TRACE"
      if [ "${REMOUNT_ON_START:-0}" = 1 ]; then
        printf '%s\n' "/dev/sdb1" >> "$MOUNTS"
      fi
      if [ "${VIRSH_START_FAIL:-0}" = 1 ]; then
        exit 1
      fi
      echo "STARTED $2" >> "$TRACE"
      exit 0
      ;;
    *) exit 1 ;;
  esac
done
''',
        )

    def _write_cmd(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{shutil.which('bash')}\nset -euo pipefail\n" + body)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def run_launcher(self, **env):
        result = subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=self.root,
            env=self.env | env,
            capture_output=True,
            text=True,
        )
        self.trace.touch()
        return result, self.trace.read_text()

    def started(self, trace):
        return "STARTED" in trace

    def viewed(self, trace):
        return "virt-viewer" in trace

    def test_lsblk_failure_does_not_start_vm(self):
        result, trace = self.run_launcher(LSBLK_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertFalse(self.viewed(trace))
        self.assertNotIn("virsh --connect qemu:///system start", trace)

    def test_invalid_lsblk_json_does_not_start_vm(self):
        result, trace = self.run_launcher(LSBLK_INVALID="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertFalse(self.viewed(trace))
        self.assertNotIn(" start ", trace)

    def test_virsh_list_failure_does_not_start_vm(self):
        result, trace = self.run_launcher(VIRSH_LIST_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertFalse(self.viewed(trace))
        self.assertIn("virsh --connect qemu:///system list --name", trace)
        self.assertNotIn(" start ", trace)

    def test_unmount_failure_does_not_start_vm(self):
        self.mounts.write_text("/dev/sdb1\n")
        result, trace = self.run_launcher(UNMOUNT_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertFalse(self.viewed(trace))
        self.assertIn("udisksctl unmount --block-device /dev/sdb1", trace)
        self.assertNotIn(" start ", trace)

    def test_still_mounted_after_unmount_does_not_start_vm(self):
        self.mounts.write_text("/dev/sdb1\n")
        result, trace = self.run_launcher(KEEP_MOUNTED="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertFalse(self.viewed(trace))
        self.assertNotIn(" start ", trace)

    def test_running_guest_only_opens_viewer(self):
        result, trace = self.run_launcher(VM_RUNNING="1")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertTrue(self.viewed(trace))
        self.assertNotIn(" start ", trace)
        self.assertIn("virt-viewer --connect qemu:///system --wait --reconnect external-windows-11", trace)

    def test_remount_between_probes_does_not_start_vm(self):
        result, trace = self.run_launcher(INSERT_MOUNT_ON="3")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started(trace))
        self.assertNotIn("START-ATTEMPT", trace)

    def test_start_failure_after_remount_does_not_retry_start(self):
        result, trace = self.run_launcher(VIRSH_START_FAIL="1", REMOUNT_ON_START="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(trace.count("START-ATTEMPT"), 1)
        self.assertFalse(self.started(trace))
        self.assertIn("still mounted", result.stderr + trace)

    def test_unmounted_idle_guest_starts_then_opens_viewer(self):
        result, trace = self.run_launcher()
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self.started(trace))
        self.assertTrue(self.viewed(trace))
        self.assertIn("virsh --connect qemu:///system start external-windows-11", trace)

    def test_successful_unmount_starts_vm(self):
        self.mounts.write_text("/dev/sdb1\n")
        result, trace = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("udisksctl unmount --block-device /dev/sdb1", trace)
        self.assertTrue(self.started(trace))
        self.assertTrue(self.viewed(trace))

    def test_vcpu_and_topology_share_the_same_parameter(self):
        source = VIRT.read_text()
        self.assertIn("<vcpu placement='static'>${toString vcpus}</vcpu>", source)
        self.assertIn("cores='${toString vcpus}'", source)
        self.assertNotRegex(source, r"<vcpu placement='static'>[0-9]+</vcpu>")

    def test_generated_xml_matches_configured_vcpus(self):
        xml_path = os.environ.get("DOMAIN_XML")
        vcpus = os.environ.get("EXPECTED_VCPUS")
        if not xml_path or not vcpus:
            self.skipTest("generated domain XML is supplied by the configuration check")
        xml = Path(xml_path).read_text()
        self.assertIn(f"<vcpu placement='static'>{vcpus}</vcpu>", xml)
        self.assertIn(f"cores='{vcpus}'", xml)
        self.assertIn("sockets='1'", xml)
        self.assertIn("threads='1'", xml)
        self.assertIn("<feature policy='disable' name='vmx'/>", xml)
