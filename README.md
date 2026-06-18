# lilya's NixOS configuration

Personal NixOS + Home Manager configuration for a light niri desktop.

## Layout

- `configuration.nix`: NixOS system configuration.
- `home.nix`: Home Manager user configuration.
- `modules/`: desktop, theme, shell, niri, kitty, fcitx5, and shared glass settings.
- `pkgs/`: small local package definitions; binary sources are fetched with pinned hashes.

Local source archives under `sources/` are intentionally ignored and are not part of the repository.
