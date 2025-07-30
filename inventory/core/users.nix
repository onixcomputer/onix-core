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
      alex-mu = {
        role = "owner";
        shell = "zsh";
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
        shell = "zsh";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
          ];
        };
      };
      alex-fw = {
        role = "owner";
        shell = "zsh";
        homeManager = {
          enable = true;
          profiles = [
            "base"
            "dev"
            "laptop"
            "creative"
          ];
        };
      };
      alex-wsl = {
        role = "owner";
        shell = "zsh";
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
            "laptop"
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
            "desktop"
            "creative"
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
      alex-mu = {
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
}
