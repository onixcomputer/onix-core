{ config, ... }:
{
  services.gammastep = {
    enable = true;
    provider = "manual";
    latitude = config.location.lat;
    longitude = config.location.lng;
    temperature = {
      day = 6500;
      night = 3500;
    };
    settings.general = {
      brightness-day = 1.0;
      brightness-night = 0.9;
      fade = 1; # smooth transitions
    };
  };
}
