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

              # ── Declarative schedules ──────────────────────────────────
              # Convert user-friendly schedule configs to clanker-scheduler
              # JSON format (must match serde representation).
              hasSchedules = settings.schedules != [ ];

              parseCronField =
                s:
                if s == "*" then
                  "Any"
                else if lib.hasPrefix "*/" s then
                  { Step = lib.toInt (lib.removePrefix "*/" s); }
                else if lib.hasInfix "," s then
                  { List = map lib.toInt (lib.splitString "," s); }
                else if lib.hasInfix "-" s then
                  let
                    parts = lib.splitString "-" s;
                  in
                  {
                    Range = [
                      (lib.toInt (builtins.elemAt parts 0))
                      (lib.toInt (builtins.elemAt parts 1))
                    ];
                  }
                else
                  { Exact = lib.toInt s; };

              scheduleToJson =
                s:
                let
                  cronFields = if s.kind == "cron" then lib.splitString " " s.cron else [ ];
                in
                {
                  # Deterministic ID so the merge script can match by name.
                  id = builtins.substring 0 36 (builtins.hashString "sha256" "nix-${s.name}");
                  inherit (s) name;
                  kind =
                    if s.kind == "interval" then
                      {
                        Interval = {
                          interval_secs = s.interval;
                        };
                      }
                    else if s.kind == "cron" then
                      {
                        Cron = {
                          pattern = {
                            minute = parseCronField (builtins.elemAt cronFields 0);
                            hour = parseCronField (builtins.elemAt cronFields 1);
                            day_of_week = parseCronField (builtins.elemAt cronFields 2);
                          };
                        };
                      }
                    else
                      throw "clankers schedule: unknown kind '${s.kind}' (use interval or cron)";
                  status = "Active";
                  payload = {
                    inherit (s) prompt;
                  }
                  // (s.payload or { });
                  created_at = "2026-01-01T00:00:00Z";
                  last_fired = null;
                  fire_count = 0;
                  max_fires = s.maxFires or null;
                };

              seedFile = pkgs.writeText "clankers-schedules-seed.json" (
                builtins.toJSON (map scheduleToJson settings.schedules)
              );

              # Merge script: preserve runtime schedules, replace/add Nix-declared ones.
              mergeScript = pkgs.writeShellScript "clankers-merge-schedules" ''
                set -euo pipefail
                seed="${seedFile}"
                live="/var/lib/clankers/.clankers/agent/schedules.json"
                mkdir -p "$(dirname "$live")"

                if [ -f "$live" ]; then
                  # Remove schedules whose names match seed, then append seed.
                  ${pkgs.jq}/bin/jq --slurpfile seed "$seed" '
                    [.[] | select(.name as $n | ($seed[0] | map(.name) | index($n)) == null)]
                    + $seed[0]
                  ' "$live" > "$live.tmp" && mv "$live.tmp" "$live"
                else
                  cp "$seed" "$live"
                fi
                chown clankers:clankers "$live"
              '';
            in
            {
              imports = [ inputs.clankers.nixosModules.clankers-daemon ];

              # Make the CLI available system-wide for `clankers rpc`, `clankers attach`, etc.
              environment.systemPackages = [ clankersPkg ];

              # Let admin users connect to the daemon control socket.
              users.users.brittonr.extraGroups = [ "clankers" ];

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
                # --api-base is a CLI flag, not an env var. Pass it via extraArgs
                # on the ExecStart command line.
                (mkIf (settings.apiBase != null) {
                  environment.ANTHROPIC_API_KEY = "sk-ant-proxy";
                  serviceConfig.ExecStart = lib.mkForce (
                    "${clankersPkg}/bin/clankers"
                    + " --api-base ${settings.apiBase}"
                    + " daemon start"
                    + " --heartbeat ${toString settings.heartbeat}"
                    + lib.optionalString settings.allowAll " --allow-all"
                    + lib.concatMapStrings (a: " ${a}") settings.extraArgs
                  );
                })
                # Seed Nix-declared schedules before the daemon starts.
                (mkIf hasSchedules {
                  serviceConfig.ExecStartPre = [ "+${mergeScript}" ];
                })
                # Put the control socket in /run/clankers/ (created by
                # RuntimeDirectory) instead of private /tmp/ namespace.
                # Relax sandboxing so iroh can bind its QUIC endpoint.
                {
                  environment.XDG_RUNTIME_DIR = "/run/clankers";
                  serviceConfig = {
                    PrivateTmp = lib.mkForce false;
                    ProtectSystem = lib.mkForce "full";
                    ProtectHome = lib.mkForce "read-only";
                    # Socket needs group-write so clankers group members
                    # can connect via `clankers daemon status/sessions/attach`.
                    UMask = "0002";
                  };
                }
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

              # Point the router at the deployed auth.json.
              # --auth-file is a global flag (before the subcommand), so we
              # override ExecStart rather than using extraArgs (which append
              # after `serve`).
              # Exit code 1 = "no providers configured" — treat as clean exit
              # so switch-to-configuration doesn't report a failed unit.
              # --auth-file is a global flag (before the subcommand), so we
              # override ExecStart rather than using extraArgs.
              systemd.services.clanker-router.serviceConfig = mkMerge [
                { SuccessExitStatus = "1 2"; }
                (mkIf useOAuth {
                  ExecStart = lib.mkForce (
                    "${routerPkg}/bin/clanker-router"
                    + " --auth-file ${config.clan.core.vars.generators.${generatorName}.files.auth-json.path}"
                    + " serve --proxy-addr ${settings.listenAddr}:${toString settings.listenPort}"
                    + lib.concatMapStrings (k: " --proxy-key ${k}") settings.proxyKeys
                    + lib.concatMapStrings (a: " ${a}") settings.extraArgs
                  );
                })
              ];

              # Make clanker-router CLI available for `auth login`.
              environment.systemPackages = [ routerPkg ];

              clan.core.vars.generators.${generatorName} =
                if useOAuth then
                  {
                    # OAuth: build auth.json from per-account tokens.
                    # Run `clanker-router auth login --account <name>` locally,
                    # then extract tokens from ~/.config/clanker-router/auth.json:
                    #   jq -r '.providers.anthropic.accounts.<name>.access_token'
                    share = true;
                    files.auth-json = {
                      secret = true;
                      deploy = true;
                      owner = "clanker-router";
                      group = "clanker-router";
                    };

                    prompts = builtins.listToAttrs (
                      map (account: {
                        name = "${account}-access-token";
                        value = {
                          description = "OAuth access token for '${account}'";
                          type = "line";
                          persist = true;
                        };
                      }) settings.oauthAccounts
                    );

                    runtimeInputs = [ pkgs.coreutils ];

                    script =
                      let
                        accountJson = account: ''
                          access_${account}="$(tr -dc '[:print:]' < "$prompts/${account}-access-token")"
                        '';
                        # Build the JSON account entry for each account.
                        accountEntry = account: ''
                          "${account}": {
                                    "credential_type": "oauth",
                                    "access_token": "$access_${account}",
                                    "refresh_token": "",
                                    "expires_at_ms": 4102444800000
                                  }'';
                        accountEntries = builtins.concatStringsSep "," (map accountEntry settings.oauthAccounts);
                      in
                      ''
                        ${builtins.concatStringsSep "\n" (map accountJson settings.oauthAccounts)}
                        cat > "$out/auth-json" <<EOF
                        {
                          "version": 2,
                          "providers": {
                            "anthropic": {
                              "active_account": "${settings.oauthActiveAccount}",
                              "accounts": {
                                ${accountEntries}
                              }
                            }
                          }
                        }
                        EOF
                      '';
                  }
                else
                  {
                    # API keys: prompted once, SOPS-encrypted, deployed as env file.
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
