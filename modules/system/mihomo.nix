{ pkgs, ... }:

let
  configDir = "/home/lilya/.config/mihomo";
  configFile = "${configDir}/config.yaml";
  identityFile = "/home/lilya/.config/age/mihomo.txt";
  configBeforeProxies = ./mihomo/config-before-proxies.yaml;
  configAfterProxies = ./mihomo/config-after-proxies.yaml;
  encryptedProxies = ../../secrets/mihomo-proxies.yaml.age;
in
{
  system.activationScripts.mihomoConfig = ''
    set -eu
    tmp=""
    cleanup() {
      if [ -n "$tmp" ]; then
        rm -f "$tmp"
      fi
    }
    trap cleanup EXIT

    install -d -m 700 -o lilya -g users ${configDir}

    if [ ! -r ${identityFile} ]; then
      echo "Missing mihomo age identity: ${identityFile}" >&2
      exit 1
    fi

    tmp="$(mktemp ${configDir}/config.yaml.tmp.XXXXXX)"
    {
      cat ${configBeforeProxies}
      ${pkgs.age}/bin/age --decrypt --identity ${identityFile} ${encryptedProxies}
      cat ${configAfterProxies}
    } > "$tmp"

    chown lilya:users "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" ${configFile}
    tmp=""
  '';

  services.mihomo = {
    enable = true;
    tunMode = true;
    inherit configFile;
    webui = pkgs.metacubexd;
  };
}
