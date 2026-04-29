{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "hermes-gateway";
    description = "Hermes Agent messaging gateway";
    readme = "Runs `hermes gateway run` as a managed service with Matrix credentials from clan vars.";
    categories = [
      "AI/ML"
      "Messaging"
    ];
  };

  roles.default = {
    description = "Hermes Agent gateway host";
    interface = mkSettings.mkInterface schema.default;

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
            settings = extendSettings (ms.mkDefaults schema.default);

            generatorName = "hermes-gateway-${instanceName}";
            serviceName = "hermes-gateway-${instanceName}";
            envFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;

            trueString = value: if value then "true" else "false";
            optionalEnvLine =
              name: value:
              lib.optionalString (value != null && value != "") ''
                printf '%s=%s\n' ${lib.escapeShellArg name} ${lib.escapeShellArg value}
              '';
            optionalListEnvLine = name: values: optionalEnvLine name (lib.concatStringsSep "," values);
            managedEnvKeys = [
              "MATRIX_ACCESS_TOKEN"
              "MATRIX_ALLOWED_USERS"
              "MATRIX_AUTO_THREAD"
              "MATRIX_DM_MENTION_THREADS"
              "MATRIX_ENCRYPTION"
              "MATRIX_FREE_RESPONSE_ROOMS"
              "MATRIX_HOMESERVER"
              "MATRIX_HOME_ROOM"
              "MATRIX_REACTIONS"
              "MATRIX_REQUIRE_MENTION"
            ];
            managedEnvPattern = lib.concatStringsSep "|" managedEnvKeys;
            matrixSettingsHash = builtins.hashString "sha256" (
              builtins.toJSON {
                inherit (settings)
                  allowedUsers
                  autoThread
                  dmMentionThreads
                  enableEncryption
                  freeResponseRooms
                  homeRoom
                  homeserver
                  reactions
                  requireMention
                  ;
              }
            );

            secretFileMode = "0600";
            stateDirMode = "0700";
            restartDelay = "10s";
            stopTimeout = "120s";
            libolmPackageName = "olm-3.2.16";

            agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
            hermesBasePackage = agentPkgs.hermes-agent;
            hermesPackage =
              if settings.enableEncryption then
                hermesBasePackage.overridePythonAttrs (old: {
                  propagatedBuildInputs =
                    (old.propagatedBuildInputs or [ ])
                    ++ (with pkgs.python3.pkgs; [
                      base58
                      pycryptodome
                      python-olm
                      unpaddedbase64
                    ]);
                  pythonImportsCheck = (old.pythonImportsCheck or [ ]) ++ [ "mautrix.crypto" ];
                })
              else
                hermesBasePackage;

            packageByName =
              name: lib.attrByPath [ name ] (throw "hermes-gateway: unknown nixpkgs package '${name}'") pkgs;
            servicePathPackages = [ hermesPackage ] ++ map packageByName settings.extraPackages;

            syncEnv = pkgs.writeShellApplication {
              name = "hermes-gateway-sync-env";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gawk
              ];
              text = ''
                install -d -m ${stateDirMode} -o ${settings.user} -g ${settings.group} ${lib.escapeShellArg settings.hermesHome}
                install -d -m ${stateDirMode} -o ${settings.user} -g ${settings.group} ${lib.escapeShellArg "${settings.hermesHome}/platforms/matrix/store"}

                target=${lib.escapeShellArg "${settings.hermesHome}/.env"}
                temp="$(mktemp "''${target}.tmp.XXXXXX")"
                trap 'rm -f "$temp"' EXIT

                if [ -f "$target" ]; then
                  awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/ { if ($1 ~ /^(${managedEnvPattern})$/) next } { print }' "$target" > "$temp"
                else
                  : > "$temp"
                fi

                {
                  printf '\n# Managed by onix-core hermes-gateway clan service; local edits to MATRIX_* are overwritten.\n'
                  cat ${lib.escapeShellArg envFile}
                } >> "$temp"

                install -m ${secretFileMode} -o ${settings.user} -g ${settings.group} "$temp" "$target"
              '';
            };
          in
          {
            assertions = [
              {
                assertion = !settings.enableEncryption || settings.acceptInsecureLibolm;
                message = "hermes-gateway ${instanceName}: enableEncryption requires acceptInsecureLibolm = true because nixpkgs marks libolm insecure/deprecated (CVE-2024-45191/45192/45193).";
              }
              {
                assertion = settings.allowedUsers != [ ];
                message = "hermes-gateway ${instanceName}: allowedUsers must not be empty; Hermes denies all Matrix users otherwise.";
              }
            ];

            nixpkgs.config.permittedInsecurePackages =
              lib.mkIf (settings.enableEncryption && settings.acceptInsecureLibolm)
                [
                  libolmPackageName
                ];

            clan.core.vars.generators.${generatorName} = {
              share = true;
              files."env-file" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "root";
              };
              prompts.matrix-access-token = {
                description = "Matrix access token for the Hermes bot account";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''
                token="$(tr -d '\n' < "$prompts/matrix-access-token")"
                if [ -z "$token" ] || [ "$token" = "Welcome to SOPS! Edit this file as you please!" ]; then
                  echo "Matrix access token for Hermes gateway is unset" >&2
                  exit 1
                fi

                {
                  printf 'MATRIX_HOMESERVER=%s\n' ${lib.escapeShellArg settings.homeserver}
                  printf 'MATRIX_ACCESS_TOKEN=%s\n' "$token"
                  printf 'MATRIX_ALLOWED_USERS=%s\n' ${lib.escapeShellArg (lib.concatStringsSep "," settings.allowedUsers)}
                  printf 'MATRIX_REQUIRE_MENTION=%s\n' ${lib.escapeShellArg (trueString settings.requireMention)}
                  printf 'MATRIX_AUTO_THREAD=%s\n' ${lib.escapeShellArg (trueString settings.autoThread)}
                  printf 'MATRIX_DM_MENTION_THREADS=%s\n' ${lib.escapeShellArg (trueString settings.dmMentionThreads)}
                  printf 'MATRIX_REACTIONS=%s\n' ${lib.escapeShellArg (trueString settings.reactions)}
                  printf 'MATRIX_ENCRYPTION=%s\n' ${lib.escapeShellArg (trueString settings.enableEncryption)}
                  ${optionalListEnvLine "MATRIX_FREE_RESPONSE_ROOMS" settings.freeResponseRooms}
                  ${optionalEnvLine "MATRIX_HOME_ROOM" settings.homeRoom}
                } > "$out/env-file"
              '';
            };

            systemd.tmpfiles.rules = [
              "d ${settings.hermesHome} ${stateDirMode} ${settings.user} ${settings.group} -"
              "d ${settings.hermesHome}/platforms ${stateDirMode} ${settings.user} ${settings.group} -"
              "d ${settings.hermesHome}/platforms/matrix ${stateDirMode} ${settings.user} ${settings.group} -"
              "d ${settings.hermesHome}/platforms/matrix/store ${stateDirMode} ${settings.user} ${settings.group} -"
            ];

            systemd.services.${serviceName} = {
              description = "Hermes Agent Matrix gateway (${instanceName})";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              path = servicePathPackages;
              environment = {
                HOME = settings.userHome;
                HERMES_ACCEPT_HOOKS = "1";
                HERMES_HOME = settings.hermesHome;
                HERMES_GATEWAY_MATRIX_SETTINGS_HASH = matrixSettingsHash;
                HERMES_REDACT_SECRETS = "true";
                XDG_CACHE_HOME = "${settings.userHome}/.cache";
                XDG_CONFIG_HOME = "${settings.userHome}/.config";
                XDG_DATA_HOME = "${settings.userHome}/.local/share";
              }
              // settings.extraEnv;
              serviceConfig = {
                Type = "simple";
                User = settings.user;
                Group = settings.group;
                WorkingDirectory = settings.workingDirectory;
                ExecStartPre = "+${lib.getExe syncEnv}";
                ExecStart = "${lib.getExe hermesPackage} --accept-hooks gateway run";
                Restart = "on-failure";
                RestartSec = restartDelay;
                TimeoutStopSec = stopTimeout;
                PrivateTmp = true;
                NoNewPrivileges = true;
              };
            };

          };
      };
  };
}
