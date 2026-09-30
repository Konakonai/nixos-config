{ hostProfile, ... }:

{
  age.identityPaths = [ hostProfile.secrets.identityFile ];

  # NetEase web login (the MUSIC_U cookie) for music-discover, which runs as
  # the user; see modules/home/music-discover.nix. It expires every few months.
  age.secrets.netease-cookie = {
    file = ../../secrets/netease-cookie.age;
    owner = hostProfile.user.userName;
    group = hostProfile.user.group;
    mode = "0400";
  };
}
