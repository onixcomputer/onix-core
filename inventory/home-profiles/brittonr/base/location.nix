{ lib, ... }:
{
  options.location = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      lat = 52.3;
      lng = 4.8;
    };
    description = "Geographic location for sunrise/sunset calculations";
  };
}
