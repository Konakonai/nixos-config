{ pkgs, ... }:

{
  home.packages = with pkgs; [
    aria2
    zip
    sshfs
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
    pigz

    wl-clipboard
    grim
    slurp
    cliphist
    hyprsunset
    wlsunset
  ];
}
