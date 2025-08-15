_: {
  alex = {
    description = "Alex";
    defaultUid = 3801;
    defaultGroups = [
      "audio"
      "networkmanager"
      "video"
      "input"
      "plugdev"
    ];
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeeoL1jwVSachA9GdJxm/5TgCRBULfSDGLyP/nfmkMq alex@DESKTOP-SVRV9Q8"
    ];
    machines = {
      alex-fw = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "hyprland"
            "hypr-laptop"
            "creative"
            "social"
          ];
        };
      };
      sequoia = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      alex-mu = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      alex-dev = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      alex-wsl = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      zenith = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "hyprland"
            "hypr-laptop"
            "creative"
            "social"
          ];
        };
      };
    };
  };

  brittonr = {
    description = "Britton";
    defaultUid = 1555;
    defaultGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "kvm"
    ];
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
    ];
    machines = {
      britton-fw = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "hyprland"
            "hypr-laptop"
          ];
        };
      };
      britton-desktop = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "hyprland"
            "creative"
          ];
        };
      };
      gmk1 = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      gmk2 = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      gmk3 = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      britton-dev = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      alex-fw = {
        role = "admin";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
    };
  };
  dima = {
    description = "Dima";
    defaultUid = 8070;
    defaultGroups = [
      "audio"
      "networkmanager"
      "video"
      "input"
      "plugdev"
    ];
    sshAuthorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP++JHcHDQfP5wcPxtb8o4liBWo+DFS13I4a9UgSTFec dima@nixos"
    ];
    machines = {
      zenith = {
        role = "owner";
        shell = "fish";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "hyprland"
            "hypr-laptop"
            "creative"
            "social"
          ];
        };
      };
      gmk1 = {
        role = "basic";
        shell = "zsh";
        homeManager = {
          enable = true;
          profiles = [
            # "base"
            # "dev"
          ];
        };
      };
      gmk2 = {
        role = "basic";
        shell = "zsh";
        homeManager = {
          enable = true;
          profiles = [
            # "base"
            # "dev"
          ];
        };
      };
      gmk3 = {
        role = "basic";
        shell = "zsh";
        homeManager = {
          enable = true;
          profiles = [
            # "base"
            # "dev"
          ];
        };
      };
    };
  };

}
