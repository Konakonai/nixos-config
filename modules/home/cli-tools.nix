{ pkgs, ... }:

{
  home.packages = with pkgs; [
    aria2
    unzip
    zip
    git
    sshfs
    ripgrep
    jq
    python3Packages.ddgs
    nh
    nvd
    paru
    nushell
    trash-cli
    udisks
    ripdrag
    unrar
    _7zz
    p7zip
    pigz

    wl-clipboard
    grim
    slurp
    cliphist
    hyprsunset
    wlsunset
  ];
}
