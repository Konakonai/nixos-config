{
  config,
  hostProfile,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # ffmpeg 8 without NVIDIA support. 8: h264.rs only knows libavcodec <= 62
  # (nixpkgs' default ffmpeg 9 ships 63), and linux_video_codec.cpp (hardware
  # encode/decode) dlopen()s the major of the headers it was compiled
  # against, so ffmpeg 9 headers made it look for .so.63 and fall back to
  # software. No NVIDIA: with it the hardware decoder picks CUDA first and its
  # startup HEVC probe keeps the dGPU awake (on battery too); VA-API on the
  # iGPU (LIBVA_DRIVER_NAME=iHD) stays the only hardware path.
  ffmpeg = pkgs.ffmpeg_8.override {
    withCuda = false;
    withCudaLLVM = false;
    withNvcodec = false;
    withNvdec = false;
    withNvenc = false;
  };
  # The decoders (webcam, mirroring) are dlopen()ed, not linked. Upstream's
  # flake adds them to the RUNPATH in preFixup, but fixup's patchelf
  # --shrink-rpath then drops them as unused, so the webcam fails with "no
  # native Linux video decoder". Re-add them after fixup, on the real binary
  # behind the Qt wrapper, and build against the same ffmpeg. The RUNPATH
  # part can go once upstream PR thtbee/nectarlink#512 is in.
  nectarlink =
    inputs.nectarlink.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
      (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.patchelf ];
        buildInputs = map (p: if p == pkgs.ffmpeg then ffmpeg else p) old.buildInputs;
        postFixup = (old.postFixup or "") + ''
          patchelf --add-rpath ${
            lib.makeLibraryPath [
              ffmpeg
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
  # Phone as webcam: the app feeds frames into a v4l2loopback device.
  # exclusive_caps=1 makes browsers and Zoom list it as a capture-only camera.
  boot = {
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    kernelModules = [ "v4l2loopback" ];
    extraModprobeConfig = ''
      options v4l2loopback exclusive_caps=1 card_label="NectarLink Webcam"
    '';
  };

  # Phone as keyboard and mouse writes to /dev/uinput; without it the app
  # falls back to the RemoteDesktop portal, which niri does not implement.
  hardware.uinput.enable = true;
  users.users.${hostProfile.user.userName}.extraGroups = [ "uinput" ];

  # 7718/udp: NectarLink's QUIC endpoint, pinned below (upstream's installer
  # also opens TCP, which nothing listens on). 5353/udp: its own mDNS discovery
  # (no avahi here). LocalSend interop (53317) is already open in networking.nix.
  # Opened on Wi-Fi, not on every interface, for the same reason as the other
  # LAN services there.
  #
  # Also on tailscale0: NectarLink treats tailnet addresses as local, so the
  # phone reaches the PC directly through Tailscale away from home, with
  # "Connect over mobile data" (iroh relays) left off. mDNS does not cross
  # the tailnet; the address comes from pairing or a session on the LAN.
  networking.firewall.interfaces = {
    wlp0s20f3 = {
      allowedUDPPorts = [
        5353
        7718
      ];
    };
    tailscale0.allowedUDPPorts = [ 7718 ];
  };

  home-manager.users.${hostProfile.user.userName} = {
    home.packages = [ nectarlink ];

    # NectarLink rewrites this entry on every start with its own store path
    # (the unwrapped Qt binary, which lacks the plugin paths). A read-only
    # symlink makes that write fail harmlessly, keeping the PATH launcher.
    xdg.dataFile."applications/nectarlink.desktop" = {
      source = "${nectarlink}/share/applications/nectarlink.desktop";
      force = true;
    };

    # The QUIC endpoint takes a random UDP port on first start and keeps it in
    # this file (the core only binds a fixed port when embedders set one; the
    # desktop app never does). Pin it so the firewall rules above match.
    # Read-only: if 7718 is ever taken, the app binds another port and only
    # fails to save it.
    xdg.dataFile."Nectarlink/port" = {
      text = "7718";
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
  };
}
