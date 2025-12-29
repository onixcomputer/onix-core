{ inputs, pkgs, ... }:
{
  home.packages = [
    (inputs.wrappers.wrapperModules.jujutsu.apply {
      inherit pkgs;

      settings = {
        user = {
          name = "brittonr";
          email = "b@robitzs.ch";
        };

        ui = {
          default-command = "log";
          pager = "less -FRX";
        };

        aliases = {
          l = [ "log" ];
          s = [ "status" ];
          d = [ "diff" ];
        };
      };
    }).wrapper
  ];
}
