# NixOS Declarative Configuration & App Integration Rules

This file defines project-wide rules and guidelines for managing applications and desktop environments on this NixOS system.

## 1. Declarative Only
* **Rule**: NEVER install packages imperatively using `nix-env` or `nix profile`.
* **Action**: Always add packages to the declarative config repository at `~/nixos-config/home.nix` (or appropriate module).

## 2. Git Tracking for Nix Flakes
* **Rule**: Any new configuration file (e.g., `pkgs/xxx.nix`) must be staged in Git (`git add`) before running any nix build or rebuild command.
* **Action**: Nix Flakes ignores untracked files. Always run `git add <file>` to avoid "file not found" errors during evaluation.

## 3. Desktop Environment (Niri + Noctalia)
* **Rule**: The desktop environment is **Niri** (Wayland compositor) and **Noctalia** (desktop shell/launcher).
* **Action**: When newly installed application menus or icons do not update, reload/restart Noctalia in the background to force-refresh the cache:
  ```bash
  pkill noctalia && noctalia & disown
  ```

## 4. AppImage Packaging
* **Rule**: Package proprietary AppImages using `pkgs.appimageTools.wrapType2`.
* **Action**: Extract `.desktop` and icons using `extractType2`. Always substitute the `Exec` path in the desktop file to target the wrapped binary name (e.g. `Exec=splayer %U` instead of `Exec=AppRun`).
