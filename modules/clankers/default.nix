# Clankers clan service — thin wrapper around upstream NixOS modules.
#
# The clankers flake (inputs.clankers) exports:
#   nixosModules.clankers-daemon  — services.clankers-daemon.*
#   nixosModules.clanker-router   — services.clanker-router.*
#
# This clan module adds:
#   - ANTHROPIC_BASE_URL injection so daemon proxies through router
#   - Colocation detection (after/wants when router is on same machine)
#   - Vars-based secret management for router API keys
#
# The upstream clankers workspace has path deps on sibling repos
# (subwayrat), so unit2nix IFD can't build it in sandbox. The daemon
# uses a local package build (pkgs/clankers/). The router is a
# standalone repo and builds fine from upstream.
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  inherit (lib) mkIf mkMerge;
in
{
  _class = "clan.service";
  manifest = {
    name = "clankers";
    readme = "Clankers coding agent daemon and router services";
  };

  roles = {
    daemon = {
      description = "Clankers daemon — persistent agent sessions over iroh QUIC";
      interface = mkSettings.mkInterface schema.daemon;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              inputs,
              lib,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              settings = extendSettings (ms.mkDefaults schema.daemon);

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

              routerEnabled = config.services.clanker-router.enable or false;
            in
            {
              imports = [ inputs.clankers.nixosModules.clankers-daemon ];

              # Make the CLI available system-wide for `clankers rpc`, `clankers attach`, etc.
              environment.systemPackages = [ clankersPkg ];

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

              systemd.services.clankers-daemon = mkMerge [
                # When router is colocated, order daemon after it.
                (mkIf routerEnabled {
                  after = [ "clanker-router.service" ];
                  wants = [ "clanker-router.service" ];
                })
                # Route through the proxy when apiBase is set.
                (mkIf (settings.apiBase != null) {
                  environment.ANTHROPIC_BASE_URL = settings.apiBase;
                })
              ];
            };
        };
    };

    router = {
      description = "Clanker-router — multi-provider LLM proxy with failover and caching";
      interface = mkSettings.mkInterface schema.router;

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              inputs,
              lib,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              settings = extendSettings (ms.mkDefaults schema.router);
              generatorName = "clanker-router-${instanceName}";
              inherit (settings) useOAuth;
              routerPkg = inputs.clankers.packages.${pkgs.stdenv.hostPlatform.system}.clanker-router;
            in
            {
              imports = [ inputs.clankers.nixosModules.clanker-router ];

              services.clanker-router = {
                enable = true;
                package = routerPkg;
                proxyAddr = "${settings.listenAddr}:${toString settings.listenPort}";
                openFirewall = true;
                inherit (settings) proxyKeys extraArgs;
              }
              // lib.optionalAttrs (!useOAuth) {
                environmentFile = config.clan.core.vars.generators.${generatorName}.files.env-file.path;
              };

              # Exit code 1 = "no providers configured" — treat as clean exit
              # so switch-to-configuration doesn't report a failed unit.
              # The user runs `clanker-router auth login` / `auth set-key`
              # then `systemctl restart clanker-router`.
              systemd.services.clanker-router.serviceConfig.SuccessExitStatus = "1";

              # Make clanker-router CLI available for `auth login`.
              environment.systemPackages = [ routerPkg ];

              # Provider API keys — prompted once, SOPS-encrypted, deployed to target.
              # Skipped when useOAuth = true (credentials managed via `clanker-router auth login`).
              clan.core.vars.generators = mkIf (!useOAuth) {
                ${generatorName} = {
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
  };
}
