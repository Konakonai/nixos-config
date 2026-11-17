{
  lib,
  buildNpmPackage,
  fetchNpmDeps,
  fetchurl,
  installShellFiles,
  jq,
}:

let
  pname = "opencli";
  version = "2.0.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@jackwener/opencli/-/opencli-${version}.tgz";
    hash = "sha256-Xo0og32H9EyycqzAwHB67ARpyuV5yt9x/gCRyYSXmRg=";
  };

  lockFile = fetchurl {
    url = "https://raw.githubusercontent.com/jackwener/OpenCLI/v${version}/package-lock.json";
    hash = "sha256-ti58grFtdc07ontoExStGi6zfCDElU64EXBypXWS8VM=";
  };

  npmDepsHash = "sha256-SaBAQ/7cYtrU3ADJFnMNOXECb6VdstHIMH5FW7DoN7Q=";

  # The published npm tarball already ships prebuilt `dist/src/` and
  # `cli-manifest.json`, so strip the 300+ devDependencies (vitepress, vitest,
  # typescript) from upstream's lockfile and fetch only the 18 runtime deps.
  postPatch = ''
    jq 'del(.packages[] | select(.dev == true)) | del(.packages[""].devDependencies)' \
      "${lockFile}" > package-lock.json
    jq 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json

    # Updates come through `update-pins`, not `npm install -g`.
    substituteInPlace dist/src/update-check.js \
      --replace-fail 'npm install -g @jackwener/opencli' 'update-pins'
  '';
in
buildNpmPackage {
  inherit
    pname
    version
    src
    npmDepsHash
    postPatch
    ;

  # npm tarballs unpack into `package/`.
  sourceRoot = "package";

  npmDeps = fetchNpmDeps {
    inherit src postPatch;
    sourceRoot = "package";
    name = "${pname}-${version}-npm-deps";
    hash = npmDepsHash;
    nativeBuildInputs = [ jq ];
  };

  nativeBuildInputs = [
    installShellFiles
    jq
  ];

  dontNpmBuild = true;
  npmFlags = [
    "--omit=dev"
    "--ignore-scripts"
  ];

  postInstall = ''
    pkgRoot="$out/lib/node_modules/@jackwener/opencli"

    # Drop @mixmark-io/domino's 7 MB upstream test suite (matches postinstall.js).
    rm -rf "$pkgRoot/node_modules/@mixmark-io/domino/test"

    mkdir -p "$out/share/opencli"
    ln -s "$pkgRoot/skills" "$out/share/opencli/skills"

    installShellCompletion --cmd opencli \
      --bash <(cat <<'EOF'
    _opencli_completions() {
      local cur words cword
      _get_comp_words_by_ref -n : cur words cword
      local completions
      completions=$(opencli --get-completions --cursor "$cword" "''${words[@]:1}" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$completions" -- "$cur") )
      __ltrim_colon_completions "$cur"
    }
    complete -F _opencli_completions opencli
    EOF
      ) \
      --fish <(cat <<'EOF'
    complete -c opencli -f -a '(
      set -l tokens (commandline -cop)
      set -l cursor (count (commandline -cop))
      opencli --get-completions --cursor $cursor $tokens[2..] 2>/dev/null
    )'
    EOF
      ) \
      --zsh <(cat <<'EOF'
    #compdef opencli
    _opencli() {
      local -a completions
      local cword=$((CURRENT - 1))
      completions=(''${(f)"$(opencli --get-completions --cursor "$cword" "''${words[@]:1}" 2>/dev/null)"})
      compadd -a completions
    }
    _opencli
    EOF
      )
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME="$TMPDIR" CI=1 "$out/bin/opencli" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "General-purpose browser automation CLI and deterministic site adapters for AI agents";
    homepage = "https://github.com/jackwener/OpenCLI";
    downloadPage = "https://github.com/jackwener/OpenCLI/releases";
    license = lib.licenses.asl20;
    mainProgram = "opencli";
    platforms = lib.platforms.linux;
  };
}
