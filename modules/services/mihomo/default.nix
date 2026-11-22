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
    # mihomo drops tun.inet6-address unless a GUA exists when it loads the
    # config. Started on LTE (IPv4 only) it would then keep a v4-only TUN on
    # campus Wi-Fi, where strict-route blackholes all IPv6 until a reload.
    environment.SKIP_SYSTEM_IPV6_CHECK = "1";
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2s";
      # With no default interface every dial fails at once and gets retried,
      # logging ~300 warnings/s (6.5M lines over one offline morning). The
      # journald default (10000/30s) let that fill the 4G journal and evict
      # every earlier boot. Normal operation logs about one line per second.
      LogRateLimitIntervalSec = "30s";
      LogRateLimitBurst = 1000;
    };
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}
