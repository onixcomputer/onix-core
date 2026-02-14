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
    };
    description = "Terminal emulator performance and behavior settings";
  };
}
