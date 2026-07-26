{ ... }:

{
  services.udev.extraRules = ''
    # Disable USB runtime autosuspend across devices, interfaces, and hubs.
    # This complements usbcore.autosuspend=-1 and applies again after hotplug.
    ACTION=="add|change", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"

    # The Bluetooth Xbox controller can appear as plain input on this machine,
    # which makes Proton/Wine miss it even though /dev/input/js0 exists.
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Xbox Wireless Controller", ENV{ID_INPUT_JOYSTICK}="1", ENV{ID_INPUT_GAMEPAD}="1", TAG+="uaccess"
  '';
}
