{
  config,
  hostProfile,
  ...
}:

# System side of NectarLink (the app itself is in modules/home/apps/desktop.nix).
# Mirrors what upstream's install.sh sets up on other distros.
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

  # 7718/udp: NectarLink's QUIC endpoint, pinned in
  # modules/home/apps/nectarlink.nix (upstream's installer also opens TCP,
  # which nothing listens on). 5353/udp: its own mDNS discovery (no avahi
  # here). LocalSend interop (53317) is already open in networking.nix.
  # Opened on Wi-Fi, not on every interface, for the same reason as the
  # other LAN services there.
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
}
