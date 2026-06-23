{ pkgs, lib, ... }:

pkgs.stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.142.0";

  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "00d8vvk421p1x7way0dz4vmbxbkg4kfwycnq2k1i3zvpl8wwnfif";
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
