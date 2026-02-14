{ lib, ... }:
{
  options.power = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      battery = {
        warning = 20;
        critical = 10;
        danger = 5;
        full = 95;
      };
      temperature = {
        critical = 80;
      };
    };
    description = "Power management thresholds (battery and temperature levels)";
  };
}
