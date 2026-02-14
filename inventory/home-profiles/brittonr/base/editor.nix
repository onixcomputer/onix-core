{ lib, ... }:
{
  options.editor = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      textWidth = 80;
      rulers = [ 80 ];
      softWrap = {
        maxWrap = 25;
        maxWrapZen = 40;
      };
      autoSave.timeout = 3000;
      inlineDiagnostics = {
        maxCount = 5;
        prefixLen = 2;
      };
    };
    description = "Editor settings for text width, wrapping, auto-save, and diagnostics";
  };
}
