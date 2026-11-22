{ lib, pkgs, ... }:

let
  # Electron registers its tray icon once, at creation. If the
  # StatusNotifierWatcher (Noctalia under niri, kded under Plasma) is not on
  # the bus yet, it falls back to an XEmbed icon that Wayland never shows and
  # does not retry. Autostart runs in parallel with the shell, so wait for it.
  autostart = pkgs.writeShellApplication {
    name = "bitwarden-autostart";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      for _ in $(seq 60); do
        busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
        sleep 0.5
      done
      exec ${lib.getExe pkgs.bitwarden-desktop} --autostart
    '';
  };
in
{
  home.packages = [ pkgs.bitwarden-desktop ];

  # Replaces Bitwarden's own "Start on login", which writes an autostart entry
  # pinned to one store path; keep that setting off in the app.
  systemd.user.services.bitwarden = {
    Unit = {
      Description = "Bitwarden (started once the tray is available)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service.ExecStart = lib.getExe autostart;

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
