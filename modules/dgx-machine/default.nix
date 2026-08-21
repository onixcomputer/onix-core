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
  rwkvProfile = import ./rwkv7-profile.nix;
  localBackendInstanceName = "dgx-local";
  localBackendUnit = "llamacpp-server-${localBackendInstanceName}.service";
  minimumLlamaCppVersion = "10133";
  loopbackHost = "127.0.0.1";
  llamaApiPort = 13305;
  disabledNumericOption = 0;
  defaultMetaliumInspectorPort = 50051;

  localModel = cfg.services.localModel;
  localLlamaSettings = {
    host = loopbackHost;
    port = llamaApiPort;
    backend = "cuda";
    modelRepo = localModel.repository;
    modelFile = localModel.file;
    modelRevision = localModel.revision;
    modelSha256 = localModel.sha256;
    extraModelFiles = [ ];
    draftModelSource = "download";
    draftModelRepo = "";
    draftModelFile = "";
    draftModelRevision = "main";
    modelAlias = localModel.alias;
    inherit (localModel) gpuLayers;
    metaliumDeviceId = disabledNumericOption;
    metaliumInspectorPort = defaultMetaliumInspectorPort;
    metaliumTrace = false;
    inherit (localModel) contextSize;
    generationThreads = disabledNumericOption;
    batchThreads = disabledNumericOption;
    batchSize = disabledNumericOption;
    ubatchSize = disabledNumericOption;
    parallelSlots = disabledNumericOption;
    cacheTypeK = null;
    cacheTypeV = null;
    inherit (localModel) flashAttention;
    gpuPerformanceLock = false;
    inherit (localModel) noMmap;
    inherit (localModel) enableMetrics;
    autoStart = true;
    inherit (localModel) extraArgs;
  };
  localLlamaConfig = import ../llamacpp-server/mk-nixos-config.nix {
    inherit inputs lib pkgs;
    instanceName = localBackendInstanceName;
    settings = localLlamaSettings;
  };

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
    endpointUrl = "http://${loopbackHost}:${toString llamaApiPort}/v1";
    proxyActivationModel = cfg.services.meshActivationModel;
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
    (lib.mkIf (!cfg.services.meshBackendExternallyManaged) localLlamaConfig)
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
      meshActivationModel = lib.mkOption {
        type = lib.types.strMatching "[a-zA-Z0-9._/+:-]+";
        default = rwkvProfile.alias;
        description = "Model name that Mesh-LLM sends to the owned backend.";
      };
      localModel = lib.mkOption {
        description = "Hash-pinned GGUF profile for the local DGX llama.cpp backend.";
        default = { };
        type = lib.types.submodule {
          options = {
            alias = lib.mkOption {
              type = lib.types.strMatching "[a-zA-Z0-9._/+:-]+";
              default = rwkvProfile.alias;
            };
            repository = lib.mkOption {
              type = lib.types.strMatching "[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+";
              default = rwkvProfile.repository;
            };
            revision = lib.mkOption {
              type = lib.types.strMatching "[0-9a-f]{40}";
              default = rwkvProfile.revision;
            };
            file = lib.mkOption {
              type = lib.types.strMatching "[a-zA-Z0-9._/+:-]+[.]gguf";
              default = rwkvProfile.file;
            };
            sha256 = lib.mkOption {
              type = lib.types.strMatching "[0-9a-f]{64}";
              default = rwkvProfile.sha256;
            };
            contextSize = lib.mkOption {
              type = lib.types.ints.positive;
              default = rwkvProfile.contextSize;
            };
            gpuLayers = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = rwkvProfile.gpuLayers;
            };
            flashAttention = lib.mkOption {
              type = lib.types.bool;
              default = rwkvProfile.flashAttention;
            };
            noMmap = lib.mkOption {
              type = lib.types.bool;
              default = rwkvProfile.noMmap;
            };
            enableMetrics = lib.mkOption {
              type = lib.types.bool;
              default = rwkvProfile.enableMetrics;
            };
            extraArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = rwkvProfile.extraArgs;
            };
          };
        };
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
            {
              assertion =
                cfg.services.meshBackendExternallyManaged || cfg.services.meshBackendUnit == localBackendUnit;
              message = "The local DGX backend must be ${localBackendUnit}.";
            }
            {
              assertion =
                cfg.services.meshBackendExternallyManaged || cfg.services.meshActivationModel == localModel.alias;
              message = "The local DGX model alias must match the Mesh-LLM activation model.";
            }
            {
              assertion =
                cfg.services.meshBackendExternallyManaged
                || lib.versionAtLeast pkgs.llama-cpp.version minimumLlamaCppVersion;
              message = "The DGX local backend requires llama.cpp ${minimumLlamaCppVersion} or newer.";
            }
          ];
        }
        serviceConfig
      ]
    ))
  ];
}
