{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  internalUsbRule =
    { vendor, product }:
    ''ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${vendor}", ATTR{idProduct}=="${product}", ATTR{power/control}="auto"'';
in
{
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
  '';
}
