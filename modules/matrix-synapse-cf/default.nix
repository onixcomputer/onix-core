# Override the upstream matrix-synapse module's nginx config for use
# behind a Cloudflare tunnel.  Cloudflare terminates TLS at the edge,
# so we disable ACME cert issuance and forceSSL on the nginx vhosts.
#
# If you change server_tld/app_domain in the inventory, update these
# vhost names to match.
{ lib, ... }:
{
  services.nginx.virtualHosts = {
    "onix.computer" = {
      forceSSL = lib.mkForce false;
      enableACME = lib.mkForce false;
    };
    "matrix.onix.computer" = {
      forceSSL = lib.mkForce false;
      enableACME = lib.mkForce false;
    };
  };
}
