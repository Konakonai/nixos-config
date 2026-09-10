{ ... }:

{
  services.udev.extraRules = ''
    # The Bluetooth Xbox controller can appear as plain input on this machine,
    # which makes Proton/Wine miss it even though /dev/input/js0 exists.
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Xbox Wireless Controller", ENV{ID_INPUT_JOYSTICK}="1", ENV{ID_INPUT_GAMEPAD}="1", TAG+="uaccess"
  '';
}
