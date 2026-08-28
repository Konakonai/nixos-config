{ config, lib, pkgs, ... }:

let
  palette =
    (builtins.fromJSON (
      builtins.readFile ../../../assets/noctalia/palettes/catppuccin-lavender-glass.json
    )).light;
  themeRelativePath = "pear-desktop/catppuccin-lavender-glass.css";
  themePath = "${config.xdg.configHome}/${themeRelativePath}";
  pearConfig = "${config.xdg.configHome}/YouTube Music/config.json";
  pearTheme = pkgs.writeText "pear-catppuccin-lavender-glass.css" ''
    /*
     * Catppuccin Lavender Glass light theme for Pear Desktop.
     * Keep the palette tied to Noctalia's current custom palette while
     * overriding both YouTube Music and Pear's injected MDUI controls.
     */
    :root,
    html,
    html.mdui-theme-dark {
      color-scheme: light !important;

      --pear-bg: ${palette.mSurface};
      --pear-surface: ${palette.mSurfaceVariant};
      --pear-text: ${palette.mOnSurface};
      --pear-subtext: ${palette.mOnSurfaceVariant};
      --pear-primary: ${palette.mPrimary};
      --pear-secondary: ${palette.mSecondary};
      --pear-tertiary: ${palette.mTertiary};
      --pear-outline: ${palette.mOutline};
      --pear-hover: ${palette.mHover};

      --ytmusic-color-black1: var(--pear-bg) !important;
      --ytmusic-color-black2: var(--pear-surface) !important;
      --ytmusic-color-black3: var(--pear-surface) !important;
      --ytmusic-color-black4: var(--pear-bg) !important;
      --ytmusic-color-blackpure: var(--pear-text) !important;
      --ytmusic-color-blackpure-alpha0: transparent !important;
      --ytmusic-color-blackpure-alpha10: rgb(44 36 62 / 0.08) !important;
      --ytmusic-color-blackpure-alpha60: rgb(44 36 62 / 0.35) !important;
      --ytmusic-color-white1: var(--pear-text) !important;
      --ytmusic-color-white1-alpha10: rgb(44 36 62 / 0.08) !important;
      --ytmusic-color-white1-alpha15: rgb(44 36 62 / 0.12) !important;
      --ytmusic-color-white1-alpha20: rgb(44 36 62 / 0.16) !important;
      --ytmusic-color-white1-alpha30: rgb(44 36 62 / 0.22) !important;
      --ytmusic-color-white1-alpha50: rgb(44 36 62 / 0.42) !important;
      --ytmusic-color-white1-alpha70: var(--pear-subtext) !important;
      --ytmusic-color-grey1: var(--pear-text) !important;
      --ytmusic-color-grey2: var(--pear-subtext) !important;
      --ytmusic-color-grey3: var(--pear-subtext) !important;
      --ytmusic-color-grey4: var(--pear-outline) !important;
      --ytmusic-color-grey5: var(--pear-surface) !important;
      --ytmusic-static-brand-red: var(--pear-tertiary) !important;
      --ytmusic-brand-link-text: var(--pear-primary) !important;
      --ytmusic-setting-item-toggle-active: var(--pear-primary) !important;
      --ytmusic-dialog-background-color: var(--pear-bg) !important;
      --ytmusic-detail-header: var(--pear-bg) !important;

      --yt-spec-base-background: var(--pear-bg) !important;
      --yt-spec-raised-background: var(--pear-surface) !important;
      --yt-spec-menu-background: var(--pear-bg) !important;
      --yt-spec-general-background-a: var(--pear-bg) !important;
      --yt-spec-general-background-b: var(--pear-surface) !important;
      --yt-spec-general-background-c: var(--pear-hover) !important;
      --yt-spec-text-primary: var(--pear-text) !important;
      --yt-spec-text-secondary: var(--pear-subtext) !important;
      --yt-spec-brand-link-text: var(--pear-primary) !important;
      --yt-spec-call-to-action: var(--pear-primary) !important;
      --yt-spec-touch-response: rgb(124 92 250 / 0.12) !important;

      --mdui-color-primary-dark: 124, 92, 250;
      --mdui-color-primary-container-dark: 229, 223, 252;
      --mdui-color-on-primary-dark: 255, 255, 255;
      --mdui-color-on-primary-container-dark: 44, 36, 62;
      --mdui-color-secondary-dark: 162, 136, 255;
      --mdui-color-secondary-container-dark: 240, 237, 252;
      --mdui-color-on-secondary-dark: 255, 255, 255;
      --mdui-color-on-secondary-container-dark: 44, 36, 62;
      --mdui-color-tertiary-dark: 234, 118, 203;
      --mdui-color-tertiary-container-dark: 240, 237, 252;
      --mdui-color-on-tertiary-dark: 255, 255, 255;
      --mdui-color-on-tertiary-container-dark: 44, 36, 62;
      --mdui-color-surface-dark: 250, 248, 255;
      --mdui-color-surface-dim-dark: 240, 237, 252;
      --mdui-color-surface-bright-dark: 250, 248, 255;
      --mdui-color-surface-container-lowest-dark: 255, 255, 255;
      --mdui-color-surface-container-low-dark: 250, 248, 255;
      --mdui-color-surface-container-dark: 240, 237, 252;
      --mdui-color-surface-container-high-dark: 229, 223, 252;
      --mdui-color-surface-container-highest-dark: 228, 222, 250;
      --mdui-color-surface-variant-dark: 240, 237, 252;
      --mdui-color-on-surface-dark: 44, 36, 62;
      --mdui-color-on-surface-variant-dark: 104, 93, 130;
      --mdui-color-background-dark: 250, 248, 255;
      --mdui-color-on-background-dark: 44, 36, 62;
      --mdui-color-error-dark: 229, 72, 77;
      --mdui-color-on-error-dark: 255, 255, 255;
      --mdui-color-outline-dark: 216, 208, 244;
      --mdui-color-outline-variant-dark: 228, 222, 250;
      --mdui-color-shadow-dark: 228, 222, 250;
      --mdui-color-surface-tint-color-dark: 124, 92, 250;
    }

    html,
    body,
    ytmusic-app,
    ytmusic-app-layout,
    ytmusic-browse-response,
    ytmusic-player-page,
    ytmusic-section-list-renderer,
    ytmusic-tab-renderer,
    #content,
    #layout,
    #main-panel,
    #guide-wrapper {
      background: var(--pear-bg) !important;
      color: var(--pear-text) !important;
    }

    ytmusic-nav-bar,
    ytmusic-player-bar,
    ytmusic-data-bound-header-renderer,
    ytmusic-detail-header-renderer,
    ytmusic-player-queue,
    tp-yt-paper-dialog,
    tp-yt-paper-listbox,
    tp-yt-paper-menu-button,
    #guide-content,
    #mini-guide-background {
      background-color: var(--pear-bg) !important;
      color: var(--pear-text) !important;
      border-color: var(--pear-outline) !important;
    }

    ytmusic-responsive-list-item-renderer,
    ytmusic-player-queue-item,
    ytmusic-menu-service-item-renderer,
    ytmusic-toggle-menu-service-item-renderer,
    ytmusic-chip-cloud-chip-renderer,
    yt-chip-cloud-chip-renderer,
    tp-yt-paper-item {
      color: var(--pear-text) !important;
    }

    ytmusic-responsive-list-item-renderer:hover,
    ytmusic-player-queue-item:hover,
    ytmusic-menu-service-item-renderer:hover,
    ytmusic-toggle-menu-service-item-renderer:hover,
    tp-yt-paper-item:hover,
    yt-chip-cloud-chip-renderer:hover,
    ytmusic-chip-cloud-chip-renderer:hover {
      background-color: var(--pear-hover) !important;
    }

    yt-formatted-string,
    .title,
    .headline,
    .song-title,
    .content-info-wrapper,
    .tab-content,
    .yt-spec-button-shape-next__button-text-content {
      color: var(--pear-text) !important;
    }

    .subtitle,
    .byline,
    .secondary-flex-columns,
    .description,
    .metadata,
    .duration,
    .subtitle-container {
      color: var(--pear-subtext) !important;
    }

    ytmusic-pivot-bar-item-renderer,
    ytmusic-search-box,
    yt-icon,
    .icon,
    .material-icons {
      color: var(--pear-subtext) !important;
      fill: currentColor !important;
    }

    ytmusic-pivot-bar-item-renderer.iron-selected,
    ytmusic-pivot-bar-item-renderer:hover,
    ytmusic-search-box:focus-within,
    button:hover yt-icon,
    .icon:hover {
      color: var(--pear-primary) !important;
    }

    #progress-bar,
    #volume-slider,
    tp-yt-paper-slider {
      --paper-slider-active-color: var(--pear-primary) !important;
      --paper-slider-knob-color: var(--pear-primary) !important;
      --paper-slider-container-color: var(--pear-outline) !important;
    }

    input,
    textarea,
    ytmusic-search-box,
    .search-box {
      background-color: var(--pear-surface) !important;
      color: var(--pear-text) !important;
      border-color: var(--pear-outline) !important;
    }

    ::selection {
      background: var(--pear-hover);
      color: var(--pear-text);
    }

    ::-webkit-scrollbar-thumb {
      background: var(--pear-outline) !important;
      border-radius: 999px;
    }

    ::-webkit-scrollbar-track {
      background: var(--pear-bg) !important;
    }
  '';
  initialPearConfig = builtins.toJSON {
    options = {
      tray = false;
      appVisible = true;
      autoUpdates = false;
      alwaysOnTop = false;
      hideMenu = false;
      hideMenuWarned = false;
      startAtLogin = false;
      disableHardwareAcceleration = false;
      removeUpgradeButton = false;
      restartOnConfigChanges = false;
      trayClickPlayPause = false;
      autoResetAppCache = false;
      resumeOnStart = true;
      likeButtons = "";
      swapLikeButtonsOrder = false;
      proxy = "";
      startingPage = "";
      overrideUserAgent = false;
      usePodcastParticipantAsArtist = false;
      themes = [ themePath ];
    };
  };
in
{
  home.packages = [ pkgs.pear-desktop ];

  xdg.configFile.${themeRelativePath}.source = pearTheme;

  # Pear stores its preferences in electron-store rather than exposing a Nix
  # option. Seed only its documented defaults on first install; afterward keep
  # user-owned settings intact and ensure the managed light theme stays loaded.
  home.activation.configurePearLightTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_file=${lib.escapeShellArg pearConfig}
    theme_path=${lib.escapeShellArg themePath}
    config_dir="$(${pkgs.coreutils}/bin/dirname "$config_file")"

    ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
    if [ ! -e "$config_file" ]; then
      ${pkgs.coreutils}/bin/install -Dm600 \
        ${pkgs.writeText "pear-initial-config.json" initialPearConfig} \
        "$config_file"
    else
      temp_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/config.json.XXXXXX")"
      ${pkgs.jq}/bin/jq --arg theme "$theme_path" '
        .options = (.options // {})
        | .options.autoUpdates = false
        | .options.themes = (((.options.themes // []) | map(select(. != $theme))) + [$theme])
      ' "$config_file" > "$temp_file"
      ${pkgs.coreutils}/bin/chmod 600 "$temp_file"
      ${pkgs.coreutils}/bin/mv "$temp_file" "$config_file"
    fi
  '';
}
