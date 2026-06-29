# Focused Home Manager migration checks.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  targetHomeStateVersion = "26.05";
  legacyHomeStateVersion = "25.11";

  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  desktopHome = desktopConfig.home-manager.users.brittonr;
  actualHomeStateVersion = desktopHome.home.stateVersion;
  actualSystemStateVersion = desktopConfig.system.stateVersion;
  neovimConfig = desktopHome.programs.neovim;

  boolString = value: if value then "true" else "false";

  assertions = [
    {
      name = "positive: britton-desktop Home Manager stateVersion is ${targetHomeStateVersion}";
      condition = actualHomeStateVersion == targetHomeStateVersion;
    }
    {
      name = "positive: NixOS system.stateVersion remains ${legacyHomeStateVersion}";
      condition = actualSystemStateVersion == legacyHomeStateVersion;
    }
    {
      name = "positive: Neovim Ruby provider is disabled";
      condition = neovimConfig.withRuby == false;
    }
    {
      name = "positive: Neovim Python provider is disabled";
      condition = neovimConfig.withPython3 == false;
    }
    {
      name = "negative: Home Manager stateVersion no longer matches legacy ${legacyHomeStateVersion}";
      condition = actualHomeStateVersion != legacyHomeStateVersion;
    }
    {
      name = "negative: Neovim Ruby provider no longer preserves the legacy enabled default";
      condition = neovimConfig.withRuby != true;
    }
    {
      name = "negative: Neovim Python provider no longer preserves the legacy enabled default";
      condition = neovimConfig.withPython3 != true;
    }
  ];

  failedAssertions = lib.filter (assertion: !assertion.condition) assertions;
  failedNames = lib.concatMapStringsSep "; " (assertion: assertion.name) failedAssertions;
  report = builtins.toFile "home-manager-2605-migration-report.txt" ''
    Home Manager 26.05 migration check

    Effective values:
    - home-manager.users.brittonr.home.stateVersion = ${actualHomeStateVersion}
    - system.stateVersion = ${actualSystemStateVersion}
    - programs.neovim.withRuby = ${boolString neovimConfig.withRuby}
    - programs.neovim.withPython3 = ${boolString neovimConfig.withPython3}

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) assertions}
  '';
in
{
  checks = lib.optionalAttrs (system == "x86_64-linux") {
    home-manager-2605-migration =
      if failedAssertions == [ ] then
        pkgs.runCommand "home-manager-2605-migration" { migrationReport = report; } ''
          cp "$migrationReport" "$out"
        ''
      else
        throw "home-manager-2605-migration failed: ${failedNames}";
  };
}
