{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "homepage-dashboard";
    readme = "Homepage dashboard service for customizable web portal and service links";
  };

  roles = {
    server = {
      description = "Homepage dashboard server that provides a customizable web portal";
      interface = {
        # Freeform module - any attribute becomes a homepage-dashboard setting
        freeformType = attrsOf anything;
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            _:
            let
              localSettings = extendSettings {
                # Minimal defaults
                enable = mkDefault true;
                listenPort = mkDefault 8082;
                openFirewall = mkDefault true;

                # Default configuration structure
                settings = mkDefault {
                  title = "Dashboard";
                  background = {
                    image = "";
                    blur = "sm";
                    saturate = 50;
                    brightness = 50;
                    opacity = 50;
                  };
                };

                services = mkDefault [ ];
                widgets = mkDefault [ ];
                bookmarks = mkDefault [ ];
              };
            in
            {
              services.homepage-dashboard = localSettings;
            };
        };
    };
  };

  # No perMachine configuration needed for homepage-dashboard
  perMachine = _: {
    nixosModule = _: { };
  };
}
