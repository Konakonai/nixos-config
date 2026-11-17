{
  lib,
  python3Packages,
  fetchPypi,
  installShellFiles,
  openssh,
}:

let
  pname = "google-colab-cli";
  version = "0.8.0";

  jupyter-mimetypes = python3Packages.buildPythonPackage {
    pname = "jupyter-mimetypes";
    version = "0.2.0";
    format = "wheel";

    src = fetchPypi {
      pname = "jupyter_mimetypes";
      version = "0.2.0";
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-5tzZiSWOP8lENltlbZFzGRUX4OOTvYeOl85QDls4hSc=";
    };

    dependencies = with python3Packages; [
      pyarrow
      typing-extensions
    ];

    pythonImportsCheck = [ "jupyter_mimetypes" ];
  };

  jupyter-kernel-client = python3Packages.buildPythonPackage {
    pname = "jupyter-kernel-client";
    version = "0.9.0";
    format = "wheel";

    src = fetchPypi {
      pname = "jupyter_kernel_client";
      version = "0.9.0";
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-d6y48vc42XYl1r0B7ozyHE1ZeQt7pGQQhxLbOHBBbyA=";
    };

    dependencies = with python3Packages; [
      jupyter-client
      jupyter-core
      jupyter-mimetypes
      requests
      traitlets
      typing-extensions
      websocket-client
    ];

    pythonImportsCheck = [ "jupyter_kernel_client" ];
  };
in
python3Packages.buildPythonApplication {
  inherit pname version;
  pyproject = true;

  src = fetchPypi {
    pname = "google_colab_cli";
    inherit version;
    hash = "sha256-fLVoaI6LzeFOi03SFBy9dtjZZTqVbcr307ea22vr7V0=";
  };

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python3Packages; [
    click
    filelock
    google-auth
    google-auth-oauthlib
    html2text
    jupyter-kernel-client
    keyring
    nbformat
    packaging
    prompt-toolkit
    pydantic
    pygments
    requests
    rich
    typer
    typing-extensions
    websocket-client
  ];

  nativeBuildInputs = [ installShellFiles ];

  # Updates come through `update-pins`, not `pip install --upgrade`.
  postPatch = ''
    substituteInPlace src/colab_cli/auto_update.py \
      --replace-fail \
        'return f"pip install --upgrade {PYPI_PACKAGE_NAME}"' \
        'return "update-pins" if "/nix/store/" in sys.executable else f"pip install --upgrade {PYPI_PACKAGE_NAME}"'
  '';

  # `colab ssh` invokes `ssh` and `ssh-keygen`.
  makeWrapperArgs = [
    "--suffix"
    "PATH"
    ":"
    (lib.makeBinPath [ openssh ])
  ];

  postInstall = ''
    mkdir -p "$out/share/google-colab-cli"
    cp -R skills "$out/share/google-colab-cli/skills"

    installShellCompletion --cmd colab \
      --bash <(HOME="$TMPDIR" _COLAB_COMPLETE=source_bash "$out/bin/colab") \
      --fish <(HOME="$TMPDIR" _COLAB_COMPLETE=source_fish "$out/bin/colab") \
      --zsh <(HOME="$TMPDIR" _COLAB_COMPLETE=source_zsh "$out/bin/colab")
  '';

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-mock
  ];

  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "CLI for interacting with Google Colab runtimes";
    homepage = "https://github.com/googlecolab/google-colab-cli";
    license = lib.licenses.asl20;
    mainProgram = "colab";
    platforms = lib.platforms.linux;
  };
}
