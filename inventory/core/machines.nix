_: {
  machines = {
    alex-dev = {
      name = "alex-dev";
      tags = [
        "tailnet-adeci"
      ];
      deploy = {
        targetHost = "root@alex-dev";
        buildHost = "";
      };
    };
    alex-fw = {
      name = "alex-fw";
      tags = [
        "tailnet-adeci"
        "laptop"
        "hyprland"
        "nixvegas"
      ];
      deploy = {
        targetHost = "root@alex-fw";
        buildHost = "";
      };
    };
    alex-wsl = {
      name = "alex-wsl";
      tags = [
        "tailnet-adeci"
        "wsl"
      ];
      deploy = {
        targetHost = "root@alex-wsl";
        buildHost = "";
      };
    };
    alex-mu = {
      name = "alex-mu";
      tags = [
        "tailnet-adeci"
        "dev"
      ];
      deploy = {
        targetHost = "root@alex-mu";
        buildHost = "";
      };
    };
    britton-dev = {
      name = "britton-dev";
      tags = [
        # No tailnet for now
      ];
      deploy = {
        targetHost = "root@192.168.1.146";
        buildHost = "";
      };
    };
    britton-desktop = {
      name = "britton-desktop";
      tags = [
        # "tailnet"
        "dev"
        "desktop"
        "nvidia"
        "hyprland"
        "creative"
        "media"
        "prometheus"
        "monitoring"
        "vaultwarden-server"
        "homepage-server"
        "traefik-desktop"
        "static-test"
        "static-demo"
        "onix-cache"
        "seaweedfs-volume"
      ];
      deploy = {
        targetHost = "root@britton-desktop";
        buildHost = "";
      };
    };
    britton-fw = {
      name = "britton-fw";
      tags = [
        "laptop"
        "nixvegas"
        "hyprland"
        "prometheus"
        "log-collector"
        "homepage-server"
        "traefik-homepage"
        "static-test"
        "static-demo"
        "wiki-js"
        "nix-cache"
        "seaweedfs-master"
        "onix-cache"
      ];
      deploy = {
        targetHost = "root@britton-fw";
        buildHost = "";
      };
    };
    gmk1 = {
      name = "gmk1";
      tags = [
        "tailnet-brittonr"
        # "desktop"
        # "hyprland"
        "prometheus"
        "log-collector"
        "onix-cache"
      ];
      deploy = {
        targetHost = "root@192.168.8.201";
        buildHost = "";
      };
    };
    gmk2 = {
      name = "gmk2";
      tags = [
        "tailnet-brittonr"
        "prometheus"
        "log-collector"
        "onix-cache"
      ];
      deploy = {
        targetHost = "root@192.168.8.122";
        buildHost = "";
      };
    };
    gmk3 = {
      name = "gmk3";
      tags = [
        "tailnet-brittonr"
        # "desktop"
        # "hyprland"
        "prometheus"
        "log-collector"
        "onix-cache"
      ];
      deploy = {
        targetHost = "root@192.168.8.167";
        buildHost = "";
      };
    };
    sequoia = {
      name = "sequoia";
      tags = [
        "tailnet"
        "dev"
        "vaultwarden-server"
      ];
      deploy = {
        targetHost = "root@sequoia";
        buildHost = "";
      };
    };
    zenith = {
      name = "zenith";
      tags = [
        "tailnet"
        "laptop"
        "hyprland"
        "nixvegas"
      ];
      deploy = {
        targetHost = "root@zenith";
        buildHost = "";
      };
    };
  };
}
