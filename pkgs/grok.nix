{
  lib,
  stdenv,
  fetchurl,
  zstd,
  installShellFiles,
  makeDesktopItem,
  copyDesktopItems,
}:

stdenv.mkDerivation rec {
  pname = "grok";
  version = "1.0.34";

  src = fetchurl {
    url = "https://x.ai/cli/grok-${version}-linux-x86_64.zst";
    sha256 = "1wbgw3mcszn4vymdri6m7pqzfk0r51v66kmx0xn7z25l3qklcyba";
  };

  icon = fetchurl {
    url = "https://media.x.ai/v1/website/spacexai-symbol-white-transparent-0c31957f.png";
    sha256 = "1iklav19hr1d97ghh2ha9ndmpml37am1yvwsq941h6rhm02qzqin";
  };

  desktopItems = [
    (makeDesktopItem {
      name = "grok";
      desktopName = "Grok Build";
      genericName = "AI Coding Agent";
      comment = "SpaceXAI's coding agent harness and fullscreen TUI";
      exec = "grok";
      icon = "grok";
      terminal = true;
      categories = [ "Development" ];
      keywords = [
        "ai"
        "coding"
        "agent"
        "grok"
        "xai"
      ];
    })
  ];

  nativeBuildInputs = [
    zstd
    installShellFiles
    copyDesktopItems
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    zstd -dc $src > $out/bin/grok
    chmod +x $out/bin/grok
    ln -s grok $out/bin/agent

    $out/bin/grok completions bash > grok.bash
    $out/bin/grok completions zsh > _grok
    $out/bin/grok completions fish > grok.fish
    installShellCompletion --cmd grok \
      --bash grok.bash \
      --zsh _grok \
      --fish grok.fish

    install -Dm644 $icon $out/share/icons/hicolor/512x512/apps/grok.png

    runHook postInstall
  '';

  meta = with lib; {
    description = "SpaceXAI's coding agent harness and fullscreen TUI";
    homepage = "https://x.ai/build";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok";
  };
}
