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
  configBeforeProxies = ./config-before-proxies.yaml;
  configAfterProxies = ./config-after-proxies.yaml;
  encryptedProxies = ../../../secrets/mihomo-proxies.yaml.age;
  # LoadCredential copies config.yaml at start, so a fragment change must
  # regenerate the file and then restart the proxy.
  restartTriggers = [
    configBeforeProxies
    configAfterProxies
    encryptedProxies
  ];
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
    inherit restartTriggers;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      bash ${../../../scripts/generate-mihomo-config.sh} \
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
  # heuristic.
  systemd.services.mihomo = {
    requires = lib.mkForce [ "mihomo-config.service" ];
    after = lib.mkForce [
      "network.target"
      "mihomo-config.service"
    ];
    inherit restartTriggers;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}
