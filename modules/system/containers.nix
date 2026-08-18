{ pkgs, ... }:

{
  virtualisation.containers = {
    enable = true;
    registries.settings = {
      unqualified-search-registries = [ "docker.io" ];
    };
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
