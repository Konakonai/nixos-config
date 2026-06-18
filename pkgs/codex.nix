{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.139.0";

  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "10803293vjwq42dwxs0ppc9d3kgawysjm4b230333j0xyh6zgsqj";
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp codex-x86_64-unknown-linux-musl $out/bin/codex-bin
    chmod +x $out/bin/codex-bin

    cat > $out/bin/codex << 'WRAPPER'
#!/etc/profiles/per-user/lilya/bin/bash
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
