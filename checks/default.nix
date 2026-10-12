{
  pkgs,
  config,
  hostProfile,
}:

let
  inherit (pkgs) lib;
  home = config.home-manager.users.${hostProfile.user.userName};
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  qtPluginPath = config.environment.variables.QT_PLUGIN_PATH;
  qtPluginList =
    if builtins.isList qtPluginPath then qtPluginPath else lib.splitString ":" qtPluginPath;
in
# Merged across modules: setting QT_PLUGIN_PATH in one place must not drop the
# fcitx5 plugin directory another module contributes.
assert lib.hasInfix "fcitx5" (toString qtPluginPath);
assert builtins.length qtPluginList > 1;
# Host IPv6 stays off: Zen and WebRTC would otherwise leak a GUA past mihomo.
assert !config.networking.enableIPv6;
assert config.networking.networkmanager.connectionConfig."ipv6.method" == "disabled";
{
  configuration =
    pkgs.runCommand "configuration-regressions"
      {
        nativeBuildInputs = [
          python
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.jq
          pkgs.util-linux
        ];
        src = pkgs.lib.fileset.toSource {
          root = ../.;
          fileset = pkgs.lib.fileset.unions [
            ../scripts
            ../modules/system/mihomo
          ];
        };
      }
      ''
        cp -R "$src" source
        chmod -R u+w source
        cd source
        python -B -m unittest discover -s scripts/tests -v
        touch "$out"
      '';

  # statix/deadnix over every Nix file; nixfmt --check keeps the tree formatted.
  lint =
    pkgs.runCommand "lint"
      {
        nativeBuildInputs = [
          pkgs.statix
          pkgs.deadnix
          pkgs.nixfmt
        ];
        src = pkgs.lib.fileset.toSource {
          root = ../.;
          fileset = pkgs.lib.fileset.unions [
            (pkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ../.)
            ../statix.toml
          ];
        };
      }
      ''
        cd "$src"
        statix check .
        deadnix --fail --exclude hardware-configuration.nix .
        nixfmt --check .
        touch "$out"
      '';

  niri-config =
    pkgs.runCommand "niri-session-config"
      {
        nativeBuildInputs = [ home.programs.niri.package ];
        niriConfig = home.xdg.configFile.niri-config.source;
      }
      ''
        set -euo pipefail
        grep -F 'include "noctalia.kdl" optional=true' "$niriConfig"
        grep -F 'include "gpu.kdl" optional=true' "$niriConfig"

        work="$(mktemp -d)"
        cp "$niriConfig" "$work/config.kdl"

        niri validate -c "$work/config.kdl"

        cat > "$work/noctalia.kdl" <<'EOF'
        layout {
            focus-ring {
                active-color "#7c5cfa"
            }
        }
        EOF
        niri validate -c "$work/config.kdl"

        printf '%s\n' 'this is not valid kdl' > "$work/noctalia.kdl"
        if niri validate -c "$work/config.kdl"; then
          echo "corrupt noctalia.kdl was accepted" >&2
          exit 1
        fi

        touch "$out"
      '';
}
