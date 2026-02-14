{ lib, ... }:
{
  options.audio = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      volume = {
        step = 5;
        max = 150;
        default = 100;
      };
      bluetooth.codec = "ldac";
    };
    description = "Audio and volume control settings";
  };
}
