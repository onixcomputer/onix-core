_: {
  machines = {

    # ========== Alex Machines ===========
    alex-fw = {
      name = "alex-fw";
      tags = [
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
        "tailnet-adeci"
        "dev"
      ];
      deploy = {
        targetHost = "root@alex-fw.cymric-daggertooth.ts.net";
        buildHost = "";
      };
    };

    sequoia = {
      name = "sequoia";
      tags = [
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

    # ========== Britton Machines ===========
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
        "seaweedfs-master"
        "garage-server"
        "traefik-blr"
        "tailnet-brittonr"
        "openpgp"
        "password-manager"
        "infrastructure-dev" # Development infrastructure environment
      ];
      deploy = {
        targetHost = "root@britton-fw.bison-tailor.ts.net";
        buildHost = "";
      };
    };

    aspen1 = {
      name = "aspen1";
      tags = [
        "tailnet-brittonr"
        "dev"
        "prometheus"
        "monitoring"
        "homepage-server"
        "infrastructure-prod" # Production infrastructure environment
      ];
      deploy = {
        targetHost = "root@aspen1";
        buildHost = "";
      };
    };

    britton-dev = {
      name = "britton-dev";
      tags = [
        "dev"
        "wiki-js"
        "traefik-blrdev"
        "infrastructure-staging" # Staging infrastructure environment
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
        "homepage-server"
        "traefik-desktop"
        "static-test"
        "static-demo"
        "seaweedfs-volume"
        "docker"
        "llm"
        "password-manager"
      ];
      deploy = {
        targetHost = "root@127.0.0.1";
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

    # ========== Dima Machines ===========
    zenith = {
      name = "zenith";
      tags = [
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
