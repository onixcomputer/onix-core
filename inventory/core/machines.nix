_: {
  machines = {
    # ========== Alex Machines ===========
    alex-fw = {
      name = "alex-fw";
      tags = [
        "all"
        "tailnet-adeci"
        "password-manager"
        "laptop"
        "dev"
        "hyprland"
      ];
      deploy = {
        targetHost = "root@alex-fw.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    leviathan = {
      name = "leviathan";
      tags = [
        "all"
        "tailnet-adeci"
        "dev"
        "pragmatic"
      ];
      deploy = {
        targetHost = "root@leviathan.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    claudia = {
      name = "claudia";
      tags = [
        "all"
        "tailnet-adeci"
      ];
      deploy = {
        targetHost = "root@claudia.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    sequoia = {
      name = "sequoia";
      tags = [
        "all"
        "dev"
        "tailnet-adeci"
        "docker"
        "gitlab-runner"
      ];
      deploy = {
        targetHost = "root@sequoia.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    marine = {
      name = "marine";
      tags = [
        "all"
        "tailnet-adeci"
        "dev"
      ];
      deploy = {
        targetHost = "root@marine.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    bambrew = {
      name = "bambrew";
      tags = [
        "all"
        "tailnet-adeci"
        "dev"
      ];
      deploy = {
        targetHost = "root@bambrew.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    alex-wsl = {
      name = "alex-wsl";
      tags = [
        "all"
        "tailnet-adeci"
        "wsl"
        "dev"
      ];
      deploy = {
        targetHost = "root@alex-wsl";
        buildHost = "";
      };
    };

    # ========== Britton Machines ===========
    britton-fw = {
      name = "britton-fw";
      tags = [
        "all"
        "dev"
        "laptop"
        "hyprland"
        "prometheus"
        "monitoring"
        "homepage-server"
        "static-test"
        "static-demo"
        "seaweedfs-master"
        "traefik-blr"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "typst"
        "llm-client"
        "cross-compile"
        "creative"
        "docker"
        # "radicle-node"
      ];
      deploy = {
        targetHost = "root@127.0.0.1";
        buildHost = "";
      };
    };
    britton-gpd = {
      name = "britton-gpd";
      tags = [
        "all"
        "dev"
        "laptop"
        "hyprland"
        "prometheus"
        "monitoring"
        "homepage-server"
        # "static-test"
        # "static-demo"
        # "seaweedfs-master"
        # "traefik-blr"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "typst"
        "llm-client"
        "cross-compile"
        "creative"
        # "radicle-node"
      ];
      deploy = {
        targetHost = "root@192.168.1.73";
        buildHost = "";
      };
    };

    aspen1 = {
      name = "aspen1";
      tags = [
        "all"
        "docker"
        "tailnet-brittonr"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        "llm"
        "amd-gpu" # AMD Ryzen AI MAX+ 395 with Radeon 8060S
      ];
      deploy = {
        targetHost = "root@aspen1";
        buildHost = "";
      };
    };

    britton-desktop = {
      name = "britton-desktop";
      tags = [
        "all"
        "dev"
        "desktop"
        "nvidia"
        "hyprland"
        "creative"
        "media"
        "prometheus"
        "monitoring"
        "homepage-server"
        "traefik-desktop"
        "static-test"
        "static-demo"
        "seaweedfs-volume"
        "docker"
        "llm-client"
        "password-manager"
        # "cross-compile"
        "udev-rules"
        # "radicle-seed"
      ];
      deploy = {
        targetHost = "root@britton-desktop";
        buildHost = "";
      };
    };

    gmk1 = {
      name = "gmk1";
      tags = [
        "all"
        "nv"
        "tailnet-brittonr"
        "prometheus"
        "blr-logs"
      ];
      deploy = {
        targetHost = "root@192.168.8.201";
        buildHost = "";
      };
    };

    gmk2 = {
      name = "gmk2";
      tags = [
        "all"
        "nv"
        "tailnet-brittonr"
        "prometheus"
        "blr-logs"
      ];
      deploy = {
        targetHost = "root@192.168.8.121";
        buildHost = "";
      };
    };

    gmk3 = {
      name = "gmk3";
      tags = [
        "all"
        "nv"
        "tailnet-brittonr"
        "prometheus"
        "blr-logs"
      ];
      deploy = {
        targetHost = "root@192.168.8.167";
        buildHost = "";
      };
    };

    # ========== Dima Machines ===========
    zenith = {
      name = "zenith";
      tags = [
        "all"
        "dev"
        "tailnet-dima"
        "laptop"
        "hyprland"
        "password-manager"
      ];
      deploy = {
        targetHost = "root@zenith.clouded-hammerhead.ts.net";
        buildHost = "";
      };
    };
  };
}
