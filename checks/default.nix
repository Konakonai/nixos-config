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
  flatpakInstall = home.systemd.user.services.flatpak-managed-install;
  flatpakSanitize = toString flatpakInstall.Service.ExecStartPost;
  wechatEnv = home.services.flatpak.overrides."com.tencent.WeChat".Environment;
  mihomoTriggerNames = map (item: baseNameOf (toString item)) config.systemd.services.mihomo.restartTriggers;
  kdeconnectRefreshExec = toString home.systemd.user.services.kdeconnect-refresh.Service.ExecStart;
  kdeconnectNmHook = (builtins.head config.networking.networkmanager.dispatcherScripts).source;
  qtPluginPath = config.environment.variables.QT_PLUGIN_PATH;
  qtPluginList = if builtins.isList qtPluginPath then qtPluginPath else lib.splitString ":" qtPluginPath;
in
assert lib.hasInfix "if-unreachable" kdeconnectRefreshExec;
assert lib.hasInfix "fcitx5" (toString qtPluginPath);
assert builtins.length qtPluginList > 1;
assert flatpakTimer.Timer.Unit == "flatpak-managed-install-timer.service";
assert flatpakTimerService.Unit.ConditionACPower == true;
assert flatpakInstall.Unit.ConditionACPower == true;
assert lib.hasInfix "sanitize-flatpak-overrides" flatpakSanitize;
assert wechatEnv.QT_QPA_PLATFORM == "xcb";
assert !(wechatEnv ? QT_ENABLE_HIGHDPI_SCALING);
assert !(wechatEnv ? QT_SCALE_FACTOR_ROUNDING_POLICY);
assert !(flatpakTimer.Timer ? ConditionACPower);
assert !config.networking.enableIPv6;
assert config.networking.networkmanager.connectionConfig."ipv6.method" == "disabled";
assert lib.elem "mihomo-config.service" config.systemd.services.mihomo.requires;
assert lib.elem "mihomo-config.service" config.systemd.services.mihomo.after;
assert config.systemd.services.mihomo.restartTriggers == config.systemd.services.mihomo-config.restartTriggers;
assert lib.elem "config-before-proxies.yaml" mihomoTriggerNames;
assert lib.elem "config-after-proxies.yaml" mihomoTriggerNames;
assert lib.elem "mihomo-proxies.yaml.age" mihomoTriggerNames;
assert !(lib.any (name: lib.hasInfix "theme" name) mihomoTriggerNames);
{
  configuration = pkgs.runCommand "configuration-regressions" {
    nativeBuildInputs = [ python pkgs.bash pkgs.coreutils pkgs.git pkgs.jq pkgs.util-linux ];
    NOCTALIA_SEED = home.xdg.dataFile."nixos-config/defaults/noctalia-config.toml".source;
    DOMAIN_XML = domainXml;
    EXPECTED_VCPUS = vcpus;
    KDECONNECT_NM_HOOK = kdeconnectNmHook;
    KDECONNECT_REFRESH_EXEC = kdeconnectRefreshExec;
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
