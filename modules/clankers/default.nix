# Clankers clan service — thin wrapper around upstream NixOS modules.
#
# The clankers flake (inputs.clankers) exports:
#   nixosModules.clankers-daemon  — services.clankers-daemon.*
#   nixosModules.clanker-router   — services.clanker-router.*
#
# This clan module adds:
#   - Router auto-discovery via clan exports (daemon finds router endpoint)
#   - Colocation detection (localhost when on same machine)
#   - ANTHROPIC_BASE_URL injection so daemon proxies through router
{ clanLib, lib, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    str
    port
    bool
    nullOr
    listOf
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "clankers";
    readme = "Clankers coding agent daemon and router services";
    exports.out = [ "endpoints" ];
  };

  roles = {
    daemon = {
      description = "Clankers daemon — persistent agent sessions over iroh QUIC";
      interface = {
        options = {
          model = mkOption {
            type = str;
            default = "claude-sonnet-4-20250514";
            description = "Default LLM model for agent sessions";
          };

          allowAll = mkOption {
            type = bool;
            default = false;
            description = "Skip token/ACL checks (development mode)";
          };

          heartbeat = mkOption {
            type = lib.types.int;
            default = 30;
            description = "Heartbeat interval in seconds (0 to disable)";
          };

          apiBase = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              API base URL override (e.g. http://127.0.0.1:4000).
              If null, auto-discovered from the router role's exported endpoint.
            '';
          };

          extraArgs = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra arguments passed to `clankers daemon start`";
          };
        };
      };

      perInstance =
        {
          settings,
          exports,
          machine,
          ...
        }:
        let
          # Find the router endpoint from exports.
          routerExports = clanLib.selectExports (
            scope: scope.serviceName == "clankers" && scope.roleName == "router"
          ) exports;
          routerEntries = lib.attrValues routerExports;

          routerHostPort =
            let
              first = lib.head routerEntries;
              hosts = first.endpoints.hosts or [ ];
            in
            if routerEntries != [ ] && hosts != [ ] then lib.head hosts else null;

          routerScopes = lib.attrNames routerExports;
          routerMachines = map (s: (clanLib.parseScope s).machineName) routerScopes;
          isColocated = lib.elem machine.name routerMachines;

          resolvedApiBase =
            if settings.apiBase != null then
              settings.apiBase
            else if routerHostPort == null then
              null
            else
              let
                parts = lib.splitString ":" routerHostPort;
                routerPort = lib.elemAt parts 1;
              in
              if isColocated then "http://127.0.0.1:${routerPort}" else "http://${routerHostPort}";
        in
        {
          nixosModule =
            { pkgs, inputs, ... }:
            let
              # Local build — upstream unit2nix IFD can't resolve the
              # cross-repo subwayrat path deps in sandbox.
              rustPkgs = import inputs.nixpkgs {
                inherit (pkgs) system;
                overlays = [ (import inputs.rust-overlay) ];
              };
              nightlyToolchain = rustPkgs.rust-bin.nightly.latest.default.override {
                extensions = [ "rust-src" ];
              };
              clankersPkg = pkgs.callPackage "${inputs.self}/pkgs/clankers" {
                rustc = nightlyToolchain;
                cargo = nightlyToolchain;
              };
            in
            {
              imports = [ inputs.clankers.nixosModules.clankers-daemon ];

              services.clankers-daemon = {
                enable = true;
                package = clankersPkg;
                inherit (settings)
                  model
                  allowAll
                  heartbeat
                  extraArgs
                  ;
              };

              # Router auto-discovery: order after colocated router, inject base URL.
              systemd.services.clankers-daemon = mkMerge [
                (mkIf isColocated {
                  after = [ "clanker-router.service" ];
                  wants = [ "clanker-router.service" ];
                })
                (mkIf (resolvedApiBase != null) {
                  environment.ANTHROPIC_BASE_URL = resolvedApiBase;
                })
              ];
            };
        };
    };

    router = {
      description = "Clanker-router — multi-provider LLM proxy with failover and caching";
      interface = {
        options = {
          listenAddr = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Address to bind the HTTP proxy";
          };

          listenPort = mkOption {
            type = port;
            default = 4000;
            description = "Port for the OpenAI-compatible HTTP proxy";
          };

          proxyKeys = mkOption {
            type = listOf str;
            default = [ ];
            description = "API keys allowed to access the proxy. Empty = no auth.";
          };

          extraArgs = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra arguments passed to `clanker-router serve`";
          };
        };
      };

      perInstance =
        {
          instanceName,
          settings,
          mkExports,
          machine,
          ...
        }:
        {
          exports = mkExports {
            endpoints.hosts = [ "${machine.name}:${toString settings.listenPort}" ];
          };

          nixosModule =
            {
              config,
              pkgs,
              inputs,
              ...
            }:
            let
              generatorName = "clanker-router-${instanceName}";
              envFilePath = config.clan.core.vars.generators.${generatorName}.files.env-file.path;
            in
            {
              imports = [ inputs.clankers.nixosModules.clanker-router ];

              services.clanker-router = {
                enable = true;
                package = inputs.clankers.packages.${pkgs.stdenv.hostPlatform.system}.clanker-router;
                proxyAddr = "${settings.listenAddr}:${toString settings.listenPort}";
                openFirewall = true;
                environmentFile = envFilePath;
                inherit (settings) proxyKeys extraArgs;
              };

              # Provider API keys — prompted once, SOPS-encrypted, deployed to target.
              clan.core.vars.generators.${generatorName} = {
                share = true;
                files.env-file = {
                  secret = true;
                  deploy = true;
                };

                prompts = {
                  anthropic-api-key = {
                    description = "Anthropic API key (sk-ant-...)";
                    type = "hidden";
                    persist = true;
                  };
                  openai-api-key = {
                    description = "OpenAI API key (sk-...) — leave empty to skip";
                    type = "hidden";
                    persist = true;
                  };
                  openrouter-api-key = {
                    description = "OpenRouter API key (sk-or-...) — leave empty to skip";
                    type = "hidden";
                    persist = true;
                  };
                };

                runtimeInputs = [ pkgs.coreutils ];

                script = ''
                  : > "$out/env-file"
                  for pair in \
                    "ANTHROPIC_API_KEY:$prompts/anthropic-api-key" \
                    "OPENAI_API_KEY:$prompts/openai-api-key" \
                    "OPENROUTER_API_KEY:$prompts/openrouter-api-key"; do
                    var="''${pair%%:*}"
                    file="''${pair#*:}"
                    val="$(tr -d '\n' < "$file")"
                    [ -n "$val" ] && printf '%s=%s\n' "$var" "$val" >> "$out/env-file"
                  done
                '';
              };
            };
        };
    };
  };
}
