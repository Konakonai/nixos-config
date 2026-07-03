{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.142.5";

  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "1f5anjz580gv1bpvcd952ykglacq2kkgbv4fr1glpgv1rg1kx4yb";
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
