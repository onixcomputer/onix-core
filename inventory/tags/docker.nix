{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    liveRestore = true; # Keep containers running during daemon downtime

    daemon.settings = {
      storage-driver = "overlay2";
      data-root = "/var/lib/docker";

      log-driver = "journald";
      log-opts.tag = "{{.Name}}/{{.ID}}";

      default-address-pools = [
        {
          base = "172.30.0.0/16";
          size = 24;
        }
      ];

      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      userland-proxy = false;
      experimental = true;

      registry-mirrors = [ "https://mirror.gcr.io" ];
      insecure-registries = [ ];
    };

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [
        "--all"
        "--volumes"
      ];
    };
  };

  virtualisation.containers.enable = true;

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-buildx
    docker-credential-helpers
    dive # Docker image layer explorer
    lazydocker # Terminal UI for Docker
    ctop # Container metrics viewer
    podman-tui # Terminal UI for containers
  ];

  # trustedInterfaces handles docker0 traffic - nftables manages this automatically
  networking.firewall.trustedInterfaces = [ "docker0" ];

  boot.kernelModules = [
    "overlay"
    "br_netfilter"
  ];

  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  security = {
    apparmor.enable = true;
    unprivilegedUsernsClone = true; # For rootless containers
  };

  systemd = {
    services = {
      docker = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
        startLimitIntervalSec = 60;
        startLimitBurst = 3;
      };

      docker-gc = {
        description = "Docker garbage collection";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.docker}/bin/docker system prune -af --volumes";
        };
      };
    };

    timers.docker-gc = {
      description = "Docker garbage collection timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };

  users.groups.docker = { };

  environment.variables = {
    DOCKER_BUILDKIT = "1";
    BUILDKIT_PROGRESS = "auto";
  };

}
