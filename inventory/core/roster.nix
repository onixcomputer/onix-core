_:
let
  roster-users = {
    alex = {
      description = "Alex";
      defaultUid = 3801;
      defaultGroups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeeoL1jwVSachA9GdJxm/5TgCRBULfSDGLyP/nfmkMq alex@DESKTOP-SVRV9Q8"
      ];
      defaultPosition = "owner";
      defaultShell = "fish";
    };

    brittonr = {
      description = "Britton";
      defaultUid = 1555;
      defaultGroups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
        "docker"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
      ];
      defaultPosition = "owner";
      defaultShell = "fish";
    };

    dima = {
      description = "Dima";
      defaultUid = 8070;
      defaultGroups = [
        "networkmanager"
        "video"
        "audio"
        "input"
        "kvm"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP++JHcHDQfP5wcPxtb8o4liBWo+DFS13I4a9UgSTFec dima@nixos"
      ];
      defaultPosition = "owner";
      defaultShell = "fish";
    };
  };

  roster-machines = {
    alex-fw = {
      users = {
        alex = {
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
      homeManagerOptions = {
        sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "eDP-1,2880x1920@120,auto,2"
              "DP-3,preferred,auto,1,mirror,eDP-1"
            ];
          }
        ];
      };
    };

    britton-fw = {
      users = {
        brittonr = {
          position = "owner";
          shell = "fish";
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              "hyprland"
              "hypr-laptop"
              "social"
            ];
          };
        };
      };
      homeManagerOptions = {
        sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "eDP-1,2880x1920@120,auto,2"
              "DP-3,preferred,auto,1,mirror,eDP-1"
            ];
          }
        ];
      };
    };

    britton-desktop = {
      users = {
        brittonr = {
          position = "owner";
          shell = "fish";
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              "hyprland"
              "creative"
              "social"
            ];
          };
        };
      };
      homeManagerOptions = {
        sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              ",preferred,auto,1.5"
              "HDMI-A-1,preferred,auto,2,mirror,eDP-1"
              "HDMI-A-2,preferred,auto,2,mirror,DP-1"
            ];
          }
        ];
      };
    };

    britton-dev = {
      users = {
        brittonr = {
          position = "owner";
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

    aspen1 = {
      users = {
        brittonr = {
          position = "owner";
          shell = "fish";
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        alex = {
          position = "owner";
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

    sequoia = {
      users = {
        alex = {
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

    bambrew = {
      users = {
        alex = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        brittonr = {
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

    marine = {
      users = {
        alex = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        brittonr = {
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

    alex-wsl = {
      users = {
        alex = {
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

    zenith = {
      users = {
        dima = {
          position = "owner";
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
        alex = {
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
      homeManagerOptions = {
        sharedModules = [
          {
            wayland.windowManager.hyprland.settings.monitor = [
              "eDP-1, preferred, auto, 1.5"
            ];
          }
        ];
      };
    };

    # GMK machines
    gmk1 = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        dima = {
          position = "basic";
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

    gmk2 = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        dima = {
          position = "basic";
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

    gmk3 = {
      users = {
        brittonr = {
          position = "owner";
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
            ];
          };
        };
        dima = {
          position = "basic";
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
  };
in
{
  instances = {
    roster = {
      module.name = "roster";
      roles.default.tags.all = { };
      roles.default.settings = {
        users = roster-users;
        machines = roster-machines;
        homeProfilesPath = ../home-profiles;
        homeManagerOptions = {
          backupFileExtension = "bak";
        };
      };
    };
  };
}
