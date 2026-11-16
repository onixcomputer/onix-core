{ lib }:
let
  inherit (lib)
    hasPrefix
    hasInfix
    ;

  absolutePath = path: path != "" && hasPrefix "/" path;
  nestedPath = parent: child: hasPrefix "${parent}/" child;
  validSiteUrl = url: (hasPrefix "http://" url || hasPrefix "https://" url) && !hasInfix " " url;
  # Calibre's default request-body limit is 500 MB; larger uploads would fail there.
  maxIntakeMegabytes = 500;
  loopbackUrl = url: hasPrefix "http://127." url || hasPrefix "http://localhost:" url;
  # Local proxies relay remote clients from 127.0.0.1, so Calibre must trust a
  # different loopback address that only the upload endpoint binds.
  dedicatedLoopback = address: address != null && hasPrefix "127." address && address != "127.0.0.1";

  validate =
    settings:
    lib.flatten [
      (lib.optional (
        !absolutePath settings.sourceDir
      ) "bookshelf sourceDir must be a non-empty absolute path")
      (lib.optional (
        !absolutePath settings.libraryDir
      ) "bookshelf libraryDir must be a non-empty absolute path")
      (lib.optional (
        settings.sourceDir == settings.libraryDir
        || nestedPath settings.sourceDir settings.libraryDir
        || nestedPath settings.libraryDir settings.sourceDir
      ) "bookshelf sourceDir and libraryDir must be separate, non-overlapping paths")
      (lib.optional (
        settings.bindAddress == "" || settings.bindAddress == "0.0.0.0" || settings.bindAddress == "::"
      ) "bookshelf bindAddress must name one explicit private or loopback address")
      (lib.optional (
        !validSiteUrl settings.siteUrl
      ) "bookshelf siteUrl must be an absolute HTTP or HTTPS URL without spaces")
      (lib.optional (settings.openFirewall && settings.firewallInterface == null)
        "bookshelf openFirewall requires a private firewallInterface because Bookshelf has no authentication"
      )
      (lib.optional (
        settings.restartDelaySeconds < 1
      ) "bookshelf restartDelaySeconds must be at least one second")
      (lib.optionals settings.intakeEnable [
        (lib.optional (
          settings.intakePort == 0 || settings.intakePort == settings.port
        ) "bookshelf intakePort must be a fixed port different from port")
        (lib.optional (
          settings.intakeMaxMegabytes < 1 || settings.intakeMaxMegabytes > maxIntakeMegabytes
        ) "bookshelf intakeMaxMegabytes must be between 1 and ${toString maxIntakeMegabytes}")
      ])
      (lib.optional (
        settings.intakeCalibreUrl != null && !loopbackUrl settings.intakeCalibreUrl
      ) "bookshelf intakeCalibreUrl must be a loopback http:// URL")
      (lib.optional
        (settings.intakeCalibreUrl != null && !dedicatedLoopback settings.intakeCalibreSourceAddress)
        "bookshelf intakeCalibreSourceAddress must be a loopback address other than 127.0.0.1, which local proxies share"
      )
      (lib.optional (
        settings.intakeCalibreUrl == null
        && (settings.intakeCalibreSourceAddress != null || settings.intakeCalibreLibraryId != null)
      ) "bookshelf intakeCalibreSourceAddress and intakeCalibreLibraryId require intakeCalibreUrl")
    ];
in
{
  inherit validate;
}
