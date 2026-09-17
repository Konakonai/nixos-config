{
  config,
  lib,
  pkgs,
  ...
}:

let
  runtimeDir = "/run/mihomo";
  configFile = "${runtimeDir}/config.yaml";
  proxiesFile = config.age.secrets.mihomo-proxies.path;
  configBeforeProxies = ./mihomo/config-before-proxies.yaml;
  configAfterProxies = ./mihomo/config-after-proxies.yaml;
  encryptedProxies = ../../secrets/mihomo-proxies.yaml.age;
in
{
  age.secrets.mihomo-proxies = {
    file = encryptedProxies;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.services.mihomo-config = {
    description = "Generate Mihomo runtime configuration";
    before = [ "mihomo.service" ];
    requiredBy = [ "mihomo.service" ];
    path = [
      pkgs.bash
      pkgs.coreutils
    ];
    restartTriggers = [
      configBeforeProxies
      configAfterProxies
      encryptedProxies
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      bash ${../../scripts/generate-mihomo-config.sh} \
        ${configBeforeProxies} \
        ${proxiesFile} \
        ${configAfterProxies} \
        ${configFile}
    '';
  };

  services.mihomo = {
    enable = true;
    tunMode = true;
    inherit configFile;
    webui = pkgs.metacubexd;
  };

  # The proxy can establish listeners before the uplink is ready and reconnect
  # on its own. Do not hold graphical.target behind NetworkManager's online
  # heuristic. LoadCredential copies config.yaml at start, so fragment changes
  # must restart this unit after a successful generator run.
  systemd.services.mihomo = {
    requires = lib.mkForce [ "mihomo-config.service" ];
    after = lib.mkForce [
      "network.target"
      "mihomo-config.service"
    ];
    restartTriggers = [
      configBeforeProxies
      configAfterProxies
      encryptedProxies
    ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}
