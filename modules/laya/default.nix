{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "laya";
    description = "Laya English typed decisions on CPU or compensated FP32 Vulkan";
    readme = "Private research service with a pinned Hugging Face resource and an explicit CPU or native Vulkan backend";
    categories = [ "AI/ML" ];
  };
  roles.server = {
    description = "Private laya API";
    interface = mkSettings.mkInterface schema.server;
    perInstance = { instanceName, extendSettings, ... }: {
      nixosModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          ms = import ../../lib/mk-settings.nix { inherit lib; };
          cfg = extendSettings (ms.mkDefaults schema.server);
          vulkan = cfg.backend == "vulkan-compensated-fp32";
          package = if vulkan then pkgs.laya-cpp else pkgs.laya;
          name = "laya-${instanceName}";
          state = "/var/lib/${name}";
          cache = if vulkan then "/var/cache/${name}" else "${state}/cache";
          radvIcd = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
          baseArgs = [
            "--state-dir"
            state
            "--revision"
            cfg.revision
          ];
          serveArgs = baseArgs ++ [
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
            "--threads"
            "4"
          ];
        in
        {
          # r[impl onix.research-tools.private-deployment]
          assertions = [
            {
              assertion =
                cfg.host == "127.0.0.1"
                ||
                  builtins.match "100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}" cfg.host
                  != null;
              message = "laya must bind loopback or a Tailscale IPv4 address, never a public interface";
            }
            {
              assertion =
                !vulkan || (pkgs.stdenv.hostPlatform.system == "x86_64-linux" && config.hardware.graphics.enable);
              message = "laya vulkan-compensated-fp32 requires x86_64 Linux with hardware.graphics.enable and the RADV driver";
            }
            {
              assertion = !vulkan || cfg.revision == "1c5edc17a7acd8701df6fc341c0d179f1c62c982";
              message = "laya vulkan-compensated-fp32 uses the prepackaged offline model revision 1c5edc17a7acd8701df6fc341c0d179f1c62c982";
            }
          ];
          networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals (
            cfg.host != "127.0.0.1"
          ) [ cfg.port ];
          users.groups.render = lib.mkIf vulkan { };
          systemd.services.${name} = {
            description = "Laya English typed decisions (${cfg.backend})";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [
              "network-online.target"
              "tailscaled.service"
            ];
            environment = {
              HOME = state;
              HF_HOME = state;
              XDG_CACHE_HOME = cache;
              HF_HUB_DISABLE_TELEMETRY = "1";
              HF_HUB_DOWNLOAD_TIMEOUT = "60";
              HF_HUB_ETAG_TIMEOUT = "30";
              PYTHONUNBUFFERED = "1";
            }
            // lib.optionalAttrs vulkan {
              HF_HUB_OFFLINE = "1";
              TRANSFORMERS_OFFLINE = "1";
              # Select only RADV, never the host's development ICD/layer defaults or lavapipe.
              AMD_VULKAN_ICD = "RADV";
              VK_DRIVER_FILES = radvIcd;
              VK_ICD_FILENAMES = radvIcd;
              VK_LOADER_LAYERS_DISABLE = "*";
              GGML_VK_VISIBLE_DEVICES = "0";
              MESA_SHADER_CACHE_DIR = cache;
            };
            serviceConfig = {
              Type = "simple";
              DynamicUser = true;
              StateDirectory = name;
              StateDirectoryMode = "0700";
              ExecStartPre = "${lib.getExe package} prepare ${lib.escapeShellArgs baseArgs}";
              ExecStart = "${lib.getExe package} serve ${lib.escapeShellArgs serveArgs}";
              TimeoutStartSec = "2h";
              Restart = "on-failure";
              RestartSec = 5;
              MemoryMax = "6G";
              CPUQuota = "400%";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = !vulkan;
              ProtectHome = true;
              ProtectSystem = "strict";
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
            }
            // lib.optionalAttrs vulkan {
              SupplementaryGroups = [ "render" ];
              DevicePolicy = "closed";
              DeviceAllow = [ "/dev/dri/renderD128 rw" ];
              CacheDirectory = name;
              CacheDirectoryMode = "0700";
              UnsetEnvironment = [
                "VK_INSTANCE_LAYERS"
                "VK_LAYER_PATH"
                "VK_ADD_LAYER_PATH"
                "VK_LOADER_LAYERS_ENABLE"
                "VK_LOADER_LAYERS_ALLOW"
              ];
            };
          };
        };
    };
  };
}
