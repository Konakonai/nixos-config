{ config, hostProfile, ... }:

let
  encryptedGithubAccessTokenConfig = ../../secrets/nix-github-access-token.conf.age;
in

{
  age.secrets.nix-github-access-token-conf = {
    file = encryptedGithubAccessTokenConfig;
    path = "/run/nix-github-access-token.conf";
    owner = hostProfile.user.userName;
    group = hostProfile.user.group;
    mode = "0400";
    symlink = false;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://niri.cachix.org"
      "https://noctalia.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:WvPHH8MAB75+grGROmO1CwMgxMO47J3AaOEGg3RL0c0="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];

    # mirror.sjtu.edu.cn drops large NAR transfers mid-stream with HTTP/2
    # framing errors; HTTP/1.1 sustains ~2 MB/s without resets.
    http2 = false;
    # Fail fast on hung mirrors/streams instead of blocking 300s per path.
    connect-timeout = 10;
    stalled-download-timeout = 30;
  };

  # Fixed-output `fetchurl` builders read NIX_CURL_FLAGS from nix-daemon's
  # environment: avoid HTTP/2 stream resets (e.g. oaistatic.com) and abort
  # throttled TCP connections so `curl --retry --continue-at -` recovers.
  systemd.services.nix-daemon.environment.NIX_CURL_FLAGS =
    "--http1.1 --speed-time 30 --speed-limit 10240";

  nix.extraOptions = ''
    !include ${config.age.secrets.nix-github-access-token-conf.path}
  '';

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise.automatic = true;
  nixpkgs.config.allowUnfree = true;
}
