{ lib, ... }:
{
  options.terminal = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      cursorBlinkInterval = "0.5";
      cursorTrail = 3;
      cursorStopBlinkingAfter = 0;
      repaintDelay = 10;
      inputDelay = 3;
      visualBellDuration = 0;
      updateCheckInterval = 0;
      scrollbackLines = 10000;
      mouseHideWait = 3;
      minimumContrast = 7.0;
      inactiveTextAlpha = 0.8;
      textComposition = {
        gamma = 1.0;
        scale = 1.75;
      };
      scrollbar = {
        width = 1;
        hoverWidth = 2;
        radius = 0.5;
        gap = 0.1;
        minHandleHeight = 2;
        handleOpacity = 0.6;
        trackOpacity = 0.1;
      };
    };
    description = "Terminal emulator performance and behavior settings";
  };
}
