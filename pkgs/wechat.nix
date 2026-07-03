{ pkgs, lib, fcitxCompatEnv ? { }, ... }:

let
  pname = "wechat";
  version = "4.1.1.7";

  src = pkgs.fetchurl {
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-vTTkuFm1LhAqVvuynIfYdROPf19nfCQIOGhw6Z+dOeo=";
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };

  fcitxExports = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") fcitxCompatEnv
  );

  fontConfigPath = "$out/share/wechat-fontconfig/fonts.conf";
in
pkgs.appimageTools.wrapAppImage {
  inherit pname version;

  src = appimageContents;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${appimageContents}/wechat.desktop $out/share/applications/
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/

    mkdir -p $out/share/wechat-fontconfig
    cat > ${fontConfigPath} <<'EOF'
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <include ignore_missing="yes">conf.d</include>

      <match target="pattern">
        <test qual="any" name="family"><string>Microsoft YaHei</string></test>
        <test name="style"><string>Semi-Bold</string></test>
        <edit name="family" mode="assign" binding="strong"><string>Noto Sans CJK SC</string></edit>
        <edit name="weight" mode="assign"><const>medium</const></edit>
      </match>

      <match target="pattern">
        <test qual="any" name="family"><string>PingFang SC</string></test>
        <test name="style"><string>Semi-Bold</string></test>
        <edit name="family" mode="assign" binding="strong"><string>Noto Sans CJK SC</string></edit>
        <edit name="weight" mode="assign"><const>medium</const></edit>
      </match>

      <match target="font">
        <test name="family"><string>Noto Sans CJK SC</string></test>
        <test name="style"><string>Regular</string></test>
        <edit name="embolden" mode="assign"><bool>true</bool></edit>
      </match>
    </fontconfig>
    EOF

    substituteInPlace $out/share/applications/wechat.desktop \
      --replace-fail AppRun wechat

    mv $out/bin/wechat $out/bin/.wechat-wrapped
    cat > $out/bin/wechat <<EOF
    #!${pkgs.runtimeShell}
    ${fcitxExports}
    export FONTCONFIG_FILE=${fontConfigPath}
    exec "$out/bin/.wechat-wrapped" "\$@"
    EOF
    chmod +x $out/bin/wechat
  '';

  meta = {
    description = "Messaging and calling app";
    homepage = "https://www.wechat.com/en/";
    downloadPage = "https://linux.weixin.qq.com/en";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "wechat";
    platforms = [ "x86_64-linux" ];
  };
}
