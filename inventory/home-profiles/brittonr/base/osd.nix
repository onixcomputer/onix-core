{ lib, ... }:
{
  options.osd = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      enabled = true;
      location = "top_right";
      autoHideMs = 2000;
    };
    description = "On-screen display (volume/brightness) settings";
  };
}
