{ lib }:
let
  # Local reverse proxies (for example Folio's position proxy in front of
  # Calibre) relay remote clients from these addresses, so trusting them would
  # open Calibre's write API to everyone who can reach such a proxy.
  sharedAddresses = [
    "127.0.0.1"
    "::1"
    "::ffff:127.0.0.1"
    "0.0.0.0"
    "::"
  ];
  singleAddress =
    address:
    address != ""
    && !lib.hasInfix "/" address
    && !lib.hasInfix "," address
    && !lib.hasInfix " " address;
  validTrustedIp = address: singleAddress address && !(builtins.elem address sharedAddresses);

  validate =
    settings:
    lib.optional (!lib.all validTrustedIp settings.trustedIps)
      "calibre-server trustedIps must list single addresses other than 127.0.0.1, ::1 and wildcards, because local proxies relay remote clients from the shared loopback addresses";
in
{
  inherit validate;
}
