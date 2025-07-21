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
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    machines = {
      alex-mu = {
        role = "owner";
        shell = "zsh";
      };
      alex-dev = {
        role = "owner";
        shell = "zsh";
      };
      alex-fw = {
        role = "owner";
        shell = "zsh";
      };
      alex-wsl = {
        role = "owner";
        shell = "zsh";
      };
    };
  };

  brittonr = {
    description = "Britton";
    defaultUid = 1000;
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
    sessionVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };
    machines = {
      britton-fw = {
        role = "owner";
        groups = [
          "wheel"
          "networkmanager"
          "video"
          "input"
          "testgroup"
        ];
        shell = "fish";
      };
      britton-desktop = {
        role = "owner";
        shell = "fish";
      };
      britton-dev = {
        role = "owner";
        shell = "fish";
      };
    };
  };
}
