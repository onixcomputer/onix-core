# Pure OpenTofu Library Functions - No derivations, pkgs-independent
# These functions work with nix-unit for fast testing
{ lib }:

{
  # Generate LoadCredential entries for systemd services
  generateLoadCredentials =
    generatorName: credentialMapping:
    lib.mapAttrsToList (
      tfVar: clanVar: "${tfVar}:/run/secrets/vars/${generatorName}/${clanVar}"
    ) credentialMapping;

  # Generate terraform.tfvars script content
  generateTfvarsScript = credentialMapping: extraContent: ''
    # Generate terraform.tfvars from clan vars
    cat > terraform.tfvars <<EOF
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        tfVar: _: "${tfVar} = \"$(cat \"$CREDENTIALS_DIRECTORY/${tfVar}\")\""
      ) credentialMapping
    )}
    ${extraContent}
    EOF
  '';

  # Basic terranix config validation (structure only)
  validateTerranixConfig =
    config:
    if builtins.isAttrs config && config != { } then
      config
    else
      throw "validateTerranixConfig: Configuration must be a non-empty attribute set";

  # Pure string manipulation utilities
  makeServiceName = serviceName: instanceName: "${serviceName}-${instanceName}";

  makeStateDirectory = serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform";

  makeLockFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock";

  # Configuration hash utilities
  generateConfigId = config: builtins.hashString "sha256" (builtins.toJSON config);

  # Credential mapping validation
  validateCredentialMapping =
    mapping:
    if builtins.isAttrs mapping && mapping != { } then
      mapping
    else
      throw "validateCredentialMapping: Mapping must be a non-empty attribute set";

  # Backend configuration generators (pure string generation)
  generateS3BackendConfig =
    { serviceName, instanceName }:
    ''
      terraform {
        backend "s3" {
          endpoint = "http://127.0.0.1:3900"
          bucket = "terraform-state"
          key = "${serviceName}/${instanceName}/terraform.tfstate"
          region = "garage"
          skip_credentials_validation = true
          skip_metadata_api_check = true
          skip_region_validation = true
          force_path_style = true
        }
      }
    '';

  generateLocalBackendConfig = ''
    terraform {
      backend "local" {
        path = "terraform.tfstate"
      }
    }
  '';

  # Service configuration helpers
  makeDeploymentServiceName =
    serviceName: instanceName: "${serviceName}-terraform-deploy-${instanceName}";

  makeGarageInitServiceName = instanceName: "garage-terraform-init-${instanceName}";

  # Script name generators for helper scripts
  makeUnlockScriptName = serviceName: instanceName: "${serviceName}-tf-unlock-${instanceName}";
  makeStatusScriptName = serviceName: instanceName: "${serviceName}-tf-status-${instanceName}";
  makeApplyScriptName = serviceName: instanceName: "${serviceName}-tf-apply-${instanceName}";
  makeLogsScriptName = serviceName: instanceName: "${serviceName}-tf-logs-${instanceName}";

  # Path utilities
  makeLockInfoFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info";
  makeDeployCompleteFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete";

  # Configuration merging utilities
  mergeConfigurations = configs: lib.foldl' lib.recursiveUpdate { } configs;

  # Variable extraction from terranix configs
  extractVariables = config: if config ? variable then builtins.attrNames config.variable else [ ];

  extractResources =
    config:
    if config ? resource then
      lib.flatten (
        lib.mapAttrsToList (
          type: resources: map (name: { inherit type name; }) (builtins.attrNames resources)
        ) config.resource
      )
    else
      [ ];

  # Helper for testing - extract service components
  extractServiceComponents = serviceName: instanceName: {
    stateDir = "/var/lib/${serviceName}-${instanceName}-terraform";
    lockFile = "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock";
    lockInfoFile = "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info";
    deploymentServiceName = "${serviceName}-terraform-deploy-${instanceName}";
    scriptNames = {
      unlock = "${serviceName}-tf-unlock-${instanceName}";
      status = "${serviceName}-tf-status-${instanceName}";
      apply = "${serviceName}-tf-apply-${instanceName}";
      logs = "${serviceName}-tf-logs-${instanceName}";
    };
  };
}
