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
              settings = extendSettings (ms.mkDefaults schema.daemon);
              daemonGeneratorName = "clankers-daemon-${instanceName}";

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
              daemonExecStart =
                "${clankersPkg}/bin/clankers"
                + " --model ${settings.model}"
                + " daemon start"
                + " --heartbeat ${toString settings.heartbeat}"
                + lib.optionalString settings.allowAll " --allow-all"
                + lib.concatMapStrings (a: " ${a}") settings.extraArgs;

              routerEnabled = config.services.clanker-router.enable or false;
              emailEnabled = settings.emailAuth;

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
                # Route through the colocated proxy when apiBase is set.
                # clankers' in-process discovery can treat any OpenAI-compatible
                # endpoint as an Ollama-style local provider via OLLAMA_HOST,
                # which lets the daemon see all models exposed by clanker-router
                # (`/v1/models` includes Anthropic + the remote Lemonade models).
                # Disable RPC auto-connect so startup doesn't race the router.
                (mkIf (settings.apiBase != null) {
                  environment.OLLAMA_HOST = settings.apiBase;
                  environment.CLANKERS_NO_DAEMON = "1";
                })
                # Seed Nix-declared schedules before the daemon starts.
                (mkIf hasSchedules {
                  serviceConfig.ExecStartPre = [ "+${mergeScript}" ];
                })
                # Email plugin auth: inject Fastmail token + config as env vars.
                (mkIf emailEnabled {
                  serviceConfig.EnvironmentFile = [
                    config.clan.core.vars.generators.${daemonGeneratorName}.files.email-env.path
                  ];
                })
                # Auto-create a session after daemon starts so schedules
                # have somewhere to route.
                (mkIf hasSchedules {
                  serviceConfig.ExecStartPost = [
                    "${pkgs.writeShellScript "clankers-auto-session" ''
                      # Wait for the control socket to appear.
                      for i in $(seq 1 30); do
                        [ -S /run/clankers/control.sock ] && break
                        sleep 0.5
                      done
                      export XDG_RUNTIME_DIR=/run/clankers
                      exec ${clankersPkg}/bin/clankers daemon create
                    ''}"
                  ];
                })
                # Put the control socket in /run/clankers/ (created by
                # RuntimeDirectory) instead of private /tmp/ namespace.
                # Relax sandboxing so iroh can bind its QUIC endpoint.
                {
                  environment.XDG_RUNTIME_DIR = "/run/clankers";
                  serviceConfig = {
                    ExecStart = lib.mkForce daemonExecStart;
                    PrivateTmp = lib.mkForce false;
                    ProtectSystem = lib.mkForce "full";
                    ProtectHome = lib.mkForce "read-only";
                    # Socket needs group-write so clankers group members
                    # can connect via `clankers daemon status/sessions/attach`.
                    UMask = "0002";
                  };
                }
              ];
              # ── Email auth vars generator ──────────────────────────────
              clan.core.vars.generators.${daemonGeneratorName} = mkIf emailEnabled {
                share = true;
                files.email-env = {
                  secret = true;
                  deploy = true;
                  owner = "clankers";
                  group = "clankers";
                };

                prompts = {
                  fastmail-api-token = {
                    description = "Fastmail API token (Bearer token for JMAP)";
                    type = "hidden";
                    persist = true;
                  };
                  email-from = {
                    description = "Default sender email address (e.g. bot@example.com)";
                    type = "line";
                    persist = true;
                  };
                  email-allowed-recipients = {
                    description = "Comma-separated allowed recipients (emails or @domain patterns)";
                    type = "line";
                    persist = true;
                  };
                };

                runtimeInputs = [ pkgs.coreutils ];

                script = ''
                  token="$(tr -d '\n' < "$prompts/fastmail-api-token")"
                  from="$(tr -d '\n' < "$prompts/email-from")"
                  recipients="$(tr -d '\n' < "$prompts/email-allowed-recipients")"
                  {
                    printf 'FASTMAIL_API_TOKEN=%s\n' "$token"
                    printf 'CLANKERS_EMAIL_FROM=%s\n' "$from"
                    printf 'CLANKERS_EMAIL_ALLOWED_RECIPIENTS=%s\n' "$recipients"
                  } > "$out/email-env"
                '';
              };
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
              routerPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.clanker-router;
              hasLocalProviders = settings.localProviders != [ ];
              localProvidersJson = pkgs.writeText "clanker-router-local-providers.json" (
                builtins.toJSON (
                  map (provider: {
                    inherit (provider) name models;
                    api_base = provider.apiBase;
                  }) settings.localProviders
                )
              );
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
              // lib.optionalAttrs hasLocalProviders {
                localProviderConfig = localProvidersJson;
              }
              // lib.optionalAttrs useOAuth {
                authSeedFile = config.clan.core.vars.generators.${generatorName}.files.auth-json.path;
                authRuntimeFile = "/var/lib/clanker-router/auth-runtime.json";
              }
              // lib.optionalAttrs (!useOAuth) {
                environmentFile = config.clan.core.vars.generators.${generatorName}.files.env-file.path;
              };

              # Exit code 1 = "no providers configured" — treat as clean exit
              # so switch-to-configuration doesn't report a failed unit.
              systemd.services.clanker-router.serviceConfig = {
                SuccessExitStatus = "1 2";
              };

              # Make clanker-router CLI available for `auth login`.
              environment.systemPackages = [ routerPkg ];

              clan.core.vars.generators.${generatorName} =
                if useOAuth then
                  {
                    # OAuth: build auth.json from provider/account-scoped
                    # export records, plus optional API-key providers for
                    # hybrid routing. Export records come from:
                    #   clankers auth export <provider> --account <name>
                    #   clanker-router auth export <provider> --account <name>
                    share = true;
                    files.auth-json = {
                      secret = true;
                      deploy = true;
                      owner = "clanker-router";
                      group = "clanker-router";
                    };

                    prompts =
                      (builtins.listToAttrs (
                        map (record: {
                          name = "${record.provider}-${record.account}-record";
                          value = {
                            description = "OAuth record JSON for '${record.provider}/${record.account}'";
                            type = "hidden";
                            persist = true;
                          };
                        }) settings.oauthRecords
                      ))
                      // {
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

                    runtimeInputs = [ pkgs.python3Minimal ];

                    script = ''
                                            export PROMPTS_DIR="$prompts"
                                            export OAUTH_RECORDS='${builtins.toJSON settings.oauthRecords}'
                                            python <<'PY'
                      import json
                      import os
                      from pathlib import Path

                      prompts_dir = Path(os.environ["PROMPTS_DIR"])


                      def read_prompt(name: str) -> str:
                          return (prompts_dir / name).read_text(encoding="utf-8").strip()


                      def read_optional_prompt(name: str) -> str:
                          value = read_prompt(name)
                          return "" if value == "Welcome to SOPS! Edit this file as you please!" else value


                      providers = {}
                      for record_spec in json.loads(os.environ["OAUTH_RECORDS"]):
                          prompt_name = f"{record_spec['provider']}-{record_spec['account']}-record"
                          raw_record = read_optional_prompt(prompt_name)
                          if not raw_record:
                              continue
                          record = json.loads(raw_record)
                          provider = record.get("provider", record_spec["provider"])
                          account = record.get("account", record_spec["account"])
                          if provider != record_spec["provider"] or account != record_spec["account"]:
                              raise SystemExit(
                                  f"record {prompt_name} does not match expected provider/account {record_spec['provider']}/{record_spec['account']}"
                              )
                          provider_entry = providers.setdefault(provider, {
                              "active_account": None,
                              "accounts": {},
                          })
                          provider_entry["accounts"][account] = record["credential"]
                          if record.get("active") or record_spec.get("active") or provider_entry["active_account"] is None:
                              provider_entry["active_account"] = account

                      for provider, prompt_name in {
                          "openai": "openai-api-key",
                          "openrouter": "openrouter-api-key",
                      }.items():
                          api_key = read_optional_prompt(prompt_name)
                          if api_key:
                              providers[provider] = {
                                  "active_account": "default",
                                  "accounts": {
                                      "default": {
                                          "credential_type": "api_key",
                                          "api_key": api_key,
                                      }
                                  },
                              }

                      auth_path = Path(os.environ["out"]) / "auth-json"
                      auth_path.write_text(
                          json.dumps({"version": 2, "providers": providers}, indent=2) + "\n",
                          encoding="utf-8",
                      )
                      PY
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
