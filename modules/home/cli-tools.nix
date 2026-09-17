{ pkgs, ... }:

{
  home.packages = with pkgs; [
    aria2
    zip
    sshfs
    python3Packages.ddgs
    nh
    nvd
    nushell
    trash-cli
    udisks
    ripdrag
    unrar
    _7zz
    pigz
    ffmpeg-full
    typst
    tinymist

    wl-clipboard
    hyprsunset
    wlsunset

    lilya.grok
  ];
}
