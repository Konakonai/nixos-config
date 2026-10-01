{ ... }:

{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # LDAC defaults to adaptive bitrate, which can silently drop to 330 kbps;
    # pin it to 990 kbps so LDAC always runs at full quality.
    wireplumber.extraConfig."51-ldac-hq" = {
      "monitor.bluez.rules" = [
        {
          matches = [ { "device.name" = "~bluez_card.*"; } ];
          actions.update-props."bluez5.a2dp.ldac.quality" = "hq";
        }
      ];
    };
  };
}
