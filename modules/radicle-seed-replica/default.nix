# r[impl onix.radicle_replica.configuration]
# r[impl onix.radicle_replica.deployment]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  validateSettings = import ./validate-settings.nix { inherit lib; };
  mkNixosConfig = import ../radicle-node/mk-nixos-config.nix { inherit lib; };
  mkIdentityVerifierService = import ./mk-identity-verifier-service.nix { inherit lib; };

  generatorPrefix = "radicle-seed-replica-";
  privateKeyFileName = "node-private-key";
  publicKeyFileName = "node-public-key";
  privateKeyMode = "0400";
  publicKeyMode = "0444";
  loopbackAddress = "127.0.0.1";
  disabledHttpPort = 8080;
  disabledHttpsOriginPort = 8081;
  identityVerificationServiceName = "radicle-replica-identity-verify";
  mkGeneratorName = instanceName: "${generatorPrefix}${instanceName}";
in
{
  _class = "clan.service";

  manifest = {
    name = "radicle-seed-replica";
    readme = "Selective native-only least-authority Radicle replica";
    description = "Runs the reviewed independent pilot replica without HTTP or repository governance authority";
    categories = [
      "Development"
      "Network"
    ];
  };

  roles.default = {
    description = "Selective native-only Radicle replica";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      let
        generatorName = mkGeneratorName instanceName;
      in
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);
            nodePackage = pkgs.radicle-node;
            httpdPackage = pkgs.radicle-httpd;
            policyReconciler = import ../radicle-node/policy-reconciler.nix { inherit pkgs; };
            identityVerifier = import ./identity-verifier.nix { inherit pkgs; };
            identityFiles = config.clan.core.vars.generators.${generatorName}.files;
            privateKeyPath = identityFiles.${privateKeyFileName}.path;
            publicKeyPath = identityFiles.${publicKeyFileName}.path;
            configFile = config.services.radicle.configFile;
            validationErrors = validateSettings {
              inherit settings;
              packageVersion = nodePackage.version;
              actualHost = config.networking.hostName;
            };
            monitoringAvailable =
              config.services.prometheus.enable && config.services.prometheus.exporters.systemd.enable;
            loweredSettings = {
              inherit (settings)
                alias
                externalAddress
                nodeListenAddress
                nodeListenPort
                nodeFirewallInterface
                seedRepositories
                privateSeedRepositories
                ;
              httpdEnabled = false;
              httpListenAddress = loopbackAddress;
              httpListenPort = disabledHttpPort;
              httpsEnabled = false;
              httpsServerName = null;
              httpsTransport = "cloudflare-tunnel";
              httpsOriginListenAddress = loopbackAddress;
              httpsOriginListenPort = disabledHttpsOriginPort;
              httpsGitRepositories = [ ];
              pinnedRepositories = [ ];
            };
            loweredConfig = mkNixosConfig {
              settings = loweredSettings;
              inherit
                nodePackage
                httpdPackage
                policyReconciler
                privateKeyPath
                publicKeyPath
                configFile
                ;
            };
            identityVerifierService = mkIdentityVerifierService {
              inherit
                identityVerifier
                publicKeyPath
                privateKeyPath
                ;
              expectedFingerprint = settings.expectedNodeFingerprint;
            };
          in
          lib.mkMerge [
            loweredConfig
            {
              assertions =
                map (message: {
                  assertion = false;
                  message = "radicle-seed-replica-${instanceName}: ${message}";
                }) validationErrors
                ++ [
                  {
                    assertion = !settings.monitoringRequired || monitoringAvailable;
                    message = "radicle-seed-replica-${instanceName}: Prometheus and the systemd exporter must monitor the replica";
                  }
                ];

              systemd.services = {
                radicle-node = {
                  after = [ "${identityVerificationServiceName}.service" ];
                  requires = [ "${identityVerificationServiceName}.service" ];
                  unitConfig.RequiresMountsFor = [ settings.stateDirectory ];
                };
                ${identityVerificationServiceName} = identityVerifierService;
                radicle-policy-reconcile.unitConfig.RequiresMountsFor = [ settings.stateDirectory ];
              };

              clan.core.vars.generators.${generatorName} = {
                files = {
                  ${privateKeyFileName} = {
                    secret = true;
                    deploy = true;
                    owner = "root";
                    group = "root";
                    mode = privateKeyMode;
                  };
                  ${publicKeyFileName} = {
                    secret = false;
                    deploy = true;
                    owner = "root";
                    group = "root";
                    mode = publicKeyMode;
                  };
                };

                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.openssh
                ];

                script = ''
                  private_key="$out/${privateKeyFileName}"
                  temporary_public_key="$private_key.pub"
                  public_key="$out/${publicKeyFileName}"

                  ssh-keygen -q -t ed25519 -N "" -C "" -f "$private_key"
                  cut -d ' ' -f 1-2 "$temporary_public_key" > "$public_key"
                  rm "$temporary_public_key"
                  chmod ${privateKeyMode} "$private_key"
                  chmod ${publicKeyMode} "$public_key"
                '';
              };
            }
          ];
      };
  };
}
