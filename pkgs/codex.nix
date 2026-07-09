{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.144.0";

  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "1fy80pxm1fancrd33xzr71i22b6iyvns1ai9503z6jmb43y86n3j";
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp codex-x86_64-unknown-linux-musl $out/bin/codex-bin
    chmod +x $out/bin/codex-bin

    cat > $out/bin/codex << 'WRAPPER'
#!${pkgs.runtimeShell}
exec @out@/bin/codex-bin "$@"
WRAPPER
    chmod +x $out/bin/codex
    sed -i "s|@out@|$out|g" $out/bin/codex
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    platforms = [ "x86_64-linux" ];
  };
}
