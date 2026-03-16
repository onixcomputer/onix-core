# Override the upstream matrix-synapse module's nginx config for use
# behind a Cloudflare tunnel.  Cloudflare terminates TLS at the edge,
# so we disable ACME cert issuance, forceSSL, and DH params on the
# nginx vhosts.
#
# The upstream clan-core matrix-synapse/nginx.nix sets sslDhparam to
# config.security.dhparams.params.nginx.path directly, which causes
# infinite recursion with nixpkgs' nginx module (the nixpkgs module
# conditionally defines dhparams.params.nginx via mkIf on sslDhparam,
# creating a cycle).  We disable the upstream nginx.nix entirely and
# provide a replacement without the problematic sslDhparam reference.
#
# If you change server_tld/app_domain in the inventory, update these
# vhost names to match.
{
  config,
  lib,
  inputs,
  ...
}:
{
  # Remove the upstream clan-core nginx.nix that causes infinite recursion.
  disabledModules = [
    "${inputs.clan-core}/clanServices/matrix-synapse/nginx.nix"
  ];

  # Replacement nginx config (upstream minus sslDhparam + CF overrides).
  networking.firewall.allowedTCPPorts = [
    443
    80
  ];

  services.nginx = {
    enable = true;

    statusPage = lib.mkDefault true;
    recommendedBrotliSettings = lib.mkDefault true;
    recommendedGzipSettings = lib.mkDefault true;
    recommendedOptimisation = lib.mkDefault true;
    recommendedProxySettings = lib.mkDefault true;
    recommendedTlsSettings = lib.mkDefault true;

    commonHttpConfig = "access_log syslog:server=unix:/dev/log;";

    resolver.addresses =
      let
        isIPv6 = addr: builtins.match ".*:.*:.*" addr != null;
        escapeIPv6 = addr: if isIPv6 addr then "[${addr}]" else addr;
        cloudflare = [
          "1.1.1.1"
          "2606:4700:4700::1111"
        ];
        resolvers =
          if config.networking.nameservers == [ ] then cloudflare else config.networking.nameservers;
      in
      map escapeIPv6 resolvers;

    virtualHosts = {
      "onix.computer" = {
        forceSSL = lib.mkForce false;
        enableACME = lib.mkForce false;
      };
      "matrix.onix.computer" = {
        forceSSL = lib.mkForce false;
        enableACME = lib.mkForce false;
      };
    };
  };
}
