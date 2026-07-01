{ pkgs, ... }:

let
  touhouGrubTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "grub-theme-touhou-project";
    version = "2023-04-19";

    src = pkgs.fetchzip {
      url = "https://github.com/13atm01/GRUB-Theme/releases/download/Tproject-v1.0/Touhou_Project.tar.gz";
      hash = "sha256-GcB4Drad77Ndd9LnNA+ZHzjnE4Rm+IwP9FDKLQodxTo=";
      stripRoot = false;
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p "$out"
      cp -r "$src/Touhou Project/Touhou-project/." "$out/"
      test -f "$out/theme.txt"

      substituteInPlace "$out/theme.txt" \
        --replace-fail 'message-font: "Terminus Regular Bold 14"' 'message-font: "DejaVu Sans Regular 24"' \
        --replace-fail '    left = 18%' '    left = 16%' \
        --replace-fail '    top = 22%' '    top = 20%' \
        --replace-fail '    width = 60%' '    width = 62%' \
        --replace-fail '    height = 60%' '    height = 62%' \
        --replace-fail '    item_font = "Terminus Regular Bold 14"' '    item_font = "DejaVu Sans Regular 24"' \
        --replace-fail '    icon_width = 32' '    icon_width = 48' \
        --replace-fail '    icon_height= 32' '    icon_height= 48' \
        --replace-fail '    item_icon_space = 20' '    item_icon_space = 28' \
        --replace-fail '    item_height = 36' '    item_height = 58' \
        --replace-fail '    item_padding = 5' '    item_padding = 8' \
        --replace-fail '    item_spacing = 10' '    item_spacing = 14' \
        --replace-fail '    height = 4%' '    height = 2.5%'
    '';

    meta = {
      description = "Touhou Project GRUB theme from 13atm01/GRUB-Theme";
      homepage = "https://github.com/13atm01/GRUB-Theme";
      license = pkgs.lib.licenses.gpl3;
      platforms = pkgs.lib.platforms.all;
    };
  };

  touhouPlymouthTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "plymouth-theme-touhou-logo";
    version = "2026-06-26";

    src = pkgs.fetchurl {
      url = "https://upload.wikimedia.org/wikipedia/commons/f/f6/Touhou_Project.svg";
      hash = "sha256-eSBXInPHh9YH58/wicug5HG3wyXAz0NHGnrcd9xLeQs=";
    };

    nativeBuildInputs = [
      pkgs.imagemagick
      pkgs.librsvg
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      themeDir="$out/share/plymouth/themes/touhou_logo"
      mkdir -p "$themeDir"

      rsvg-convert -w 720 "$src" -o touhou-logo-render.png
      magick touhou-logo-render.png \
        -background none \
        -gravity center \
        -extent 780x170 \
        "$themeDir/touhou-logo.png"

      magick -size 460x6 xc:'#2f2730' "$themeDir/progress-box.png"
      magick -size 460x6 xc:'#2698c7' "$themeDir/progress-bar.png"

      cat > "$themeDir/touhou_logo.plymouth" <<EOF
[Plymouth Theme]
Name=Touhou Logo
Description=Touhou Project logo with a quiet progress bar
ModuleName=script

[script]
ImageDir=$themeDir
ScriptFile=$themeDir/touhou_logo.script
EOF

      cat > "$themeDir/touhou_logo.script" <<'EOF'
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

logo.image = Image("touhou-logo.png");
logo.sprite = Sprite(logo.image);

progress_box.image = Image("progress-box.png");
progress_box.sprite = Sprite(progress_box.image);

progress_bar.original_image = Image("progress-bar.png");
progress_bar.image = progress_bar.original_image.Scale(1, progress_bar.original_image.GetHeight());
progress_bar.sprite = Sprite(progress_bar.image);

fun place_sprites()
{
  center_x = Window.GetX() + Window.GetWidth() / 2;
  center_y = Window.GetY() + Window.GetHeight() / 2;
  progress_y = center_y + logo.image.GetHeight() / 2 + 22;

  logo.sprite.SetPosition(
    center_x - logo.image.GetWidth() / 2,
    center_y - logo.image.GetHeight() / 2 - 48,
    10
  );

  progress_box.sprite.SetPosition(
    center_x - progress_box.image.GetWidth() / 2,
    progress_y,
    8
  );

  progress_bar.sprite.SetPosition(
    center_x - progress_bar.original_image.GetWidth() / 2,
    progress_y,
    9
  );
}

fun refresh_callback()
{
  Window.ApplyBackgroundColors();
  place_sprites();
}

place_sprites();
Plymouth.SetRefreshFunction(refresh_callback);

fun progress_callback(duration, progress)
{
  width = Math.Int(progress_bar.original_image.GetWidth() * progress);

  if (width < 1)
    width = 1;

  if (width != progress_bar.image.GetWidth())
    {
      progress_bar.image = progress_bar.original_image.Scale(width, progress_bar.original_image.GetHeight());
      progress_bar.sprite.SetImage(progress_bar.image);
    }
}

Plymouth.SetBootProgressFunction(progress_callback);

fun quit_callback()
{
  logo.sprite.SetOpacity(1);
}

Plymouth.SetQuitFunction(quit_callback);
EOF

      runHook postInstall
    '';

    meta = {
      description = "Touhou Project logo Plymouth boot splash";
      homepage = "https://commons.wikimedia.org/wiki/File:Touhou_Project.svg";
      license = pkgs.lib.licenses.publicDomain;
      platforms = pkgs.lib.platforms.linux;
    };
  };
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
    theme = touhouGrubTheme;
    splashImage = ../../assets/boot-background.png;
    # Keep large kernel/initrd artifacts off the small ESP. GRUB writes its
    # boot files under /boot-grub on the root filesystem, while /boot remains
    # only the EFI system partition.
    mirroredBoots = [
      {
        path = "/boot-grub";
        efiSysMountPoint = "/boot";
        efiBootloaderId = "NixOS-boot";
        devices = [ "nodev" ];
      }
    ];
    copyKernels = false;
    extraInstallCommands = ''
      grubBootId="$(
        ${pkgs.efibootmgr}/bin/efibootmgr \
          | ${pkgs.gawk}/bin/awk '/NixOS-boot|NixOS Boot Manager/ { id = $1; sub(/^Boot/, "", id); sub(/\*.*/, "", id); print id; exit }'
      )"

      if [ -n "$grubBootId" ]; then
        currentOrder="$(${pkgs.efibootmgr}/bin/efibootmgr | ${pkgs.gnused}/bin/sed -n 's/^BootOrder: //p')"
        restOrder="$(
          printf '%s\n' "$currentOrder" \
            | ${pkgs.gnused}/bin/sed \
                -e "s/^$grubBootId,//" \
                -e "s/,$grubBootId,/,/" \
                -e "s/,$grubBootId$//" \
                -e "s/^$grubBootId$//"
        )"

        if [ -n "$restOrder" ]; then
          desiredOrder="$grubBootId,$restOrder"
        else
          desiredOrder="$grubBootId"
        fi

        if [ -n "$currentOrder" ] && [ "$currentOrder" != "$desiredOrder" ]; then
          ${pkgs.efibootmgr}/bin/efibootmgr -o "$desiredOrder"
        fi
      fi
    '';
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tun" ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "touhou_logo";
    themePackages = [ touhouPlymouthTheme ];
  };
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.systemd.show_status=false"
    "systemd.show_status=false"
    # tty1 is handed to Plymouth/kmscon; keep fbcon on fallback VTs so a
    # non-fullscreen kernel console is less likely to flash during handoff.
    "fbcon=vc:2-6"
    "vt.global_cursor_default=0"
  ];

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
