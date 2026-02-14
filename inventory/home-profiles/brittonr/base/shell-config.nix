{ lib, ... }:
{
  options.shellConfig = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      starship = {
        truncationLength = 3;
        cmdDurationMinTime = 0;
      };
    };
    description = "Shell prompt configuration";
  };
}
