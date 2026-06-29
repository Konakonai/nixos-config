{ pkgs, inputs, hostProfile, lib, ... }:

let
  lilyaGlass = import ../../glass-settings.nix;
  internalDisplay = hostProfile.display.internal;
  externalDisplay = hostProfile.display.external or null;
  loginWallpaper = hostProfile.display.loginWallpaper or null;

  niriBasePackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  niriPackage = niriBasePackage.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../../../patches/niri-linear-cross-gpu-output-buffers.patch
    ];
  });
  niriSession = "${niriPackage}/bin/niri-session";
  mkNiriLogin = name: configPath: pkgs.writeShellScriptBin name ''
    unset GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME

    export NIRI_CONFIG="${configPath}"
    exec ${niriSession} "$@"
  '';
  niriLogin = mkNiriLogin "Niri" "$HOME/.config/niri/config-intel.kdl";
  niriNvidiaLogin = mkNiriLogin "Niri-NVIDIA" "$HOME/.config/niri/config-nvidia.kdl";
  niriLoginPath = lib.getExe niriLogin;
  niriNvidiaLoginPath = lib.getExe niriNvidiaLogin;
  gtkgreetGtkThemeName = "adw-gtk3";
  gtkgreetGtkThemePackage = pkgs.adw-gtk3;
  gtkgreetFontSize = 18;
  gtkgreetClockFocusedSize = 64000;
  gtkgreetClockIdleSize = 96000;
  gtkgreetCardWidth = 560;
  gtkgreetCardPadding = 28;
  gtkgreetControlHeight = 46;
  kdlString = builtins.toJSON;
  outputName = display: "${display.make} ${display.model} ${display.serial}";
  greeterOutput = display: focusAtStartup: ''
    output ${kdlString (outputName display)} {
        scale ${builtins.toString display.scale}
        ${lib.optionalString focusAtStartup "focus-at-startup"}
        transform "normal"
        position x=${builtins.toString display.position.x} y=${builtins.toString display.position.y}
        background-color ${kdlString lilyaGlass.palette.base}
    }
  '';
  externalGreeterOutput = lib.optionalString (externalDisplay != null) (
    greeterOutput externalDisplay true
  );

  gtkgreet = pkgs.gtkgreet.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      # Keep the focused-screen clock legible after gtkgreet opens the login form.
      substituteInPlace gtkgreet/window.c \
        --replace-fail "size = 96000;" "size = ${builtins.toString gtkgreetClockIdleSize};" \
        --replace-fail "size = 32000;" "size = ${builtins.toString gtkgreetClockFocusedSize};"
      # Center the form contents inside the card instead of right-aligning every row.
      substituteInPlace gtkgreet/window.c \
        --replace-fail "GTK_ALIGN_END" "GTK_ALIGN_CENTER"
      # Drop username/password prompt labels so input rows line up with the session selector.
      substituteInPlace gtkgreet/window.c \
        --replace-fail 'GtkWidget *label = gtk_label_new(question);
            gtk_widget_set_halign(label, GTK_ALIGN_CENTER);
            gtk_container_add(GTK_CONTAINER(question_box), label);

            ctx->input_field = gtk_entry_new();' 'ctx->input_field = gtk_entry_new();'
      # Show friendly command names while keeping the full command as selected value.
      substituteInPlace gtkgreet/config.c \
        --replace-fail '#include <stdio.h>' '#include <stdio.h>
#include <string.h>' \
        --replace-fail 'int config_update_command_selector(GtkWidget *combobox) {' 'static const char *display_command(const char *command) {
    const char *base = strrchr(command, '"'"'/'"'"');
    return base == NULL ? command : base + 1;
}

int config_update_command_selector(GtkWidget *combobox) {' \
        --replace-fail 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, NULL, gtkgreet->command);' 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, gtkgreet->command, display_command(gtkgreet->command));' \
        --replace-fail 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, NULL, buffer);' 'gtk_combo_box_text_append((GtkComboBoxText*)combobox, buffer, display_command(buffer));'
      substituteInPlace gtkgreet/actions.c \
        --replace-fail 'gtkgreet->selected_command = strdup(gtk_combo_box_text_get_active_text((GtkComboBoxText*)ctx->command_selector));' 'const gchar *command_id = gtk_combo_box_get_active_id((GtkComboBox*)ctx->command_selector);
            gtkgreet->selected_command = strdup(command_id == NULL ? gtk_combo_box_text_get_active_text((GtkComboBoxText*)ctx->command_selector) : command_id);'
    '';
  });

  gtkgreetCss = pkgs.writeText "gtkgreet.css" ''
    @define-color accent_color #5e81ac;
    @define-color accent_bg_color #5e81ac;
    @define-color accent_fg_color #eceff4;
    @define-color window_bg_color #eceff4;
    @define-color window_fg_color #2e3440;
    @define-color card_bg_color #e5e9f0;
    @define-color card_fg_color #2e3440;
    @define-color border_color #d8dee9;
    @define-color muted_fg_color #4c566a;
    @define-color shadow_color #2e3440;

    window,
    #window {
      background-color: transparent;
      color: @window_fg_color;
      font-family: "${lilyaGlass.fonts.sans}";
      font-size: ${builtins.toString gtkgreetFontSize}px;
    }

    #clock {
      color: @accent_fg_color;
      font-weight: 600;
      margin-bottom: 18px;
      text-shadow: 0 2px 8px alpha(@shadow_color, 0.40);
    }

    box#body {
      background-color: alpha(@card_bg_color, 0.76);
      border: 1px solid alpha(@window_bg_color, 0.52);
      border-radius: ${builtins.toString lilyaGlass.radius.panels}px;
      box-shadow: 0 18px 55px alpha(@shadow_color, 0.24);
      padding: ${builtins.toString gtkgreetCardPadding}px;
      min-width: ${builtins.toString gtkgreetCardWidth}px;
    }

    label {
      color: @card_fg_color;
    }

    button {
      background-color: @accent_bg_color;
      border: 1px solid @accent_bg_color;
      border-radius: ${builtins.toString lilyaGlass.radius.windows}px;
      color: @accent_fg_color;
      min-height: ${builtins.toString gtkgreetControlHeight}px;
      padding: 8px 16px;
    }

    button:hover {
      background-color: #6b8db6;
      border-color: #6b8db6;
    }

    entry,
    #command-selector entry {
      background-color: alpha(@window_bg_color, 0.78);
      border: 1px solid alpha(@border_color, 0.92);
      border-radius: ${builtins.toString lilyaGlass.radius.windows}px;
      color: @window_fg_color;
      min-height: ${builtins.toString gtkgreetControlHeight}px;
      padding: 8px 12px;
    }

    entry:focus,
    #command-selector entry:focus {
      border-color: @accent_color;
      box-shadow: 0 0 0 2px alpha(@accent_color, 0.18);
    }

    #command-selector {
      color: @muted_fg_color;
    }
  '';

  gtkgreetCommand = pkgs.writeShellScript "gtkgreet-command" ''
    ${lib.optionalString (loginWallpaper != null) ''
      ${lib.getExe pkgs.swaybg} -i ${loginWallpaper} -m fill &
      wallpaper_pid=$!
      trap 'kill "$wallpaper_pid" >/dev/null 2>&1 || true' EXIT
    ''}

    ${lib.getExe gtkgreet} -l -s ${gtkgreetCss} -c ${lib.escapeShellArg niriLoginPath}
    ${niriPackage}/bin/niri msg action quit --skip-confirmation
  '';

  gtkgreetNiriConfig = pkgs.writeText "gtkgreet-niri-config.kdl" ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }

        touchpad {
            tap
            natural-scroll
        }
    }

    output "*" {
        scale ${builtins.toString internalDisplay.scale}
        transform "normal"
        background-color ${kdlString lilyaGlass.palette.base}
    }

    ${greeterOutput internalDisplay false}
    ${externalGreeterOutput}

    cursor {
        xcursor-theme ${kdlString lilyaGlass.cursorThemeName}
        xcursor-size 48
    }

    hotkey-overlay { skip-at-startup; }

    environment {
        "GDK_DEBUG" "no-portals"
        "GTK_USE_PORTAL" "0"
        "XCURSOR_SIZE" "48"
        "XCURSOR_THEME" ${kdlString lilyaGlass.cursorThemeName}
    }

    layout {
        gaps 0
        center-focused-column "always"
        default-column-width { proportion 1.000000; }
        focus-ring { off; }
        border { off; }
        shadow { off; }
        background-color "transparent"
    }

    prefer-no-csd
    spawn-at-startup ${kdlString "${gtkgreetCommand}"}
  '';

  gtkgreetSession = pkgs.writeShellScript "gtkgreet-session" ''
    export GTK_THEME=${gtkgreetGtkThemeName}
    export XCURSOR_THEME=${lib.escapeShellArg lilyaGlass.cursorThemeName}
    export XCURSOR_SIZE=48
    export XDG_DATA_DIRS=${gtkgreetGtkThemePackage}/share:${pkgs.colloid-icon-theme}/share:${pkgs.nordzy-cursor-theme}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}

    exec ${pkgs.dbus}/bin/dbus-run-session ${niriPackage}/bin/niri -c ${gtkgreetNiriConfig}
  '';
in
{
  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  systemd.user.units."niri.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      UnsetEnvironment=GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME
    '';
  };

  services.greetd = {
    enable = true;
    useTextGreeter = false;
    settings.default_session = {
      command = "${gtkgreetSession}";
      user = "greeter";
    };
  };

  environment.etc."greetd/environments".text = ''
    ${niriLoginPath}
    ${niriNvidiaLoginPath}
  '';
}
