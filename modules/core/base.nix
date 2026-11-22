{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  askPass = lib.getExe' pkgs.kdePackages.ksshaskpass "ksshaskpass";
in
{
  # Secrets identity root for agenix.
  age.identityPaths = [ hostProfile.secrets.identityFile ];

  # User & privilege model.
  users.users.${hostProfile.user.userName} = {
    isNormalUser = true;
    description = hostProfile.user.userName;
    shell = pkgs.fish;

    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
    ];
  };

  security.sudo.extraConfig = "Defaults pwfeedback";
  # Single-user machine; lets agents rebuild and read root-only debug state
  # (RAPL, i915 debugfs, turbostat) without a password prompt.
  security.sudo.wheelNeedsPassword = false;

  # Home Manager activation already runs synchronously during every rebuild.
  # Reconcile the persisted generation after logins are enabled instead of
  # holding SDDM on the boot-critical path.
  systemd.services."home-manager-${hostProfile.user.userName}" = {
    before = lib.mkForce [ ];
    after = lib.mkAfter [ "systemd-user-sessions.service" ];
  };

  # Timezone & locale.
  time.timeZone = "Asia/Taipei";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  i18n.supportedLocales = [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  # Memory (zram).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  # Audio (PipeWire + full-bitrate LDAC).
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

  # Printing.
  services.printing.enable = true;

  # Base shell, editor, and git/ssh helpers.
  programs.fish.enable = true;
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };
  programs.ssh.askPassword = askPass;

  environment.variables = {
    GIT_ASKPASS = askPass;
    # Applications that bundle their own git binary (editors, agents) still
    # resolve helpers such as git-remote-https from the system git-core.
    GIT_EXEC_PATH = "${pkgs.git}/libexec/git-core";
  };

  # Core system utilities.
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    pciutils
    usbutils
    ripgrep
    fd
    jq
    tree
    unzip
    killall
    btop
    fastfetch
    bubblewrap
    imagemagick
    kdePackages.ksshaskpass
  ];
}
