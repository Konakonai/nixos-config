{ hostProfile, ... }:

{
  # Libraries point at the rclone mount of OpenList (~/Mounts/OpenList), a
  # FUSE mount owned by the user without allow_other, so Jellyfin has to run
  # as that user to see it. The port is opened for the phone in
  # networking.nix, on the Wi-Fi interface only.
  #
  # Scanning over the mount pulls real data from Quark, so real-time
  # monitoring, chapter images and trickplay are turned off in the dashboard
  # (runtime state in /var/lib/jellyfin, see README).
  services.jellyfin = {
    enable = true;
    user = hostProfile.user.userName;
    inherit (hostProfile.user) group;
    openFirewall = false;
  };

  # The module already forbids privilege escalation. Jellyfin listens on the
  # Wi-Fi and the tailnet as the login user, so also keep it away from the
  # rest of that account: home is read-only (it only reads the library mount
  # there), /run/user is hidden because the user bus would let it start a
  # process outside this sandbox, and the credential stores are hidden. The
  # last part is a denylist; anything else under $HOME stays readable.
  systemd.services.jellyfin.serviceConfig = {
    ProtectHome = "read-only";
    InaccessiblePaths = [
      "-/run/user"
    ]
    ++ map (path: "-${hostProfile.user.homeDirectory}/${path}") [
      ".ssh"
      ".gnupg"
      ".config/age"
      ".config/rclone"
      ".config/openlist"
    ];
  };
}
