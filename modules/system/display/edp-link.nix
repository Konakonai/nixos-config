{ hostProfile, pkgs, ... }:

let
  inherit (hostProfile.display.internal) link;
  debugfs = "/sys/kernel/debug/dri/${link.drmDevice}/${link.connector}";

  # The panel reports seamless DRRS, so i915 sizes the eDP link for the
  # 165 Hz mode's pixel clock even at 60 Hz: HBR3 x4 with the pipe cut to
  # 18 bpp (6 bpc + dither). Capping the link makes i915 fall back to DSC
  # instead (10 bpc in, 8 bpp on the wire), which both restores 10-bit color
  # and measured 0.4 W less at idle on battery (4 interleaved rounds, 0.33 W of
  # it in the package). The debugfs knobs persist until reboot and apply to
  # every later link training, including niri's modesets and lid reopen.
  # The 165 Hz mode does not fit this link; drop this module to use it.
  applyLink = pkgs.writeShellScript "edp-link" ''
    set -u
    for _ in $(seq 30); do
      [ -w ${debugfs}/i915_dp_force_lane_count ] && break
      sleep 1
    done
    if [ ! -w ${debugfs}/i915_dp_force_lane_count ]; then
      echo "${debugfs} not available; leaving the eDP link alone"
      exit 0
    fi
    echo ${toString link.rate} > ${debugfs}/i915_dp_force_link_rate
    echo ${toString link.lanes} > ${debugfs}/i915_dp_force_lane_count
    # Retraining fails harmlessly while the pipe is off; the next modeset
    # picks up the forced parameters anyway.
    echo 1 > ${debugfs}/i915_dp_force_link_retrain 2>/dev/null || true
    echo "eDP link limited to ${toString link.rate} kHz x ${toString link.lanes}"
  '';
in
{
  systemd.services.edp-link = {
    description = "Train the internal eDP link at the narrowest config the panel mode needs";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = applyLink;
    };
  };
}
