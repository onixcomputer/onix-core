{ lib, ... }:
{
  # Add brightness control keybindings for laptops
  wayland.windowManager.hyprland.settings.bindel = lib.mkAfter [
    ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
    ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
  ];
}
