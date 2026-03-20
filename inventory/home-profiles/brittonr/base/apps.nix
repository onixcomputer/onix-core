{ lib, pkgs, ... }:
{
  options.apps = {
    terminal = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        name = "wezterm";
        command = "${pkgs.wezterm}/bin/wezterm";
        appId = "org.wezfurlong.wezterm";
      };
      description = "Default terminal emulator";
    };

    browser = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        name = "librewolf";
        command = "librewolf";
        appId = "librewolf";
      };
      description = "Default web browser";
    };

    fileManager = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        name = "yazi";
        command = "yazi";
      };
      description = "Default file manager";
    };

    sysmon = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        name = "btop";
        command = "btop";
      };
      description = "Default system monitor";
    };
  };
}
