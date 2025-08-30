_: {
  boot = {
    kernelParams = [
      "consoleblank=60"
      "button.lid_init_state=open"
      "button.lid_event=ignore"
    ];
    initrd.systemd.tpm2.enable = false;
  };

  time.timeZone = "America/New_York";

  networking = {
    hostName = "marine";
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    logind = {
      settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
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
}
