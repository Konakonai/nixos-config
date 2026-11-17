{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
}:

let
  pname = "gemini-api";
  version = "0.4.6";

  src = fetchurl {
    url = "https://github.com/google-gemini/gemini-api-cli/releases/download/v${version}/gemini-api_Linux_x86_64.tar.gz";
    hash = "sha256-eIYt3lGdm0ep+3Cx8DQNGfoSRZNNZeg/Di28HRfNL6Y=";
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    install -Dm755 gemini-api "$out/bin/gemini-api"

    installShellCompletion --cmd gemini-api \
      --bash <("$out/bin/gemini-api" completion bash) \
      --fish <("$out/bin/gemini-api" completion fish) \
      --zsh <("$out/bin/gemini-api" completion zsh)

    runHook postInstall
  '';

  meta = {
    description = "CLI for the Gemini Interactions API and managed-agent platform";
    homepage = "https://github.com/google-gemini/gemini-api-cli";
    license = lib.licenses.asl20;
    mainProgram = "gemini-api";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
