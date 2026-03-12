_: {
  machines = {
    # ========== Britton Machines ===========
    britton-fw = {
      name = "britton-fw";
      tags = [
        "all"
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
        "hyprland"
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
        targetHost = "root@britton-fw";
        buildHost = "";
      };
    };
    britton-gpd = {
      name = "britton-gpd";
      tags = [
        "all"
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
        "hyprland"
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
        targetHost = "root@britton-gpd"; # Use hostname instead of hardcoded IP
        buildHost = "";
      };
    };

    bonsai = {
      name = "bonsai";
      tags = [
        "all"
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
        "hyprland"
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
        targetHost = "root@100.126.162.16"; # Update with actual hostname or IP
        buildHost = "";
      };
    };

    aspen1 = {
      name = "aspen1";
      tags = [
        "all"
        "ssd-optimization"
        "docker"
        "tailnet-brittonr"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        # "llm" # Disabled: Using llm-gptoss instance with vLLM instead of ollama
        "amd-gpu" # AMD Ryzen AI MAX+ 395 with Radeon 8060S
      ];
      deploy = {
        targetHost = "root@aspen1";
        buildHost = "";
      };
    };

    aspen2 = {
      name = "aspen2";
      tags = [
        "all"
        "ssd-optimization"
        "docker"
        "tailnet-brittonr"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        "amd-gpu" # AMD Ryzen AI MAX+ 395 with Radeon 8060S
      ];
      deploy = {
        targetHost = "root@aspen2"; # Update with actual hostname or IP
        buildHost = "";
      };
    };

    britton-desktop = {
      name = "britton-desktop";
      tags = [
        "all"
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
      ];
      deploy = {
        targetHost = "root@britton-desktop";
        buildHost = "";
      };
    };

    pine = {
      name = "pine";
      tags = [
        "all"
        "pinenote"
        "tailnet-brittonr"
        "dev"
      ];
      deploy = {
        targetHost = "root@pine.bison-tailor.ts.net";
        buildHost = "britton-desktop";
      };
    };

    # ========== VMs ===========
    utm-vm = {
      name = "utm-vm";
      tags = [
        "all"
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
        targetHost = "brittonr@192.168.1.55";
        buildHost = "";
      };
    };

  };
}
