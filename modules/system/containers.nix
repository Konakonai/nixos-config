{ pkgs, ... }:

{
  virtualisation.containers = {
    enable = true;
    registries.search = [ "docker.io" ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = [
    pkgs.podman-compose
  ];
}
