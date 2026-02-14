{ lib, ... }:
{
  options.gestures = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dndEdgeScroll = {
        triggerWidth = 40;
        delayMs = 150;
        maxSpeed = 1200;
      };
      lisgd = {
        timeout = 150;
        outputIndex = 0;
      };
    };
    description = "Gesture configuration for touchpad and touchscreen";
  };
}
