{ lib }:
let
  settingsLib = import ./settings.nix { inherit lib; };
  testPort = 39300;
  testIntakePort = 39301;
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
    intakeEnable = true;
    intakePort = testIntakePort;
    intakeMaxMegabytes = 256;
    intakeCalibreUrl = "http://127.0.0.1:6767";
    intakeCalibreLibraryId = "Calibre_Library";
    intakeCalibreSourceAddress = "127.0.0.2";
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
    intakeSharesPort = validSettings // {
      intakePort = testPort;
    };
    intakeRandomPort = validSettings // {
      intakePort = 0;
    };
    intakeOversizedUploads = validSettings // {
      intakeMaxMegabytes = 4096;
    };
    intakeRemoteCalibre = validSettings // {
      intakeCalibreUrl = "http://100.110.43.11:6767";
    };
    intakeSharedLoopbackSource = validSettings // {
      intakeCalibreSourceAddress = "127.0.0.1";
    };
    intakeMissingSource = validSettings // {
      intakeCalibreSourceAddress = null;
    };
    intakeSourceWithoutCalibre = validSettings // {
      intakeCalibreUrl = null;
      intakeCalibreLibraryId = null;
    };
  };
  negativeErrors = lib.mapAttrs (_: settingsLib.validate) negativeCases;
in
{
  positiveErrors = settingsLib.validate validSettings;
  # The intake is opt-in: a shelf without it needs none of its settings.
  intakeDisabledErrors = settingsLib.validate (
    validSettings
    // {
      intakeEnable = false;
      intakePort = testPort;
      intakeCalibreUrl = null;
      intakeCalibreLibraryId = null;
      intakeCalibreSourceAddress = null;
    }
  );
  inherit negativeErrors;
  missingNegativeCases = lib.attrNames (lib.filterAttrs (_: errors: errors == [ ]) negativeErrors);
}
