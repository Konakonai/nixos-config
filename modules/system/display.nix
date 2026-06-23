{ pkgs, inputs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  colloidDefault = pkgs.colloid-icon-theme;

  sddmTheme = (pkgs.catppuccin-sddm.override {
    flavor = "latte";
    accent = "blue";
    font = "JetBrains Maple Mono";
    fontSize = "11";
    background = "/etc/sddm-wallpaper.jpg";
  }).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      for f in $out/share/sddm/themes/catppuccin-latte-blue/Components/*.qml; do
        substituteInPlace $f --replace-quiet 'radius: 3' 'radius: 12'
        substituteInPlace $f --replace-quiet 'radius: 5.4' 'radius: 12'
        substituteInPlace $f --replace-quiet 'radius: 5' 'radius: 12'
      done

      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-shutdown-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/power.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-reboot-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/reboot.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/system-suspend-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/sleep.svg
      cp ${colloidDefault}/share/icons/Colloid-Light/actions/symbolic/settings-symbolic.svg $out/share/sddm/themes/catppuccin-latte-blue/icons/settings.svg

      for f in $out/share/sddm/themes/catppuccin-latte-blue/icons/*.svg; do
        substituteInPlace $f --replace-quiet '#363636' '#5e81ac'
        substituteInPlace $f --replace-quiet '#1e66f5' '#5e81ac'
        substituteInPlace $f --replace-quiet 'fill="currentColor"' 'fill="#5e81ac"'
      done
    '';
  });
in
{
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-latte-blue";
    settings.Theme = {
      CursorTheme = lilyaGlass.cursorThemeName;
      CursorSize = "48";
    };
  };

  environment.etc."sddm-wallpaper.jpg".source = ../../assets/sddm-wallpaper.jpg;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  services.gvfs.enable = true;
  services.flatpak.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  environment.systemPackages = [
    sddmTheme
    colloidDefault
  ];
}
