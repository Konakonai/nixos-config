{
  config,
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  thermalProfile = pkgs.writeShellScriptBin "thermal-profile" ''
    set -eu

    powerprofilesctl="${pkgs.power-profiles-daemon}/bin/powerprofilesctl"

    notify() {
      ${pkgs.libnotify}/bin/notify-send \
        --app-name=thermal-profile \
        "Thermal profile" \
        "$1" >/dev/null 2>&1 || true
    }

    current_profile() {
      "$powerprofilesctl" get 2>/dev/null || echo balanced
    }

    set_profile() {
      profile="$1"
      case "$profile" in
        balanced)
          label="Balanced"
          ;;
        performance)
          label="Performance"
          ;;
        power-saver)
          label="Power saver"
          ;;
        *)
          echo "unknown thermal profile: $profile" >&2
          exit 2
          ;;
      esac

      "$powerprofilesctl" set "$profile"
      echo "$profile"
      notify "$label"
    }

    case "''${1:-toggle}" in
      toggle)
        case "$(current_profile)" in
          performance)
            set_profile balanced
            ;;
          *)
            set_profile performance
            ;;
        esac
        ;;
      balanced|performance|power-saver)
        set_profile "$1"
        ;;
      status)
        current_profile
        if [ -r /sys/firmware/acpi/platform_profile ]; then
          printf 'platform_profile='
          cat /sys/firmware/acpi/platform_profile
        fi
        ;;
      *)
        echo "usage: thermal-profile [toggle|balanced|performance|power-saver|status]" >&2
        exit 2
        ;;
    esac
  '';

  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);
  powerSaverCpuCommand = "${python}/bin/python3 ${../../scripts/power-saver-cpu.py}";

  internalUsbRule =
    { vendor, product }:
    ''ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${vendor}", ATTR{idProduct}=="${product}", ATTR{power/control}="auto"'';

  inherit (hostProfile.graphics.nvidia) pci;
  hexByte = value: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString value));
  pciAddress = "0000:${hexByte pci.bus}:${hexByte pci.device}.${toString pci.function}";

  # Waking the dGPU from runtime D3 takes ~1.5 s and whatever touched it blocks
  # for that long (see Smithay/smithay#2178 for the compositor case). On mains
  # the saved power is not worth those stalls, so keep the GPU awake there and
  # only let it sleep on battery. "Mains" is any non-battery supply: ADP0 lags
  # a Type-C PD contract by about 5 s (measured 2026-11-13), and waking from
  # D3 in that gap stalls the compositor. Runs after the fine-grained rules
  # from the NixOS nvidia module because RUN programs execute once all rules
  # are done.
  onExternalPower = "${pkgs.bash}/bin/bash ${../../scripts/external-power.sh}";
  applyDgpuPolicy = pkgs.writeShellScript "dgpu-runtime-pm" ''
    set -eu
    control=/sys/bus/pci/devices/${pciAddress}/power/control
    [ -w "$control" ] || exit 0
    if ${onExternalPower}; then
      echo on > "$control"
    else
      echo auto > "$control"
    fi
  '';
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  # power-profiles-daemon's battery-aware mode drops intel_pstate EPP from
  # balance_performance to balance_power while on battery in balanced mode,
  # capping the i9-13900H at <=2.2 GHz and making interactive bursts sluggish.
  # Disabling UPower integration keeps balanced responsive on battery while
  # leaving explicit power-saver (and power-saver-cpu.py, which talks to UPower
  # directly) intact.
  systemd.services.power-profiles-daemon.serviceConfig.ExecStart = [
    ""
    "${config.services.power-profiles-daemon.package}/libexec/power-profiles-daemon --disable-upower"
  ];
  services.thermald.enable = true;

  services.logind.settings.Login = {
    # The panel already powers off when the lid is physically closed; keep the
    # system awake to avoid unreliable s2idle resume on this machine.
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  powerManagement.powertop.enable = false;

  environment.systemPackages = [ thermalProfile ];

  services.udev.extraRules = ''
    # Let the idle built-in camera, fingerprint reader and Bluetooth suspend
    # their links. The xHCI controllers themselves stay on for USB-C recovery
    # (see usb-c.nix), so this only saves the devices' own idle power.
    ${lib.concatMapStringsSep "\n" internalUsbRule hostProfile.usb.internalDevices}

    # Keep USB keyboards and mice awake: waking a suspended HID device drops or
    # delays the first input event, which is the latency autosuspend costs.
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTR{bInterfaceClass}=="03", TEST=="../power/control", RUN+="${pkgs.runtimeShell} -c 'echo on > /sys$devpath/../power/control'"

    # The Bluetooth Xbox controller can appear as plain input on this machine,
    # which makes Proton/Wine miss it even though /dev/input/js0 exists.
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Xbox Wireless Controller", ENV{ID_INPUT_JOYSTICK}="1", ENV{ID_INPUT_GAMEPAD}="1", TAG+="uaccess"

    # Re-evaluate dGPU runtime PM on driver bind and on any external-supply change.
    ACTION=="bind", SUBSYSTEM=="pci", KERNEL=="${pciAddress}", RUN+="${applyDgpuPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ADP0", RUN+="${applyDgpuPolicy}"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-*", RUN+="${applyDgpuPolicy}"
  '';

  systemd.services.power-saver-cpu = {
    description = "Apply turbo and PCIe policy on battery in power-saver mode";
    # power-profiles-daemon orders itself after multi-user.target, so being
    # wanted by (and thus before) multi-user.target formed a cycle and systemd
    # dropped this unit at boot. Follow ppd onto graphical.target instead.
    wantedBy = [ "graphical.target" ];
    wants = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    after = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    unitConfig.ConditionPathExists = "/sys/devices/system/cpu/intel_pstate/no_turbo";
    serviceConfig = {
      ExecStart = powerSaverCpuCommand;
      ExecStopPost = "${powerSaverCpuCommand} --restore";
      Restart = "on-failure";
      RestartSec = "5s";
      RuntimeDirectory = "power-saver-cpu";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  # Applies dGPU runtime-PM policy at boot and on every rebuild, when no udev
  # supply-change event is replayed.
  systemd.services.dgpu-runtime-pm = {
    description = "Keep the NVIDIA dGPU awake on mains";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = applyDgpuPolicy;
    };
  };
}
