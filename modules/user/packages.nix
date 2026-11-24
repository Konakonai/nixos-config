{ inputs, pkgs, ... }:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  python = pkgs.python3.withPackages (
    pythonPackages: with pythonPackages; [
      beautifulsoup4
      ipython
      jupyterlab
      lxml
      matplotlib
      numpy
      openpyxl
      pandas
      pillow
      python-docx
      requests
      rich
      scikit-learn
      scipy
      seaborn
    ]
  );
in
{
  programs.gh.enable = true;

  home.packages = with pkgs; [
    # CLI utilities
    aria2
    zip
    sshfs
    # nixpkgs' primp 2.0.1 fails to build: its vendored zstd-sys probes
    # libzstd via pkg-config, and aws-lc-sys is told to use a system AWS-LC,
    # but the derivation provides none of them. Drop once nixpkgs fixes it.
    (python3Packages.ddgs.override {
      primp = python3Packages.primp.overridePythonAttrs (previous: {
        nativeBuildInputs = previous.nativeBuildInputs ++ [ pkg-config ];
        buildInputs = (previous.buildInputs or [ ]) ++ [
          zstd
          aws-lc
        ];
      });
    })
    nh
    nvd
    lilya.nix-update
    trash-cli
    udisks
    ripdrag
    unrar
    _7zz
    pigz
    ffmpeg-full
    typst
    tinymist
    wl-clipboard
    officecli

    # Dev toolchains
    gcc
    rustup
    go
    nodejs
    python
    lua
    git-lfs
    android-tools
    google-cloud-sdk

    # Browsers
    chromium
    brave-origin

    # Desktop apps without dedicated config modules
    calibre
    file-roller
    foliate
    foot
    gimp
    gnome-font-viewer
    hyprpicker
    jellyfin-desktop
    kdePackages.okular
    lilya.celluloid-gl
    lilya.localsend-no-csd
    loupe
    mcomix
    nemo-with-extensions
    obsidian
    pavucontrol
    resources
    # nixpkgs' cargoSetupHook now sets AWS_LC_SYS_USE_SYSTEM=1, but
    # splayer-next does not provide aws-lc. Drop once nixpkgs fixes it.
    (splayer-next.overrideAttrs (previous: {
      buildInputs = previous.buildInputs ++ [ aws-lc ];
    }))
    thunderbird
    zoom-us
  ];

  # Celluloid / mpv autoload script
  dconf.settings."io/github/celluloid-player/celluloid" = {
    mpv-config-enable = false;
  };
  xdg.configFile = {
    "celluloid/scripts/autoload.lua".source =
      "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";
    "mpv/scripts/autoload.lua".source = "${pkgs.mpvScripts.autoload}/share/mpv/scripts/autoload.lua";
  };

  # Okular: reading defaults for the full-width column niri gives Okular
  # (modules/desktop/niri/default.nix): two pages side by side, scaled to height.
  programs.okular = {
    enable = true;
    package = null;
    general = {
      viewMode = "Facing";
      zoomMode = "fitPage";
      mouseMode = "TextSelect";
    };
  };
  # Paper PDFs carry wide white margins; trimming them enlarges the text.
  programs.plasma.configFile.okularpartrc.PageView.TrimMargins = true;

  # Spotify via Spicetify (installs patched Spotify itself; do not add pkgs.spotify).
  programs.spicetify = {
    enable = true;
    # Native Wayland with text-input-v3 so fcitx5 works in search, in both
    # niri and Plasma (NIXOS_OZONE_WL is only a hint the wrapper may ignore).
    wayland = true;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "latte";
  };
}
