{ lib, ... }:
{
  options.terminal = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      cursorBlinkInterval = "0.5";
      repaintDelay = 10;
      inputDelay = 3;
      visualBellDuration = 0;
      updateCheckInterval = 0;
      scrollbar = {
        width = 1;
        hoverWidth = 2;
        radius = 0.5;
        gap = 0.1;
        minHandleHeight = 2;
      };
    };
    description = "Terminal emulator performance and behavior settings";
  };
}
