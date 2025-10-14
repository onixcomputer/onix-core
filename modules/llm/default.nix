{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    attrsOf
    anything
    enum
    port
    ;
in
{
  _class = "clan.service";

  manifest = {
    name = "llm";
    description = "LLM Inference Service - Large Language Model serving";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles = {
    # LLM server role - runs inference servers
    server = {
      interface = {
        # Allow freeform configuration that maps directly to underlying services
        freeformType = attrsOf anything;

        options = {
          # Service type selection
          serviceType = mkOption {
            type = enum [
              "ollama"
              "llamacpp"
              "openai-compatible"
            ];
            default = "ollama";
            description = "Type of LLM service to run";
          };

          # Basic server configuration
          port = mkOption {
            type = port;
            default = 11434;
            description = "Port for the LLM service";
          };

          host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Host address to bind to";
          };

          # Model configuration
          models = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of models to download and serve";
          };

          # Resource limits
          enableGPU = mkOption {
            type = bool;
            default = true;
            description = "Enable GPU acceleration if available";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              ...
            }:
            let
              inherit (settings)
                serviceType
                port
                host
                enableGPU
                ;

              # Remove our wrapper options for service-specific config
              serviceConfig = builtins.removeAttrs settings [
                "serviceType"
                "port"
                "host"
                "models"
                "enableGPU"
              ];

              # Base configuration for all services
              baseConfig = {
                enable = true;
                inherit port host;
              };

              # Final configuration merging base + user config
              finalConfig = baseConfig // serviceConfig;

            in
            {
              # Enable the specific LLM service
              services = lib.mkMerge [
                (lib.mkIf (serviceType == "ollama") {
                  ollama = finalConfig // {
                    acceleration = lib.mkIf enableGPU "rocm";
                  };
                })

                # Placeholder for other service types
                (lib.mkIf (serviceType == "llamacpp") {
                  # llamacpp configuration would go here
                })
              ];

              # Open firewall for the service
              networking.firewall.allowedTCPPorts = [ port ];

              # Install client tools
              environment.systemPackages = lib.mkIf (serviceType == "ollama") [
                pkgs.ollama
              ];
            };
        };
    };

    # LLM client role - installs client tools and configuration
    client = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          # Client configuration
          defaultServer = mkOption {
            type = nullOr str;
            default = null;
            description = "Default LLM server endpoint (e.g., http://server:11434)";
          };

          clientType = mkOption {
            type = enum [
              "ollama"
              "openai"
              "curl"
            ];
            default = "ollama";
            description = "Type of client tools to install";
          };

          # Additional client packages
          extraPackages = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional packages to install for LLM clients";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              ...
            }:
            let
              inherit (settings) clientType defaultServer extraPackages;

              # Import custom goose package
              goose-cli-latest = import ./goose-cli-latest.nix { inherit pkgs; };

              # Client packages based on type
              clientPackages =
                (lib.optionals (clientType == "ollama") [
                  pkgs.ollama
                  goose-cli-latest
                  pkgs.opencode
                ])
                ++ (lib.optionals (clientType == "openai") [ pkgs.python3Packages.openai ])
                ++ (lib.optionals (clientType == "curl") [
                  pkgs.curl
                  pkgs.jq
                ]);

              # Additional user-specified packages
              allPackages = clientPackages ++ (map (pkg: pkgs.${pkg}) extraPackages);

            in
            {
              # Install client packages
              environment.systemPackages = allPackages;

              # Configure default server if specified
              environment.variables = lib.mkIf (defaultServer != null) {
                OLLAMA_HOST = lib.mkIf (clientType == "ollama") defaultServer;
                OPENAI_BASE_URL = lib.mkIf (clientType == "openai") defaultServer;
              };
            };
        };
    };
  };
}
