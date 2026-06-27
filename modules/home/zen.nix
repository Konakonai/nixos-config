{ config, hostProfile, lib, pkgs, ... }:

let
  zenProfilePath = hostProfile.zen.profilePath;
  zen = lib.getExe config.programs.zen-browser.package;
  zenLaunch = pkgs.writeShellScript "launch-zen-beta" ''
    profile="$HOME/.config/zen/${zenProfilePath}"

    if ! ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f '/bin/zen-beta( |$)|/lib/zen-bin-[^ ]*/zen( |$)' >/dev/null; then
      rm -f \
        "$profile/sessionstore.jsonlz4" \
        "$profile/sessionstore-backups/recovery.jsonlz4" \
        "$profile/sessionstore-backups/recovery.baklz4" \
        "$profile/sessionstore-backups/previous.jsonlz4" \
        "$profile/zen-sessions.jsonlz4" \
        "$profile/zen-sessions-backup/recovery.baklz4"
    fi

    exec ${zen} --name zen-beta "$@"
  '';
in
{
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

      profiles.default = {
        id = 0;
        name = "Default Profile";
        # This profile id is host state from the existing Zen install. Keep it
        # centralized so the duplicate-window workaround is easy to update.
        path = zenProfilePath;
        isDefault = true;

      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.allow_transparent_browser" = false;
        "widget.wayland.opaque-region.enabled" = true;
        "zen.widget.linux.transparency" = false;

        # Keep Zen from restoring duplicate windows after session/crash handoff.
        "browser.startup.page" = 1;
        "browser.sessionstore.resume_from_crash" = false;
        "browser.sessionstore.resume_session_once" = false;
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
