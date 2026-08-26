{ lib }:
let
  inherit (lib)
    hasPrefix
    hasInfix
    ;

  absolutePath = path: path != "" && hasPrefix "/" path;
  nestedPath = parent: child: hasPrefix "${parent}/" child;
  validSiteUrl = url: (hasPrefix "http://" url || hasPrefix "https://" url) && !hasInfix " " url;

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
    ];
in
{
  inherit validate;
}
