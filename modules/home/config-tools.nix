{ config, pkgs, ... }:

let
  defaultsDir = "${config.xdg.dataHome}/nixos-config/defaults";
  noctaliaDefaults = config.xdg.configFile."noctalia/config.toml".source;
  jsonc = ../../scripts/jsonc.py;
  configDrift = pkgs.writeShellApplication {
    name = "config-drift";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils pkgs.python3 config.programs.noctalia.package ];
    text = ''
      case "''${1:-}" in
        noctalia)
          current="$(mktemp)"
          default="$(mktemp)"
          trap 'rm -f "$current" "$default"' EXIT
          noctalia config export merged > "$current"
          # Compare parsed values: serialization order and comments are irrelevant.
          # The diff is exactly the GUI override layer (settings.toml).
          python3 - "${noctaliaDefaults}" "$current" "$default" <<'PYTHON'
import json
from pathlib import Path
import sys
import tomllib
seed, current, default = map(Path, sys.argv[1:])
for source, target in ((seed, default), (current, current)):
    data = tomllib.loads(source.read_text())
    target.write_text(json.dumps(data, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
PYTHON
          diff -u "$default" "$current"
          ;;
        zed)
          current="$(mktemp)"
          default="$(mktemp)"
          trap 'rm -f "$current" "$default"' EXIT
          python3 ${jsonc} canonicalize "${config.xdg.configHome}/zed/settings.json" > "$current"
          python3 ${jsonc} canonicalize "${defaultsDir}/zed-settings.json" > "$default"
          diff -u "$default" "$current"
          ;;
        *)
          echo "usage: config-drift <noctalia|zed>" >&2
          exit 2
          ;;
      esac
    '';
  };
  configDump = pkgs.writeShellApplication {
    name = "config-dump";
    runtimeInputs = [ pkgs.coreutils pkgs.python3 config.programs.noctalia.package ];
    text = ''
      case "''${1:-}" in
        noctalia)
          noctalia config export merged
          ;;
        zed)
          python3 ${jsonc} canonicalize "${config.xdg.configHome}/zed/settings.json"
          ;;
        *)
          echo "usage: config-dump <noctalia|zed>" >&2
          exit 2
          ;;
      esac
    '';
  };
  configRepair = pkgs.writeShellApplication {
    name = "config-repair";
    runtimeInputs = [ config.programs.noctalia.package pkgs.coreutils ];
    text = ''
      if [ "''${1:-}" != "noctalia-templates" ]; then
        echo "usage: config-repair noctalia-templates" >&2
        exit 2
      fi

      for template in darkly-qt.conf darkly-kde-colors heroic.css; do
        path="${config.xdg.configHome}/noctalia/templates/$template"
        if [ ! -e "$path" ]; then
          echo "missing template: $path; run rebuild first" >&2
          exit 1
        fi
      done

      noctalia msg templates-apply
    '';
  };
in
{
  home.packages = [ configDrift configDump configRepair ];
}
