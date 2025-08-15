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
        "wiki-js"
        "nixvegas"
        "traefik-blrdev"
      ];
      deploy = {
        targetHost = "root@192.168.1.146";
        buildHost = "";
      };
    };
    britton-desktop = {
      name = "britton-desktop";
      tags = [
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
        # "tailnet-brittonr"
        # "traefik-desktop"
        # "static-test"
        "static-demo"
        # "seaweedfs-volume"
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
        "hyprland"
        "prometheus"
        "monitoring"
        "homepage-server"
        "static-test"
        "static-demo"
        "nix-cache"
        "seaweedfs-master"
        "traefik-blr"
        "tailnet-brittonr"
        "onix-cache"
        "openpgp"
      ];
      deploy = {
        targetHost = "root@britton-fw.bison-tailor.ts.net";
        buildHost = "";
      };
    };
    gmk1 = {
      name = "gmk1";
      tags = [
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
