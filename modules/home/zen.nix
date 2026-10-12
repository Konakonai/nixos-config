{
  config,
  lib,
  lilyaTheme,
  ...
}:

let
  zen = lib.getExe config.programs.zen-browser.package;
in
{
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    profiles.default = {
      id = 0;
      name = "Default Profile";
      # Preserve the existing profile directory and browser data.
      path = "i41yvfec.Default Profile";
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
    exec = "${zen} %U";
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
        exec = "${zen} --private-window %U";
      };
      "new-window" = {
        name = "New Window";
        exec = "${zen} --new-window %U";
      };
      "profile-manager-window" = {
        name = "Profile Manager";
        exec = "${zen} --ProfileManager";
      };
    };
  };

  # Zen's own "make default browser" prompt writes userapp-Zen-*.desktop
  # entries that shadow the managed launcher and its MIME associations.
  home.activation.removeZenUserappDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME"/.local/share/applications/userapp-Zen-*.desktop
  '';
}
