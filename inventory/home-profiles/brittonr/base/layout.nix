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

    focusRingWidth = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = 1;
      description = "Focus ring width in pixels (distinct from border width)";
    };

    presetColumnWidths = lib.mkOption {
      type = lib.types.listOf lib.types.float;
      readOnly = true;
      default = [
        0.33333
        0.5
        0.66667
      ];
      description = "Preset column width proportions for tiling WM";
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
