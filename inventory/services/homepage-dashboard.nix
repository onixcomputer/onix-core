_: {
  instances = {
    "homepage-dashboard" = {
      module.name = "homepage-dashboard";
      module.input = "self";
      roles.server = {
        tags."homepage-server" = { };
        settings = {
          # Port configuration
          listenPort = 8082;

          # Allow access from multiple hosts (using the port above)
          allowedHosts = "localhost:8082,home.blr.dev";

          # Dashboard configuration
          settings = {
            title = "Onix Services";
            theme = "dark";
            color = "slate";
            background = {
              image = "";
              blur = "sm";
              saturate = 50;
              brightness = 50;
              opacity = 50;
            };
          };

          # Manual service entries - auto-discovered services from exports will be appended
          # Add manual entries here to supplement auto-discovered ones:
          # services = [ ];

          # Widgets configuration
          widgets = [
            {
              search = {
                provider = "duckduckgo";
                target = "_blank";
              };
            }
            {
              datetime = {
                text_size = "lg";
                format = {
                  dateStyle = "long";
                  timeStyle = "short";
                  hour12 = false;
                };
              };
            }
          ];

        };
      };
    };
  };
}
