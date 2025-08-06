_: {
  machines = {
    "britton-dev" = {
      name = "britton-dev";
      tags = [
        "tailnet"
      ];
      deploy = {
        targetHost = "root@192.168.1.146";
        buildHost = "";
      };
    };
    "britton-desktop" = {
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
        "seaweedfs-volume"
      ];
      deploy = {
        targetHost = "root@192.168.1.252";
        buildHost = "";
      };
    };
    "britton-fw" = {
      name = "britton-fw";
      tags = [
        "laptop"
        "hyprland"
        "prometheus"
        "log-collector"
        "homepage-server"
        "traefik-homepage"
        "static-test"
        "static-demo"
        "wiki-js"
        "seaweedfs-master"
      ];
      deploy = {
        targetHost = "root@britton-fw";
        buildHost = "";
      };
    };
    "gmk1" = {
      name = "gmk1";
      tags = [
        "tailnet"
        "dev"
        "desktop"
        "hyprland"
        "creative"
        "media"
        "prometheus"
        "monitoring"
        "vaultwarden-server"
        "homepage-server"
      ];
      deploy = {
        targetHost = "root@gmk1";
        buildHost = "";
      };
    };
    "gmk2" = {
      name = "gmk2";
      tags = [
        "tailnet"
        "desktop"
        "hyprland"
        "prometheus"
        "log-collector"
      ];
      deploy = {
        targetHost = "root@gmk2";
        buildHost = "";
      };
    };
    "gmk3" = {
      name = "gmk3";
      tags = [
        "tailnet"
        "desktop"
        "hyprland"
        "prometheus"
        "log-collector"
      ];
      deploy = {
        targetHost = "root@gmk3";
        buildHost = "";
      };
    };
    "alex-dev" = {
      name = "alex-dev";
      tags = [
        "tailnet"
      ];
      deploy = {
        targetHost = "root@alex-dev";
        buildHost = "";
      };
    };
    "alex-fw" = {
      name = "alex-fw";
      tags = [
        "tailnet"
        "laptop"
        "hyprland"
      ];
      deploy = {
        targetHost = "root@alex-fw";
        buildHost = "";
      };
    };
    "alex-wsl" = {
      name = "alex-wsl";
      tags = [
        "tailnet"
        "wsl"
      ];
      deploy = {
        targetHost = "root@alex-wsl";
        buildHost = "";
      };
    };
    "alex-mu" = {
      name = "alex-mu";
      tags = [
        "tailnet"
        "dev"
      ];
      deploy = {
        targetHost = "root@alex-mu";
        buildHost = "";
      };
    };
    "sequoia" = {
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
  };
}
