{ pkgs, ... }:

{
  console = {
    earlySetup = true;
    packages = with pkgs; [ terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    colors = [
      "2e3440" "bf616a" "a3be8c" "ebcb8b"
      "81a1c1" "b48ead" "88c0d0" "e5e9f0"
      "4c566a" "bf616a" "a3be8c" "ebcb8b"
      "81a1c1" "b48ead" "8fbcbb" "eceff4"
    ];
  };
}
