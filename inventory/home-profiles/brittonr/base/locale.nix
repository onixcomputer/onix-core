{ lib, ... }:
{
  options.locale = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      timezone = "Europe/Amsterdam";
      language = "en_US.UTF-8";
      clockFormat = "{:%Y-%m-%d %H:%M}";
      dateFormat = "%Y-%m-%d";
      timeFormat = "%H:%M";
      units = "metric";
    };
    description = "Internationalization and locale settings";
  };
}
