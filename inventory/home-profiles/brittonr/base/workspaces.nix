{ lib, ... }:
{
  options.workspaces = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      count = 10;
      names = [
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "10"
      ];
    };
    description = "Workspace configuration for window manager";
  };
}
