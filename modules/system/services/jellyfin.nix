{ hostProfile, ... }:

{
  # Libraries point at the rclone mount of OpenList (~/Mounts/OpenList), a
  # FUSE mount owned by the user without allow_other, so Jellyfin has to run
  # as that user to see it. Only the local client uses it: the port stays
  # closed on the LAN.
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
}
