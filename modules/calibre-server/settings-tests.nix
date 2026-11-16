{ lib }:
let
  settingsLib = import ./settings.nix { inherit lib; };
  negativeCases = {
    sharedLoopback.trustedIps = [ "127.0.0.1" ];
    ipv6Loopback.trustedIps = [ "::1" ];
    mappedLoopback.trustedIps = [ "::ffff:127.0.0.1" ];
    network.trustedIps = [ "127.0.0.0/8" ];
    wildcard.trustedIps = [ "0.0.0.0" ];
    commaJoined.trustedIps = [ "127.0.0.2,127.0.0.1" ];
  };
  negativeErrors = lib.mapAttrs (_: settingsLib.validate) negativeCases;
in
{
  positiveErrors =
    settingsLib.validate { trustedIps = [ "127.0.0.2" ]; }
    ++ settingsLib.validate { trustedIps = [ ]; };
  inherit negativeErrors;
  missingNegativeCases = lib.attrNames (lib.filterAttrs (_: errors: errors == [ ]) negativeErrors);
}
