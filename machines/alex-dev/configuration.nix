_: {
  boot = {
    kernelParams = [
      "consoleblank=60"
      "button.lid_init_state=open"
      "button.lid_event=ignore"
    ];
    initrd.systemd.tpm2.enable = false;
  };

  networking = {
    hostName = "alex-dev";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    logind = {
      lidSwitch = "ignore";
      lidSwitchDocked = "ignore";
      extraConfig = ''
        HandleLidSwitch=ignore
        HandleLidSwitchDocked=ignore
        HandleLidSwitchExternalPower=ignore
      '';
    };
  };

  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
    tpm2.enable = false;
  };

  system.stateVersion = "25.05";
}
