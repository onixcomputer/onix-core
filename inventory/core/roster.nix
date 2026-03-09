_:
let
  roster-users = {

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
        "dialout"
        "disk"
      ];
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
      ];
      defaultPosition = "owner";
      defaultShell = "fish";
    };

  };

  roster-machines = {

    # ========== Britton Machines ===========
    britton-fw = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              # "hyprland"
              # "hypr-laptop"
              # "niri"
              "noctalia"
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
    britton-gpd = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              # "hyprland"
              # "hypr-laptop"
              # "niri"
              "noctalia"
              "social"
            ];
          };
        };
      };
      homeManagerOptions = {
        sharedModules = [
          {
            # wayland.windowManager.hyprland.settings.monitor = [
            #   "eDP-1,2880x1920@120,auto,1"
            # ];
          }
        ];
      };
    };

    bonsai = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              # "niri"
              "noctalia"
              "social"
            ];
          };
        };
      };
      homeManagerOptions = {
        sharedModules = [
          {
            # GPD Pocket 4: 1600x2560 panel rotated 270° → 2560x1600 landscape
            # Scale 2 → 1280x800 logical (up from 1024x640 at scale 2.5)
            monitors = {
              primary = {
                name = "eDP-1";
                mode = "1600x2560@143.999";
                scale = 2;
                position = {
                  x = 0;
                  y = 0;
                };
                vrr = false;
              };
              secondary = {
                name = "DP-3";
                mode = "preferred";
                scale = 1;
                position = {
                  x = 1280;
                  y = 0;
                };
                vrr = false;
              };
              builtin = {
                name = "eDP-1";
              };
            };
          }
        ];
      };
    };

    aspen1 = {
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
      };
    };

    aspen2 = {
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
      };
    };

    britton-desktop = {
      users = {
        brittonr = {
          homeManager = {
            enable = true;
            profiles = [
              "base"
              "dev"
              # "hyprland"
              # "niri"
              "noctalia"
              "creative"
              "social"
            ];
          };
        };
      };
      homeManagerOptions = {
        sharedModules = [
          {
            wayland.windowManager.hyprland.settings = {
              monitor = [
                ",preferred,auto,1.5"
              ];
              xwayland = {
                force_zero_scaling = true;
              };
            };
          }
        ];
      };
    };

    pine = {
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
