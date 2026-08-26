{ lib }:
let
  settingsLib = import ./settings.nix { inherit lib; };
  testPort = 39300;
  testRestartDelaySeconds = 5;
  validSettings = {
    sourceDir = "/datapool/bookshelf/source";
    libraryDir = "/datapool/bookshelf/library";
    bindAddress = "100.110.43.11";
    port = testPort;
    siteUrl = "http://100.110.43.11:${toString testPort}";
    readOnly = false;
    openFirewall = true;
    firewallInterface = "tailscale0";
    restartDelaySeconds = testRestartDelaySeconds;
  };
  negativeCases = {
    relativeSource = validSettings // {
      sourceDir = "books";
    };
    emptyLibrary = validSettings // {
      libraryDir = "";
    };
    identicalPaths = validSettings // {
      libraryDir = validSettings.sourceDir;
    };
    nestedPaths = validSettings // {
      libraryDir = "${validSettings.sourceDir}/published";
    };
    wildcardBind = validSettings // {
      bindAddress = "0.0.0.0";
    };
    invalidSiteUrl = validSettings // {
      siteUrl = "bookshelf private";
    };
    globalFirewall = validSettings // {
      firewallInterface = null;
    };
    immediateRestart = validSettings // {
      restartDelaySeconds = 0;
    };
  };
  negativeErrors = lib.mapAttrs (_: settingsLib.validate) negativeCases;
in
{
  positiveErrors = settingsLib.validate validSettings;
  inherit negativeErrors;
  missingNegativeCases = lib.attrNames (lib.filterAttrs (_: errors: errors == [ ]) negativeErrors);
}
