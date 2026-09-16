{ fetchurl, xwayland-satellite }:

xwayland-satellite.overrideAttrs (old: {
  # Upstream PR #494 (add2795134593faafce60e404a0a75df68e9ee0c).
  # Keep Steam's override-redirect menus from stealing focus and closing.
  patches = (old.patches or [ ]) ++ [
    (fetchurl {
      url = "https://github.com/Supreeeme/xwayland-satellite/commit/add2795134593faafce60e404a0a75df68e9ee0c.patch";
      hash = "sha256-XD93f8m8h0o0Vs3QcmWkHGGi5mZwf9wkx9qEiq6sjnw=";
    })
    # Xwayland set_input_region is in buffer pixels; niri's surface is logical.
    ../patches/xwayland-satellite-scale-input-region.patch
  ];
})
