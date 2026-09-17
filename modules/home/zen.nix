{
  config,
  hostProfile,
  lib,
  lilyaTheme,
  pkgs,
  ...
}:

let
  zenProfilePath = hostProfile.zen.profilePath;
  zen = lib.getExe config.programs.zen-browser.package;
  zenLaunch = pkgs.writeShellScript "launch-zen-beta" ''
    exec ${zen} "$@"
  '';
in
{
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    profiles.default = {
      id = 0;
      name = "Default Profile";
      # Preserve the existing profile directory and browser data.
      path = zenProfilePath;
      isDefault = true;

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.allow_transparent_browser" = false;
        "widget.wayland.opaque-region.enabled" = true;
        "zen.widget.linux.transparency" = false;

        "font.default.zh-CN" = "sans-serif";
        "font.name.sans-serif.zh-CN" = lilyaTheme.fonts.sans;
        "font.name.serif.zh-CN" = lilyaTheme.fonts.serif;
        "font.name.monospace.zh-CN" = lilyaTheme.fonts.mono;
        "font.name.sans-serif.x-western" = "Noto Sans";
        "font.name.serif.x-western" = "Noto Serif";
        "font.name.monospace.x-western" = lilyaTheme.fonts.mono;

        # Keep Zen from restoring duplicate windows after session/crash handoff.
        "browser.startup.page" = 1;
        "browser.sessionstore.resume_from_crash" = false;
        "browser.sessionstore.resume_session_once" = false;

        # Do not gather host ICE candidates (LAN IPv4 / leftover IPv6 GUAs).
        "network.dns.disableIPv6" = true;
        "media.peerconnection.ice.default_address_only" = true;
        "media.peerconnection.ice.no_host" = true;
      };
    };
  };

  xdg.desktopEntries."zen-beta" = lib.mkForce {
    name = "Zen Browser (Beta)";
    genericName = "Web Browser";
    comment = "Browse the Web";
    exec = "${zenLaunch} %U";
    icon = "zen-browser";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
    ];
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
        exec = "${zenLaunch} --private-window %U";
      };
      "new-window" = {
        name = "New Window";
        exec = "${zenLaunch} --new-window %U";
      };
      "profile-manager-window" = {
        name = "Profile Manager";
        exec = "${zenLaunch} --ProfileManager";
      };
    };
  };

  home.activation.removeZenUserappDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME"/.local/share/applications/userapp-Zen-*.desktop
  '';
}
