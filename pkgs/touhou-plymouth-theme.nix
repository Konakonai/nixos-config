{
  stdenvNoCC,
  fetchurl,
  imagemagick,
  librsvg,
  lib,
}:

stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-touhou-logo";
  version = "2026-06-26";

  src = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/f/f6/Touhou_Project.svg";
    hash = "sha256-eSBXInPHh9YH58/wicug5HG3wyXAz0NHGnrcd9xLeQs=";
  };

  nativeBuildInputs = [
    imagemagick
    librsvg
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
    license = lib.licenses.publicDomain;
    platforms = lib.platforms.linux;
  };
}
