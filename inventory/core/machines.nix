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
        "tailnet"
        "dev"
        "desktop"
        "nvidia"
        "hyprland"
        "creative"
        "media"
      ];
      deploy = {
        targetHost = "root@britton-desktop-2";
        buildHost = "";
      };
    };
    "britton-fw" = {
      name = "britton-fw";
      tags = [
        "tailnet"
        "laptop"
        "hyprland"
      ];
      deploy = {
        targetHost = "root@britton-fw";
        buildHost = "";
      };
    };
    "alex-dev" = {
      name = "alex-dev";
      tags = [
        "tailnet"
      ];
      deploy = {
        targetHost = "root@100.92.205.115";
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
        targetHost = "root@100.97.151.9";
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
        targetHost = "root@100.112.158.103";
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
        targetHost = "root@192.168.50.173";
        buildHost = "";
      };
    };
  };
}
