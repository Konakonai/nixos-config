{ config, pkgs, ... }:

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
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0077";
    };
    script = ''
      set -eu

      if [ ! -r ${proxiesFile} ]; then
        echo "Missing decrypted Mihomo proxy secret: ${proxiesFile}" >&2
        exit 1
      fi

      install -d -m 700 ${runtimeDir}

      tmp="$(mktemp ${runtimeDir}/config.yaml.tmp.XXXXXX)"
      cleanup() {
        rm -f "$tmp"
      }
      trap cleanup EXIT

      {
        cat ${configBeforeProxies}
        cat ${proxiesFile}
        cat ${configAfterProxies}
      } > "$tmp"

      chmod 600 "$tmp"
      mv "$tmp" ${configFile}
      trap - EXIT
    '';
  };

  services.mihomo = {
    enable = true;
    tunMode = true;
    inherit configFile;
    webui = pkgs.metacubexd;
  };
}
