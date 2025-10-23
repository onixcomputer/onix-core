# Keycloak Terranix Provider Configuration
{ config, lib, ... }:

let
  inherit (lib) mkIf filterAttrs;
  cfg = config.services.keycloak;
in
{
  config = mkIf cfg.enable {
    # Configure Keycloak provider
    provider.keycloak = filterAttrs (_: v: v != null) {
      client_id = cfg.provider.clientId;
      inherit (cfg.provider)
        username
        password
        url
        realm
        ;
      initial_login = cfg.provider.initialLogin;
      client_timeout = cfg.provider.clientTimeout;
      tls_insecure_skip_verify = cfg.provider.tlsInsecureSkipVerify;

      # Add additional headers if specified
      additional_headers = mkIf (cfg.provider.additionalHeaders != { }) cfg.provider.additionalHeaders;
    };
  };
}
