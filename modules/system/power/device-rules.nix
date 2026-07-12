{ hostProfile, lib, ... }:

let
  power = hostProfile.power or { };
  keepAwakeUsbDevices = power.keepAwakeUsbDevices or [ ];
in
{
  services.udev.extraRules = lib.concatStringsSep "\n" (
    # Keep latency-sensitive HID devices awake. PowerTOP auto-tuning was putting
    # these behind USB autosuspend, which matched the observed mouse/keyboard stalls.
    map (device:
      ''ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${device.vendor}", ATTR{idProduct}=="${device.product}", TEST=="power/control", ATTR{power/control}="on"''
    ) keepAwakeUsbDevices
    ++ [
      # The Bluetooth Xbox controller can appear as plain input on this machine,
      # which makes Proton/Wine miss it even though /dev/input/js0 exists.
      ''ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Xbox Wireless Controller", ENV{ID_INPUT_JOYSTICK}="1", ENV{ID_INPUT_GAMEPAD}="1", TAG+="uaccess"''
    ]
  );
}
