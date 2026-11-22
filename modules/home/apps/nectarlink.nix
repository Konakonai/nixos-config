{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # The decoders (webcam, mirroring) are dlopen()ed, not linked. Upstream's
  # flake adds them to the RUNPATH in preFixup, but fixup's patchelf
  # --shrink-rpath then drops them as unused, so the webcam fails with "no
  # native Linux video decoder". Re-add them after fixup, on the real binary
  # behind the Qt wrapper. ffmpeg_8: the app only knows libavcodec <= 62, and
  # nixpkgs' default ffmpeg 9 ships 63.
  nectarlink =
    inputs.nectarlink.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.patchelf ];
        postFixup = (old.postFixup or "") + ''
          patchelf --add-rpath ${
            lib.makeLibraryPath [
              pkgs.ffmpeg_8
              pkgs.openh264
              pkgs.lame
              pkgs.libxtst
            ]
          } $out/bin/.nectarlink-desktop-wrapped
        '';
      });

  # Same race as Bitwarden: autostart runs in parallel with the shell, so wait
  # for the StatusNotifierWatcher (Noctalia under niri, kded under Plasma)
  # before the app registers its tray icon.
  autostart = pkgs.writeShellApplication {
    name = "nectarlink-autostart";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      for _ in $(seq 60); do
        busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
        sleep 0.5
      done
      exec ${lib.getExe nectarlink} --minimized
    '';
  };
in
{
  home.packages = [ nectarlink ];

  # NectarLink rewrites this entry on every start with its own store path
  # (the unwrapped Qt binary, which lacks the plugin paths). A read-only
  # symlink makes that write fail harmlessly, keeping the PATH launcher.
  xdg.dataFile."applications/nectarlink.desktop" = {
    source = "${nectarlink}/share/applications/nectarlink.desktop";
    force = true;
  };

  # Replaces the app's "Start with computer". That setting writes an XDG
  # autostart entry pinned to one store path, and while it is off (the default
  # for a copy outside /usr or /opt) the app deletes any entry at that path on
  # every start, so a Home Manager-owned autostart file would not survive.
  # Keep the in-app setting off.
  systemd.user.services.nectarlink = {
    Unit = {
      Description = "NectarLink (started once the tray is available)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service.ExecStart = lib.getExe autostart;

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
