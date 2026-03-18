_: {
  instances = {

    # Password generation via upstream clan-core users module.
    # Groups are set here; UID, shell, and SSH keys are in tags/all.nix.
    user-brittonr = {
      module.name = "users";
      module.input = "clan-core";
      roles.default.tags.nixos = { };
      roles.default.settings = {
        user = "brittonr";
        prompt = true;
        groups = [
          "wheel"
          "networkmanager"
          "video"
          "audio"
          "input"
          "kvm"
          "docker"
          "dialout"
          "disk"
        ];
      };
    };

    # Home-manager profiles per machine group.
    # Server/headless machines: base + dev
    hm-server = {
      module.name = "home-manager-profiles";
      module.input = "self";
      roles.default = {
        tags.hm-server = { };
        settings = {
          username = "brittonr";
          profiles = [
            "base"
            "dev"
          ];
          profilesBasePath = ../home-profiles;
        };
      };
    };

    # Laptop machines: base + dev + noctalia + social
    hm-laptop = {
      module.name = "home-manager-profiles";
      module.input = "self";
      roles.default = {
        tags.hm-laptop = { };
        settings = {
          username = "brittonr";
          profiles = [
            "base"
            "dev"
            "noctalia"
            "social"
          ];
          profilesBasePath = ../home-profiles;
        };
      };
    };

    # Desktop: base + dev + noctalia + creative + social + media
    hm-desktop = {
      module.name = "home-manager-profiles";
      module.input = "self";
      roles.default = {
        machines.britton-desktop = { };
        settings = {
          username = "brittonr";
          profiles = [
            "base"
            "dev"
            "noctalia"
            "creative"
            "social"
            "media"
          ];
          profilesBasePath = ../home-profiles;
        };
      };
    };

  };
}
