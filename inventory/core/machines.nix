_: {
  machines = {
    alex-fw = {
      name = "alex-fw";
      tags = [
        "tailnet-adeci"
        "passmanager"
        "laptop"
        "dev"
        "hyprland"
      ];
      deploy = {
        targetHost = "root@alex-fw.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };
    marine = {
      name = "marine";
      tags = [
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
        "tailnet-adeci"
        "wsl"
        "dev"
      ];
      deploy = {
        targetHost = "root@alex-wsl";
        buildHost = "";
      };
    };
    aspen1 = {
      name = "aspen1";
      tags = [
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        "nix-cache"
        "seaweedfs-master"
        "traefik-blr"
        "tailnet-brittonr"
        "onix-cache"
        "openpgp"
        "mcp"
      ];
      deploy = {
        targetHost = "root@aspen1.bison-tailor.ts.net";
        buildHost = "root@aspen1.bison-tailor.ts.net";
      };
    };
    britton-dev = {
      name = "britton-dev";
      tags = [
        "dev"
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
        "traefik-desktop"
        "static-test"
        "static-demo"
        "seaweedfs-volume"
        "mcp"
      ];
      deploy = {
        targetHost = "192.168.1.252";
        buildHost = "";
      };
    };
    britton-fw = {
      name = "britton-fw";
      tags = [
        "dev"
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
        "mcp"
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
        "dev"
        "tailnet-adeci"
        "dev"
        "vaultwarden-server"
      ];
      deploy = {
        targetHost = "root@sequoia.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };
    zenith = {
      name = "zenith";
      tags = [
        "dev"
        "tailnet-dima"
        "laptop"
        "hyprland"
      ];
      deploy = {
        targetHost = "root@zenith.clouded-hammerhead.ts.net";
        buildHost = "";
      };
    };
  };
}
