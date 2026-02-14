{ lib, ... }:
{
  options.layout = {
    borderWidth = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = 2;
      description = "Border width in pixels";
    };

    borderRadius = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = 0;
      description = "Border radius in pixels (0 = sharp corners)";
    };

    gaps = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = 8;
      description = "Gap size between windows/elements";
    };

    terminal = {
      padding = lib.mkOption {
        type = lib.types.int;
        readOnly = true;
        default = 14;
        description = "Terminal window padding in pixels";
      };
    };
  };
}
