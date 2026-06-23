{ config, lib, withFcitx, ... }:

let
  zen = lib.getExe config.programs.zen-browser.package;
in
{
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  xdg.configFile."zen/i41yvfec.Default Profile/user.js" = {
    force = true;
    text = ''
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      user_pref("browser.tabs.allow_transparent_browser", false);
      user_pref("widget.wayland.opaque-region.enabled", true);
      user_pref("zen.widget.linux.transparency", false);
    '';
  };

  xdg.desktopEntries."zen-beta" = lib.mkForce {
    name = "Zen Browser (Beta)";
    genericName = "Web Browser";
    comment = "Browse the Web";
    exec = withFcitx "${zen} --name zen-beta %U";
    icon = "zen-browser";
    terminal = false;
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/xml"
      "application/pdf"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/chrome"
    ];
    settings = {
      StartupNotify = "true";
      StartupWMClass = "zen-beta";
    };
    actions = {
      "new-private-window" = {
        name = "New Private Window";
        exec = withFcitx "${zen} --private-window %U";
      };
      "new-window" = {
        name = "New Window";
        exec = withFcitx "${zen} --new-window %U";
      };
      "profile-manager-window" = {
        name = "Profile Manager";
        exec = withFcitx "${zen} --ProfileManager";
      };
    };
  };
}
