{ config, hostProfile, lib, pkgs, ... }:

let
  preferredDisplayKernelParam = hostProfile.boot.preferredDisplayParam or null;

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
logo.sprite.SetPosition(
  Window.GetX() + Window.GetWidth() / 2 - logo.image.GetWidth() / 2,
  Window.GetY() + Window.GetHeight() / 2 - logo.image.GetHeight() / 2 - 48,
  10
);

progress_box.image = Image("progress-box.png");
progress_box.sprite = Sprite(progress_box.image);
progress_box.sprite.SetPosition(
  Window.GetX() + Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2,
  Window.GetY() + Window.GetHeight() / 2 + 80,
  8
);

progress_bar.original_image = Image("progress-bar.png");
progress_bar.image = progress_bar.original_image.Scale(1, progress_bar.original_image.GetHeight());
progress_bar.sprite = Sprite(progress_bar.image);
progress_bar.sprite.SetPosition(
  Window.GetX() + Window.GetWidth() / 2 - progress_bar.original_image.GetWidth() / 2,
  Window.GetY() + Window.GetHeight() / 2 + 80,
  9
);

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

  fallbackKernelParams = builtins.filter (param: param != preferredDisplayKernelParam) config.boot.kernelParams;
in
{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 30;
    theme = touhouGrubTheme;
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
  # Plymouth must start after NVIDIA KMS has replaced the firmware framebuffer;
  # otherwise it lays out on the internal panel and keeps that geometry when the
  # external display takes over.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.initrd.systemd.services.plymouth-start.after = [ "systemd-modules-load.service" ];
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
    "vt.global_cursor_default=0"
  ] ++ lib.optional (preferredDisplayKernelParam != null) preferredDisplayKernelParam;
  boot.supportedFilesystems.ntfs = true;

  specialisation = lib.optionalAttrs (preferredDisplayKernelParam != null) {
    internal-display-fallback.configuration = {
      system.nixos.tags = [ "internal-display-fallback" ];
      boot.kernelParams = lib.mkForce fallbackKernelParams;
    };
  };

  environment.systemPackages = [ pkgs.efibootmgr ];

  security.allowSimultaneousMultithreading = false;
}
