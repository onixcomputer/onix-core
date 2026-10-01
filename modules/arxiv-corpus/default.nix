{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "arxiv-corpus";
    description = "arXiv Complete metadata search and selective paper text";
    readme = "Private CPU-only research service with a pinned Hugging Face resource";
    categories = [ "AI/ML" ];
  };
  roles.server = {
    description = "Private arxiv-corpus API";
    interface = mkSettings.mkInterface schema.server;
    perInstance = { instanceName, extendSettings, ... }: {
      nixosModule =
        { pkgs, lib, ... }:
        let
          ms = import ../../lib/mk-settings.nix { inherit lib; };
          cfg = extendSettings (ms.mkDefaults schema.server);
          package = pkgs.arxiv-corpus;
          name = "arxiv-corpus-${instanceName}";
          state = "/var/lib/${name}";
          baseArgs = [
            "--state-dir"
            state
            "--revision"
            cfg.revision
          ];
          serveArgs = [
            "--state-dir"
            state
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
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
              message = "arxiv-corpus must bind loopback or a Tailscale IPv4 address, never a public interface";
            }
          ];
          networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals (
            cfg.host != "127.0.0.1"
          ) [ cfg.port ];
          systemd.services.${name} = {
            description = "arXiv Complete metadata search and selective paper text";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [
              "network-online.target"
              "tailscaled.service"
            ];
            environment = {
              HOME = state;
              HF_HOME = state;
              XDG_CACHE_HOME = "${state}/cache";
              HF_HUB_DISABLE_TELEMETRY = "1";
              HF_HUB_DOWNLOAD_TIMEOUT = "60";
              HF_HUB_ETAG_TIMEOUT = "30";
              PYTHONUNBUFFERED = "1";
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
              MemoryMax = "4G";
              CPUQuota = "200%";
              NoNewPrivileges = true;
              PrivateTmp = true;
              PrivateDevices = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
            };
          };
        };
    };
  };
}
