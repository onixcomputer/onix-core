{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    str
    port
    int
    float
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "clonadic";
    readme = "Clonadic - A spreadsheet where an LLM evaluates every formula";
  };

  roles = {
    default = {
      description = "Clonadic spreadsheet server";
      interface = {
        options = {
          host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Host address to bind to";
          };

          port = mkOption {
            type = port;
            default = 8080;
            description = "Port for the Clonadic web server";
          };

          model = mkOption {
            type = str;
            default = "qwen3:4b";
            description = "Ollama model to use for formula evaluation";
          };

          ollamaHost = mkOption {
            type = str;
            default = "http://localhost:11434";
            description = "Ollama API endpoint";
          };

          temperature = mkOption {
            type = float;
            default = 0.0;
            description = "LLM temperature for formula evaluation";
          };

          gridRows = mkOption {
            type = int;
            default = 20;
            description = "Default number of rows in the grid";
          };

          gridCols = mkOption {
            type = int;
            default = 10;
            description = "Default number of columns in the grid";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          exports.serviceEndpoints.clonadic = {
            url = "http://localhost:${toString settings.port}";
            inherit (settings) port;
          };
          nixosModule =
            {
              pkgs,
              inputs,
              ...
            }:
            let
              inherit (settings)
                host
                port
                model
                ollamaHost
                temperature
                gridRows
                gridCols
                ;

              inherit (pkgs.stdenv.hostPlatform) system;
              clonadic = inputs.clonadic.packages.${system}.default;

              configToml = pkgs.writeText "clonadic-config.toml" ''
                [server]
                host = "${host}"
                port = ${toString port}
                debug = false

                [llm]
                provider = "ollama"
                base_url = "${ollamaHost}"
                model = "${model}"
                temperature = ${toString temperature}

                [stats]
                tokens_per_operation = 300
                cost_per_operation = 0.003

                [grid]
                default_rows = ${toString gridRows}
                default_cols = ${toString gridCols}
              '';
            in
            {
              systemd.services.clonadic = {
                description = "Clonadic LLM-powered spreadsheet";
                after = [
                  "network.target"
                  "ollama.service"
                ];
                wants = [ "ollama.service" ];
                wantedBy = [ "multi-user.target" ];

                environment = {
                  OLLAMA_HOST = ollamaHost;
                  CLONAD_MODEL = model;
                };

                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${clonadic}/bin/clonadic";
                  WorkingDirectory = "/var/lib/clonadic";
                  StateDirectory = "clonadic";
                  Restart = "on-failure";
                  RestartSec = "10s";

                  DynamicUser = true;
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  PrivateTmp = true;
                  NoNewPrivileges = true;
                };
              };

              # Deploy config.toml to the working directory
              systemd.tmpfiles.rules = [
                "d /var/lib/clonadic 0755 - - -"
                "L+ /var/lib/clonadic/config.toml - - - - ${configToml}"
              ];

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };
  };
}
