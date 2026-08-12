{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.onix.dgxMachine;
  requiredSystem = "aarch64-linux";
  actualSystem = pkgs.stdenv.hostPlatform.system;
  brittonUserName = "brittonr";
  brittonUid = 1555;
  adminGroup = "wheel";
  frameworkAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];

  sendmePackage = pkgs.callPackage ../../pkgs/sendme { };
  meshLlmPackage = pkgs.callPackage ../../pkgs/mesh-llm { };

  defaultSshPort = 22;
  meshApiPort = 9337;
  meshConsolePort = 3131;
  meshTransportPort = 47916;
  meshProxyContextSize = 512;
  meshInstanceName = "dgx-spark";
  runtimeSecretFilePrefix = "/var/lib/onix-dgx-secrets/";

  secretPath = name: cfg.runtimeSecretFiles.${name};
  tailscaleSettings = {
    enableHostAliases = true;
    enableSSH = true;
    exitNode = false;
    extraUpFlags = [ ];
  };
  irohSettings.sshPort = defaultSshPort;
  meshSettings = {
    mode = "joiner";
    endpointUrl = "http://127.0.0.1:13305/v1";
    proxyActivationModel = "Qwen3-0.6B-Q4_K_M";
    proxyActivationContextSize = meshProxyContextSize;
    apiPort = meshApiPort;
    consolePort = meshConsolePort;
    meshBindAddress = "0.0.0.0";
    meshBindInterface = "tailscale0";
    meshPort = meshTransportPort;
    meshName = "onix-private-inference";
    nodeName = null;
    backendUnit = cfg.services.meshBackendUnit;
    backendExternallyManaged = cfg.services.meshBackendExternallyManaged;
  };

  serviceConfig = lib.mkMerge [
    (import ../tailscale/mk-nixos-config.nix {
      inherit config lib pkgs;
      settings = tailscaleSettings;
      authKeyFile = secretPath "tailscaleAuthKey";
    })
    (import ../iroh-ssh/mk-nixos-config.nix {
      inherit config lib pkgs;
      settings = irohSettings;
      privateKeyPath = secretPath "irohPrivateKey";
      publicKeyPath = secretPath "irohPublicKey";
    })
    (import ../mesh-llm/mk-nixos-config.nix {
      inherit config lib pkgs;
      instanceName = meshInstanceName;
      settings = meshSettings;
      joinTokenPath = secretPath "meshJoinToken";
      package = meshLlmPackage;
    })
  ];
in
{
  imports = [
    inputs.dgx-spark.nixosModules.dgx-spark
    ../tailscale/host-sync.nix
  ];

  options.onix.dgxMachine = {
    services = {
      enable = lib.mkEnableOption "the device-free DGX service policy";
      meshBackendUnit = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Local OpenAI-compatible backend systemd unit.";
      };
      meshBackendExternallyManaged = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Declare that another owner supplies the loopback Mesh-LLM backend.";
      };
    };

    runtimeSecretFiles = {
      tailscaleAuthKey = lib.mkOption {
        type = lib.types.str;
        default = "${runtimeSecretFilePrefix}tailscale-auth-key";
      };
      meshJoinToken = lib.mkOption {
        type = lib.types.str;
        default = "${runtimeSecretFilePrefix}mesh-join-token";
      };
      irohPrivateKey = lib.mkOption {
        type = lib.types.str;
        default = "${runtimeSecretFilePrefix}iroh-private-key";
      };
      irohPublicKey = lib.mkOption {
        type = lib.types.str;
        default = "${runtimeSecretFilePrefix}iroh-public-key";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = actualSystem == requiredSystem;
          message = "The DGX machine module requires ${requiredSystem}; got ${actualSystem}.";
        }
      ];

      hardware.dgx-spark.enable = true;
      services.openssh.enable = true;
      programs.fish.enable = true;

      users.groups.${brittonUserName} = { };
      users.users = {
        ${brittonUserName} = {
          uid = brittonUid;
          isNormalUser = true;
          group = brittonUserName;
          shell = pkgs.fish;
          extraGroups = [ adminGroup ];
          openssh.authorizedKeys.keys = lib.mkForce frameworkAuthorizedKeys;
        };
        root.openssh.authorizedKeys.keys = lib.mkForce frameworkAuthorizedKeys;
      };

      environment.systemPackages = [
        sendmePackage
        meshLlmPackage
      ];
    }

    (lib.mkIf cfg.services.enable (
      lib.mkMerge [
        {
          assertions = [
            {
              assertion = lib.all (path: lib.hasPrefix runtimeSecretFilePrefix path) (
                builtins.attrValues cfg.runtimeSecretFiles
              );
              message = "DGX runtime credentials must use the SecretSpec bootstrap directory.";
            }
            {
              assertion =
                (cfg.services.meshBackendUnit != null && cfg.services.meshBackendUnit != "")
                != cfg.services.meshBackendExternallyManaged;
              message = "DGX Mesh-LLM must name one backend unit or declare external ownership.";
            }
          ];
        }
        serviceConfig
      ]
    ))
  ];
}
