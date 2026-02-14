{ lib, ... }:
{
  options.screenshot = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      annotationSizeFactor = 2.0;
      brushSmoothHistorySize = 5;
    };
    description = "Screenshot annotation tool (satty) settings";
  };
}
