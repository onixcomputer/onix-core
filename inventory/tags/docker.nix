{ pkgs, ... }:
{
  # Enable Docker virtualisation
  virtualisation.docker = {
    enable = true;

    # Enable on boot for containers with --restart=always
    enableOnBoot = true;

    # Enable live restore to keep containers running during daemon downtime
    liveRestore = true;

    # Configure Docker daemon
    daemon.settings = {
      # Storage configuration
      storage-driver = "overlay2";
      data-root = "/var/lib/docker";

      # Logging configuration
      log-driver = "journald";
      log-opts = {
        # journald driver only supports tag option
        # Size limits are managed by systemd-journald itself
        tag = "{{.Name}}/{{.ID}}";
      };

      # Network configuration
      default-address-pools = [
        {
          base = "172.30.0.0/16";
          size = 24;
        }
      ];

      # DNS configuration
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      # Security options
      userland-proxy = false;
      experimental = true;

      # Registry configuration
      registry-mirrors = [ "https://mirror.gcr.io" ];
      insecure-registries = [ ];
    };

    # Prune old images and containers regularly
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [
        "--all"
        "--volumes"
      ];
    };
  };

  # Alternative: Podman configuration (commented out - choose one)
  # virtualisation.podman = {
  #   enable = true;
  #   dockerCompat = true; # Create docker alias
  #   defaultNetwork.settings.dns_enabled = true;
  # };

  # Enable container tools
  virtualisation.containers.enable = true;

  # GPU support for containers (if nvidia tag is present)
  # Note: nvidia-container-toolkit will be enabled automatically by the nvidia tag if present

  # Install Docker-related packages
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-buildx
    docker-credential-helpers
    dive # Docker image layer explorer
    lazydocker # Terminal UI for Docker
    ctop # Container metrics viewer
    podman-tui # Terminal UI for containers (works with Docker too)
  ];

  # Firewall configuration for Docker
  networking.firewall = {
    # Trust the Docker bridge interface
    trustedInterfaces = [ "docker0" ];

    # Allow Docker's default bridge network range
    extraCommands = ''
      iptables -A nixos-fw -i docker0 -j ACCEPT
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -i docker0 -j ACCEPT 2>/dev/null || true
    '';
  };

  # Enable kernel modules required by Docker
  boot.kernelModules = [
    "overlay"
    "br_netfilter"
  ];

  # Sysctl settings for Docker
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Security settings
  security = {
    # AppArmor profiles for Docker containers
    apparmor.enable = true;

    # Unprivileged user namespaces (for rootless containers)
    unprivilegedUsernsClone = true;
  };

  # Systemd service configuration
  systemd = {
    services = {
      docker = {
        # Ensure Docker starts after network is online
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        # Restart policy
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
          StartLimitInterval = "60s";
          StartLimitBurst = 3;
        };
      };
      # Optional: Docker garbage collection service
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

  # Create docker group and add users
  # Note: Users need to be added to docker group in their user configuration
  # users.users.<username>.extraGroups = [ "docker" ];
  users.groups.docker = { };

  # Optional: Enable BuildKit by default
  environment.variables = {
    DOCKER_BUILDKIT = "1";
    BUILDKIT_PROGRESS = "auto";
  };

}
