{ lib, ... }:
{
  options.input = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      keyboard.layout = "us";
      touchpad = {
        naturalScroll = true;
        tap = true;
        disableWhileTyping = true;
        accelSpeed = 0.2;
        accelProfile = "adaptive";
        clickMethod = "clickfinger";
        scrollMethod = "two-finger";
      };
      mouse = {
        focusFollows = true;
        warpToFocus = true;
      };
    };
    description = "Input device settings for keyboards, touchpads, and mice";
  };
}
