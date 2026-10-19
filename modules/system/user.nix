{
  hostProfile,
  lib,
  pkgs,
  ...
}:

{
  users.users.${hostProfile.user.userName} = {
    isNormalUser = true;
    description = hostProfile.user.userName;
    shell = pkgs.fish;

    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
    ];
  };

  security.sudo.extraConfig = "Defaults pwfeedback";
  # Single-user machine; lets agents rebuild and read root-only debug state
  # (RAPL, i915 debugfs, turbostat) without a password prompt.
  security.sudo.wheelNeedsPassword = false;

  # Home Manager activation already runs synchronously during every rebuild.
  # Reconcile the persisted generation after logins are enabled instead of
  # holding SDDM on the boot-critical path.
  systemd.services."home-manager-${hostProfile.user.userName}" = {
    before = lib.mkForce [ ];
    after = lib.mkAfter [ "systemd-user-sessions.service" ];
  };
}
