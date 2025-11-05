{
  inputs,
  pkgs,
  ...
}:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-3840x2160.png";
    sha256 = "sha256-d+sXYC74KL90wh06bLYTgebF6Ai7ac6Qsd+6qj57yyE=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
  ];

  networking = {
    hostName = "britton-desktop";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    os-prober
  ];

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      extraConfig = ''
        GRUB_DISABLE_OS_PROBER=false
      '';
      extraEntries = ''
        menuentry "Reboot" {
          reboot
        }
      '';
      # extraEntries = ''
      #   menuentry "Windows (Manual)" {
      #     insmod part_gpt
      #     insmod ntfs
      #     insmod search_fs_uuid
      #     insmod chain
      #     search --fs-uuid --set=root 12EA42E8EA42C825
      #     chainloader +1
      #   }
      # '';
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "3840x2160";
      splashImage = grubWallpaper;
    };
  };

  services = {

    gnome.gnome-keyring.enable = true;

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };

    printing.enable = true;

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

  };

  security = {
    rtkit.enable = true;
    pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
      sudo.fprintAuth = false;
      hyprlock = { };
    };
  };

  # Configure m2 as aarch64 remote builder
  nix = {
    distributedBuilds = true;
    settings = {
      builders = "@/etc/nix/machines";
      builders-use-substitutes = true;
      trusted-users = [ "brittonr" ];
      # Lower max-jobs to encourage offloading
      max-jobs = 0;
    };
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "m2.bison-tailor.ts.net";
        systems = [ "aarch64-linux" ];
        maxJobs = 6;
        speedFactor = 2;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
        ];
        mandatoryFeatures = [ ];
        sshUser = "root";
        sshKey = "/root/.ssh/id_m2";
      }
    ];
  };

  # Copy SSH key for m2 builder access (runs during activation)
  system.activationScripts.m2-builder-key = {
    text = ''
      mkdir -p /root/.ssh
      chmod 700 /root/.ssh
      if [ -f /home/brittonr/.ssh/framework ]; then
        if cp -f /home/brittonr/.ssh/framework /root/.ssh/id_m2 && chmod 600 /root/.ssh/id_m2; then
          echo "m2 builder SSH key installed successfully"
        else
          echo "ERROR: Failed to install m2 builder SSH key"
          exit 1
        fi
      else
        echo "ERROR: /home/brittonr/.ssh/framework not found"
        exit 1
      fi
    '';
    deps = [ "users" ];
  };

  programs.ssh = {
    knownHosts = {
      m2 = {
        hostNames = [
          "m2"
          "m2.bison-tailor.ts.net"
        ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ05g4bAY8EsmySlCMxAEyTRjs/g/SpggreGoe9XTsXz";
      };
    };
  };
}
