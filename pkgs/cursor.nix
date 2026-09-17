{
  appimageTools,
  fetchurl,
  code-cursor,
}:

let
  version = "3.20.17";
  src = appimageTools.extract {
    pname = "cursor";
    inherit version;
    src = fetchurl {
      url = "https://downloads.cursor.com/production/0c32194e3fb5ffaced9fb36430b860ec301e1fc8/linux/x64/Cursor-${version}-x86_64.AppImage";
      hash = "sha256-E+gInIUlGhAveZBa3/uR3SmN1YYmUlmb5jRX4o3DEhg=";
    };
  };
in
code-cursor.overrideAttrs (_old: {
  inherit version src;
  sourceRoot = "cursor-${version}-extracted/usr/share/cursor";
})
