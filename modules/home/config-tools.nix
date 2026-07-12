{ config, pkgs, ... }:

let
  defaultsDir = "${config.xdg.dataHome}/nixos-config/defaults";
  configDrift = pkgs.writeShellApplication {
    name = "config-drift";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils pkgs.jq ];
    text = ''
      case "''${1:-}" in
        noctalia)
          diff -u "${defaultsDir}/noctalia-config.toml" \
            "${config.xdg.configHome}/noctalia/config.toml"
          ;;
        zed)
          current="$(mktemp)"
          default="$(mktemp)"
          trap 'rm -f "$current" "$default"' EXIT
          jq -S . "${config.xdg.configHome}/zed/settings.json" > "$current"
          jq -S . "${defaultsDir}/zed-settings.json" > "$default"
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
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      case "''${1:-}" in
        noctalia)
          cat "${config.xdg.configHome}/noctalia/config.toml"
          ;;
        zed)
          jq -S . "${config.xdg.configHome}/zed/settings.json"
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

      for template in darkly-qt.conf darkly-kde-colors heroic.css cc-switch-tui.json; do
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
