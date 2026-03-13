_: {
  machines = {
    # ========== Britton Machines ===========
    britton-fw = {
      name = "britton-fw";
      tags = [
        "hm-laptop"
        "update-prefetch"
        "ssd-optimization"
        "perf-tuning"
        "dev"
        "laptop"
        "laptop-input"
        "greeter"
        "audio"
        "grub-theme"
        "remote-builders"
        "xdg-portal"
        "prometheus"
        "monitoring"
        "homepage-server"
        "static-test"
        "static-demo"
        "traefik-blr"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "typst"
        "llm-client"
        "cross-compile"
        "creative"
        "docker"
        "taskwarrior"
        # "radicle-node"
      ];
      deploy = {
        targetHost = "root@iroh-britton-fw";
        buildHost = "";
      };
    };
    britton-gpd = {
      name = "britton-gpd";
      tags = [
        "hm-laptop"
        "ssd-optimization"
        "perf-tuning"
        "dev"
        "laptop"
        "laptop-input"
        "greeter"
        "audio"
        "grub-theme"
        "remote-builders"
        "xdg-portal"
        "prometheus"
        "monitoring"
        "homepage-server"
        # "static-test"
        # "static-demo"
        # "traefik-blr"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "typst"
        "llm-client"
        "cross-compile"
        "creative"
        "taskwarrior"
        # "radicle-node"
      ];
      deploy = {
        targetHost = "root@iroh-britton-gpd";
        buildHost = "";
      };
    };

    bonsai = {
      name = "bonsai";
      tags = [
        "hm-laptop"
        "ssd-optimization"
        "perf-tuning"
        "dev"
        "laptop"
        "laptop-input"
        "greeter"
        "audio"
        "grub-theme"
        "remote-builders"
        "xdg-portal"
        "prometheus"
        "monitoring"
        "homepage-server"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "typst"
        "llm-client"
        "cross-compile"
        "creative"
        "taskwarrior"
        "udev-rules"
        "gaming"
      ];
      deploy = {
        targetHost = "root@iroh-bonsai";
        buildHost = "";
      };
    };

    aspen1 = {
      name = "aspen1";
      tags = [
        "hm-server"
        "minimal-docs"
        "ssd-optimization"
        "docker"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        # "llm"
        "amd-gpu" # AMD Ryzen AI MAX+ 395 with Radeon 8060S
        "initrd-ssh"
      ];
      deploy = {
        targetHost = "root@iroh-aspen1";
        buildHost = "";
      };
    };

    aspen2 = {
      name = "aspen2";
      tags = [
        "hm-server"
        "minimal-docs"
        "ssd-optimization"
        "docker"
        "tailnet-brittonr"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        "amd-gpu" # AMD Ryzen AI MAX+ 395 with Radeon 8060S
        "initrd-ssh"
      ];
      deploy = {
        targetHost = "root@iroh-aspen2";
        buildHost = "";
      };
    };

    britton-desktop = {
      name = "britton-desktop";
      tags = [
        # hm-desktop applied via direct machine reference in users.nix
        "update-prefetch"
        "ssd-optimization"
        "perf-tuning"
        "dev"
        "desktop"
        "laptop-input"
        "greeter" # Using cosmic-greeter instead
        "audio"
        "xdg-portal"
        "nvidia"
        "creative"
        "media"
        "prometheus"
        "monitoring"
        "homepage-server"
        "traefik-desktop"
        "static-test"
        "static-demo"
        "docker"
        "llm-client"
        "llm"
        "password-manager"
        "remote-builders"
        "cross-compile"
        "udev-rules"
        # "radicle-seed"
        "cloud-hypervisor-host" # TAP networking for RedoxOS development
        "taskwarrior"
        "initrd-ssh"
      ];
      deploy = {
        targetHost = "root@britton-desktop";
        buildHost = "";
      };
    };

    pine = {
      name = "pine";
      tags = [
        "hm-server"
        "minimal-docs"
        "pinenote"
        "tailnet-brittonr"
        "dev"
      ];
      deploy = {
        targetHost = "root@iroh-pine";
        buildHost = "britton-desktop";
      };
    };

    # ========== VMs ===========
    utm-vm = {
      name = "utm-vm";
      tags = [
        "hm-server"
        "minimal-docs"
        "ssd-optimization"
        "dev"
      ];
      deploy = {
        targetHost = "root@utm-vm";
        buildHost = "";
      };
    };

    # ========== macOS Machines ===========
    britton-air = {
      name = "britton-air";
      machineClass = "darwin";
      tags = [ ];
      deploy = {
        targetHost = "brittonr@britton-air.local";
        buildHost = "";
      };
    };

  };
}
