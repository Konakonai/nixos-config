{
  config,
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  nh = lib.getExe pkgs.nh;

  rebuild = pkgs.writeShellScriptBin "rebuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os switch ${hostProfile.user.nixosConfigPath} "$@"
  '';

  testbuild = pkgs.writeShellScriptBin "testbuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os test ${hostProfile.user.nixosConfigPath} "$@"
  '';

  # For updates that swap glibc, systemd or PAM: a live switch leaves running
  # processes unable to load the new PAM modules, so activate on reboot.
  bootbuild = pkgs.writeShellScriptBin "bootbuild" ''
    export PATH="/run/wrappers/bin:$PATH"
    exec ${nh} os boot ${hostProfile.user.nixosConfigPath} "$@"
  '';

  # One entry point for everything flake.lock does not pin. Leaves the diff
  # uncommitted for review; packages with no feed to ask are listed for manual
  # bumping.
  update-pins = pkgs.writeShellApplication {
    name = "update-pins";
    runtimeInputs = [
      pkgs.curl
      pkgs.flatpak
      pkgs.gnused
      pkgs.jq
      pkgs.lilya.nix-update
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${../../scripts/update-pins.sh} ${lib.escapeShellArg hostProfile.user.nixosConfigPath} "$@"
    '';
  };

  defaultsDir = "${config.xdg.dataHome}/nixos-config/defaults";
  noctaliaDefaults = config.xdg.configFile."noctalia/config.toml".source;
  jsonc = ../../scripts/jsonc.py;
  configDrift = pkgs.writeShellApplication {
    name = "config-drift";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.python3
      config.programs.noctalia.package
    ];
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
in
{
  home.packages = [
    rebuild
    testbuild
    bootbuild
    update-pins
    configDrift
  ];
}
