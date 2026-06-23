{ pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  fonts = {
    fontDir.enable = true;

    packages = with pkgs; [
      maple-mono."Normal-NF"

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji

      source-han-sans
      source-han-serif
      sarasa-gothic
    ];

    fontconfig.defaultFonts = {
      monospace = [
        lilyaGlass.fonts.mono
        "Noto Sans Mono CJK SC"
      ];

      sansSerif = [
        lilyaGlass.fonts.sans
        "Noto Sans"
      ];

      serif = [
        lilyaGlass.fonts.serif
        "Noto Serif"
      ];

      emoji = [
        "Noto Color Emoji"
      ];
    };
  };
}
