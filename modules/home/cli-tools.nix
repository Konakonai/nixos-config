{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    aria2
    zip
    sshfs
    # nixpkgs' primp 2.0.1 fails to build: its vendored zstd-sys probes
    # libzstd via pkg-config, and aws-lc-sys is told to use a system AWS-LC,
    # but the derivation provides none of them. Drop once nixpkgs fixes it.
    (python3Packages.ddgs.override {
      primp = python3Packages.primp.overridePythonAttrs (previous: {
        nativeBuildInputs = previous.nativeBuildInputs ++ [ pkg-config ];
        buildInputs = (previous.buildInputs or [ ]) ++ [
          zstd
          aws-lc
        ];
      });
    })
    nh
    nvd
    lilya.nix-update
    trash-cli
    udisks
    ripdrag
    unrar
    _7zz
    pigz
    ffmpeg-full
    typst
    tinymist

    wl-clipboard

    lilya.grok
    inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
