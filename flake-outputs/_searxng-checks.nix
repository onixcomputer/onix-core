{
  self,
  pkgs,
  lib,
  ...
}:
let
  wasm = import ../lib/wasm.nix { plugins = self.packages.x86_64-linux.wasm-plugins; };
  schema = wasm.evalNickelFile ../modules/searxng/schema.ncl;
  service = (import ../modules/searxng { inherit schema; }) { inherit lib; };
  fixtureName = "fixture";
  secretPath = "/run/secrets/searxng-fixture";
  kagiSecretPath = "/run/secrets/searxng-fixture-kagi";
  tidalSecretPath = "/run/secrets/searxng-fixture-tidal";
  defaultPort = schema.server.port.default;
  customPort = 8899;
  invalidPort = 65536;
  stateVersion = "26.05";
  resolve =
    overrides: defaults:
    (lib.evalModules {
      modules = [
        { options.settings = lib.mkOption { type = lib.types.submodule service.roles.server.interface; }; }
        { settings = defaults; }
        { settings = overrides; }
      ];
    }).config.settings;
  nodeWith =
    overrides: extraModules:
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit pkgs;
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        (service.roles.server.perInstance {
          instanceName = fixtureName;
          extendSettings = resolve overrides;
        }).nixosModule
        (
          { lib, ... }:
          {
            options.clan.core.vars.generators = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
            };
            config = {
              clan.core.vars.generators = {
                "searxng-${fixtureName}".files."env-file".path = secretPath;
                "searxng-${fixtureName}-kagi".files."env-file".path = kagiSecretPath;
                "searxng-${fixtureName}-tidal".files."env-file".path = tidalSecretPath;
              };
              system.stateVersion = stateVersion;
            };
          }
        )
      ]
      ++ extraModules;
    }).config;
  node = overrides: nodeWith overrides [ ];
  serveModule = ../machines/aspen1/searxng-serve.nix;
  serve = nodeWith { } [ serveModule ];
  unsafeServe = nodeWith { bindAddress = "0.0.0.0"; } [ serveModule ];
  defaults = node { };
  developers = node { enableDeveloperEngines = true; };
  developerPackage = import ../modules/searxng/kagi-package.nix {
    inherit pkgs;
    enableKagi = false;
    enableDeveloperEngines = true;
  };
  developerPython = pkgs.python3.withPackages (ps: [
    developerPackage
    ps.pytest
  ]);
  tidal = node { enableTidal = true; };
  tidalWithKagi = node {
    enableTidal = true;
    enableKagi = true;
  };
  tidalEngine = lib.findFirst (
    engine: engine.name == "tidal"
  ) null tidal.services.searx.settings.engines;
  tidalSharedEngine = lib.findFirst (
    engine: engine.name == "tidal"
  ) null tidalWithKagi.services.searx.settings.engines;
  tidalGenerator = tidal.clan.core.vars.generators.searxng-fixture-tidal;
  tidalGeneratorScript = pkgs.writeShellScript "searxng-tidal-secret-fixture" tidalGenerator.script;
  tidalPackage = import ../modules/searxng/kagi-package.nix {
    inherit pkgs;
    enableKagi = false;
    enableTidal = true;
  };
  tidalPython = pkgs.python3.withPackages (ps: [
    tidalPackage
    ps.pytest
  ]);
  kagi = node { enableKagi = true; };
  kagiEngine = builtins.head kagi.services.searx.settings.engines;
  kagiDefaults = node {
    enableKagi = true;
    kagiDefault = true;
    kagiHealthCheck = true;
  };
  monitoredKagi =
    nodeWith
      {
        enableKagi = true;
        kagiHealthCheck = true;
        baseUrl = "https://search.example.net/";
      }
      [
        {
          services.prometheus.enable = true;
          services.prometheus.exporters.blackbox.enable = true;
        }
      ];
  kagiGenerator = kagi.clan.core.vars.generators.searxng-fixture-kagi;
  kagiGeneratorScript = pkgs.writeShellScript "searxng-kagi-secret-fixture" kagiGenerator.script;
  kagiPackage = import ../modules/searxng/kagi-package.nix { inherit pkgs; };
  kagiPython = pkgs.python3.withPackages (ps: [
    kagiPackage
    ps.pytest
  ]);
  kagiTestSettings = (pkgs.formats.yaml { }).generate "kagi-test-settings.yml" {
    use_default_settings = true;
    server.secret_key = "offline-test-not-a-secret";
  };
  custom = node {
    bindAddress = "::1";
    port = customPort;
    baseUrl = "https://search.example.net/";
    instanceName = "Private search";
    enableJson = false;
    limiter = false;
    openFirewall = true;
    firewallInterface = "wg-search";
  };
  rejected =
    overrides:
    !(builtins.tryEval (
      builtins.deepSeq (resolve overrides (
        (import ../lib/mk-settings.nix { inherit lib; }).mkDefaults schema.server
      )) true
    )).success;
  assertionRejects =
    overrides:
    lib.any (a: !a.assertion && lib.hasPrefix "SearXNG" a.message) (node overrides).assertions;
  validation = wasm.evalNickelFile ../inventory/services/fixtures/searxng-validation.ncl;
  results = {
    tidalPrivate = tidalEngine.tokens == [ "$TIDAL_ENGINE_TOKEN" ];
    tidalSharesExistingBrowserGate = tidalSharedEngine.tokens == [ "$KAGI_ENGINE_TOKEN" ];
    tidalOnlyAccessSnapshot =
      tidalEngine.session_token == "$TIDAL_SESSION_TOKEN" && !(tidalGenerator.prompts ? refresh-token);
    tidalSecretsPrivate =
      tidalGenerator.files.env-file.mode == "0400" && !tidalGenerator.files.session-token.deploy;
    tidalRuntime =
      tidal.systemd.services.searx-init.serviceConfig.EnvironmentFile == [
        secretPath
        tidalSecretPath
      ];
    tidalCombinedRuntime =
      tidalWithKagi.systemd.services.searx-init.serviceConfig.EnvironmentFile == [
        secretPath
        kagiSecretPath
        tidalSecretPath
      ];
    tidalShortcut = tidalEngine.shortcut == "tidal" && !tidalEngine.disabled;
    youtubeNative = lib.any (
      engine:
      engine.name == "youtube"
      && engine.engine == "youtube_noapi"
      && engine.shortcut == "yt"
      && !engine.disabled
    ) tidal.services.searx.settings.engines;
    rejectTidalType = rejected { enableTidal = "yes"; };
    developerNames =
      map (engine: engine.name) developers.services.searx.settings.engines == [
        "github"
        "nixos options"
        "home manager"
        "noogle"
      ];
    developerShortcuts =
      map (engine: engine.shortcut) developers.services.searx.settings.engines == [
        "gh"
        "nixopts"
        "hm"
        "noogle"
      ];
    developerEnabled = lib.all (engine: !engine.disabled) developers.services.searx.settings.engines;
    developersNeedNoKagiSecret =
      developers.systemd.services.searx-init.serviceConfig.EnvironmentFile == secretPath
      && !(developers.clan.core.vars.generators.searxng-fixture-kagi ? prompts);
    kagiOptIn = kagiEngine.disabled && kagiEngine.shortcut == "kg";
    kagiPrivate = kagiEngine.tokens == [ "$KAGI_ENGINE_TOKEN" ];
    kagiDefaultEnabledAndPrivate =
      !(builtins.head kagiDefaults.services.searx.settings.engines).disabled
      && (builtins.head kagiDefaults.services.searx.settings.engines).tokens == kagiEngine.tokens;
    kagiDailyHealth = kagiDefaults.systemd.timers.searxng-kagi-health.timerConfig.OnCalendar == "daily";
    kagiHealthUsesRuntimeSecret =
      kagiDefaults.systemd.services.searxng-kagi-health.serviceConfig.EnvironmentFile == kagiSecretPath;
    kagiHealthDefaultOff = !(defaults.systemd.services ? searxng-kagi-health);
    availabilityProbe = lib.any (
      job:
      job.job_name == "searxng-health"
      && (builtins.head job.static_configs).targets == [ "https://search.example.net/healthz" ]
    ) monitoredKagi.services.prometheus.scrapeConfigs;
    noAvailabilityProbeWithoutExporter =
      !(lib.any (job: job.job_name == "searxng-health") kagiDefaults.services.prometheus.scrapeConfigs);
    healthAlerts = lib.any (
      rule: lib.hasInfix "KagiSessionCheckFailed" rule && lib.hasInfix "SearxngUnavailable" rule
    ) monitoredKagi.services.prometheus.rules;
    rejectKagiDefaultWithoutEngine = lib.any (
      a: !a.assertion && lib.hasPrefix "Kagi defaults" a.message
    ) (node { kagiDefault = true; }).assertions;
    rejectKagiHealthWithoutEngine = lib.any (
      a: !a.assertion && lib.hasPrefix "Kagi defaults" a.message
    ) (node { kagiHealthCheck = true; }).assertions;
    kagiSessionReference = kagiEngine.session_token == "$KAGI_SESSION_TOKEN";
    kagiTimeout = kagiEngine.timeout == schema.server.kagiTimeoutSeconds.default;
    kagiRuntimeSecrets =
      kagi.systemd.services.searx-init.serviceConfig.EnvironmentFile == [
        secretPath
        kagiSecretPath
      ];
    kagiHiddenPrompt = kagiGenerator.prompts.session-token.type == "hidden";
    kagiSecretScope =
      !kagiGenerator.files.session-token.deploy
      && !kagiGenerator.files.access-token.deploy
      && kagiGenerator.files.env-file.mode == "0400";
    kagiDefaultOff = !(defaults.services.searx.settings ? engines);
    rejectKagiType = rejected { enableKagi = "yes"; };
    rejectKagiTimeout =
      lib.any (a: !a.assertion && lib.hasPrefix "Kagi timeout" a.message)
        (node { kagiTimeoutSeconds = 0; }).assertions;
    tailscaleProxy = lib.hasInfix "serve --bg --https=443 --set-path=/ http://127.0.0.1:${toString defaultPort}" serve.systemd.services.searxng-serve.serviceConfig.ExecStart;
    noFunnel = !(lib.hasInfix "funnel" serve.systemd.services.searxng-serve.serviceConfig.ExecStart);
    loopbackProxyTrust =
      serve.services.searx.limiterSettings.botdetection.trusted_proxies == [
        "127.0.0.1/32"
        "::1/128"
      ];
    rejectsExposedProxyBackend = lib.any (
      a: !a.assertion && lib.hasInfix "loopback SearXNG" a.message
    ) unsafeServe.assertions;
    registered = builtins.hasAttr "searxng" (import ../modules { inherit (self) inputs; });
    schemaAccepted = validation.positive == [ ];
    schemaRejected = lib.all (field: lib.any (error: lib.hasInfix field error) validation.negative) (
      builtins.attrNames schema.server
    );
    enabled = defaults.services.searx.enable && defaults.services.searx.package == pkgs.searxng;
    privateListener =
      defaults.services.uwsgi.instance.vassals.searx.http == "127.0.0.1:${toString defaultPort}";
    noAccessLogs = defaults.services.uwsgi.instance.vassals.searx.disable-logging;
    noDebug = !defaults.services.searx.settings.general.debug;
    noGlobalFirewall = defaults.networking.firewall.allowedTCPPorts == [ ];
    noDefaultInterfaceFirewall =
      !(builtins.hasAttr "tailscale0" defaults.networking.firewall.interfaces);
    secretReference = defaults.services.searx.settings.server.secret_key == "$SEARX_SECRET_KEY";
    secretRuntime = defaults.systemd.services.searx-init.serviceConfig.EnvironmentFile == secretPath;
    secretPrivate =
      defaults.clan.core.vars.generators.searxng-fixture.files.env-file.secret
      && defaults.clan.core.vars.generators.searxng-fixture.files.env-file.mode == "0400";
    initDependency = builtins.elem "searx-init.service" defaults.systemd.services.uwsgi.requires;
    localLimiter =
      defaults.services.searx.settings.server.limiter
      && defaults.services.redis.servers.searx.enable
      && defaults.services.redis.servers.searx.port == 0;
    jsonEnabled =
      defaults.services.searx.settings.search.formats == [
        "html"
        "json"
      ];
    customListener =
      custom.services.uwsgi.instance.vassals.searx.http == "[::1]:${toString customPort}";
    customIdentity =
      custom.services.searx.settings.general.instance_name == "Private search"
      && custom.services.searx.settings.server.base_url == "https://search.example.net/";
    customFirewall =
      custom.networking.firewall.interfaces.wg-search.allowedTCPPorts == [ customPort ]
      && custom.networking.firewall.allowedTCPPorts == [ ];
    jsonDisabled = custom.services.searx.settings.search.formats == [ "html" ];
    limiterDisabled =
      !custom.services.searx.settings.server.limiter
      && !(builtins.hasAttr "searx" custom.services.redis.servers);
    rejectPortType = rejected { port = toString defaultPort; };
    rejectPortRange = rejected { port = invalidPort; };
    rejectBool = rejected { enableJson = "yes"; };
    rejectEmptyAddress = assertionRejects { bindAddress = ""; };
    rejectAddressUrl = assertionRejects { bindAddress = "http://localhost"; };
    rejectBaseUrl = assertionRejects { baseUrl = "file:///etc/passwd"; };
    rejectEmptyInterface = assertionRejects {
      openFirewall = true;
      firewallInterface = "";
    };
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) results);
  generator = defaults.clan.core.vars.generators.searxng-fixture;
  generatorScript = pkgs.writeShellScript "searxng-secret-fixture" generator.script;
  secretBytes = 32;
  hexCharactersPerByte = 2;
  secretHexLength = secretBytes * hexCharactersPerByte;
in
{
  checks = {
    searxng-module =
      pkgs.runCommand "searxng-module"
        {
          nativeBuildInputs = generator.runtimeInputs;
        }
        ''
          ${lib.optionalString (failed != [ ]) ''
            echo ${lib.escapeShellArg "SearXNG checks failed: ${lib.concatStringsSep ", " failed}"}
            exit 1
          ''}
          result_path="$out"
          mkdir valid failed bin
          out="$PWD/valid" ${generatorScript}
          grep -Eq '^SEARX_SECRET_KEY=[0-9a-f]{${toString secretHexLength}}$' valid/env-file
          printf '#!%s\nexit 1\n' '${pkgs.runtimeShell}' > bin/openssl
          chmod +x bin/openssl
          if PATH="$PWD/bin:$PATH" out="$PWD/failed" ${generatorScript}; then
            echo "SearXNG secret generation accepted an OpenSSL error"
            exit 1
          fi
          test ! -e failed/env-file
          mkdir kagi-prompts kagi-valid kagi-invalid kagi-failed
          printf '%s' 'fixture-session' > kagi-prompts/session-token
          prompts="$PWD/kagi-prompts" out="$PWD/kagi-valid" ${kagiGeneratorScript}
          grep -Fqx 'KAGI_SESSION_TOKEN=fixture-session' kagi-valid/env-file
          grep -Eq '^[0-9a-f]{${toString secretHexLength}}$' kagi-valid/access-token
          printf '%s' 'invalid;session' > kagi-prompts/session-token
          if prompts="$PWD/kagi-prompts" out="$PWD/kagi-invalid" ${kagiGeneratorScript}; then
            echo "Kagi generator accepted an unsafe session token"
            exit 1
          fi
          test ! -e kagi-invalid/env-file
          printf '%s' 'fixture-session' > kagi-prompts/session-token
          if PATH="$PWD/bin:$PATH" prompts="$PWD/kagi-prompts" out="$PWD/kagi-failed" ${kagiGeneratorScript}; then
            echo "Kagi generator accepted an OpenSSL error"
            exit 1
          fi
          test ! -e kagi-failed/env-file
          printf '%s\n' ${lib.escapeShellArg (builtins.toJSON results)} > "$result_path"
        '';
    searxng-tidal =
      pkgs.runCommand "searxng-tidal"
        {
          nativeBuildInputs = [ tidalPython ] ++ tidalGenerator.runtimeInputs;
          SEARXNG_SETTINGS_PATH = kagiTestSettings;
        }
        ''
          export HOME="$TMPDIR"
          python ${../modules/searxng/test_tidal.py} -v
          result_path="$out"
          mkdir prompts valid invalid
          printf '%s' 'fixture-tidal' > prompts/session-token
          prompts="$PWD/prompts" out="$PWD/valid" ${tidalGeneratorScript}
          grep -Fqx 'TIDAL_SESSION_TOKEN=fixture-tidal' valid/env-file
          grep -Eq '^[0-9a-f]{${toString secretHexLength}}$' valid/access-token
          printf '%s' 'invalid;token' > prompts/session-token
          if prompts="$PWD/prompts" out="$PWD/invalid" ${tidalGeneratorScript}; then
            echo "Tidal generator accepted an unsafe access token"
            exit 1
          fi
          test ! -e invalid/env-file
          touch "$result_path"
        '';
    searxng-developer-engines =
      pkgs.runCommand "searxng-developer-engines"
        {
          nativeBuildInputs = [ developerPython ];
          SEARXNG_SETTINGS_PATH = kagiTestSettings;
        }
        ''
          export HOME="$TMPDIR"
          python ${../modules/searxng/test_specialist.py} -v
          touch "$out"
        '';
    searxng-kagi-session =
      pkgs.runCommand "searxng-kagi-session"
        {
          nativeBuildInputs = [
            kagiPython
            pkgs.nodejs
          ];
          KAGI_UNLOCK_SCRIPT = "${kagiPackage}/${pkgs.python3.sitePackages}/searx/static/kagi-unlock.js";
          SEARXNG_SETTINGS_PATH = kagiTestSettings;
        }
        ''
          export HOME="$TMPDIR"
          python ${../modules/searxng/test_kagi_session.py} -v
           node --test ${../modules/searxng/test_kagi_unlock.cjs}
          touch "$out"
        '';
  };
}
