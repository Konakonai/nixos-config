{ pkgs, config, hostProfile }:

let
  inherit (pkgs) lib;
  home = config.home-manager.users.${hostProfile.user.userName};
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ps.pyyaml ]);
  domainXml = builtins.head config.systemd.services.external-windows-libvirt-domain.restartTriggers;
  vcpus = toString hostProfile.virtualization.externalWindows.vcpus;
  flatpakTimer = home.systemd.user.timers."flatpak-managed-install-timer";
  flatpakTimerUnit = lib.removeSuffix ".service" flatpakTimer.Timer.Unit;
  flatpakTimerService = home.systemd.user.services.${flatpakTimerUnit};
in
assert flatpakTimer.Timer.Unit == "flatpak-managed-install-timer.service";
assert flatpakTimerService.Unit.ConditionACPower == true;
assert home.systemd.user.services.flatpak-managed-install.Unit.ConditionACPower == true;
assert !(flatpakTimer.Timer ? ConditionACPower);
{
  configuration = pkgs.runCommand "configuration-regressions" {
    nativeBuildInputs = [ python pkgs.bash pkgs.coreutils pkgs.git pkgs.jq pkgs.util-linux ];
    NOCTALIA_SEED = home.xdg.dataFile."nixos-config/defaults/noctalia-config.toml".source;
    DOMAIN_XML = domainXml;
    EXPECTED_VCPUS = vcpus;
    src = pkgs.lib.fileset.toSource {
      root = ../.;
      fileset = pkgs.lib.fileset.unions [
        ../scripts
        ../modules/system/mihomo
        ../modules/system/virtualization.nix
        ../modules/system/external-windows-domain-xml.nix
        ../modules/home/niri
      ];
    };
  } ''
    cp -R "$src" source
    chmod -R u+w source
    cd source
    python -B -m unittest discover -s scripts/tests -v
    touch "$out"
  '';

  portal = assert config.xdg.portal.config.niri."org.freedesktop.impl.portal.ScreenCast" == "gnome";
    assert config.xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" == "gtk";
    pkgs.runCommand "portal-backend-contract" { } ''touch "$out"'';

  external-windows-cpu = pkgs.runCommand "external-windows-cpu" {
    xml = domainXml;
    inherit vcpus;
  } ''
    set -euo pipefail
    grep -F "<vcpu placement='static'>$vcpus</vcpu>" "$xml"
    grep -F "cores='$vcpus'" "$xml"
    test "$vcpus" != 3
    xml3="${pkgs.writeText "external-windows-3vcpu.xml" (import ../modules/system/external-windows-domain-xml.nix {
      domainName = "cpu-contract";
      uuid = "00000000-0000-0000-0000-000000000000";
      memoryKiB = 5 * 1024 * 1024;
      vcpus = 3;
      diskById = "/dev/null";
      ovmfCode = "/ovmf/CODE.fd";
      ovmfVars = "/ovmf/VARS.fd";
      guestToolsIso = "/guest.iso";
    })}"
    grep -F "<vcpu placement='static'>3</vcpu>" "$xml3"
    grep -F "cores='3'" "$xml3"
    touch "$out"
  '';

  niri-config = pkgs.runCommand "niri-session-config" {
    nativeBuildInputs = [ home.programs.niri.package ];
    niriConfig = home.xdg.configFile.niri-config.source;
  } ''
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
