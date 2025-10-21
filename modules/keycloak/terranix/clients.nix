# Keycloak Clients Module
{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    mkIf
    types
    mapAttrs'
    nameValuePair
    filterAttrs
    ;

  cfg = config.services.keycloak;

  # Helper function to generate realm reference
  realmRef = realmName: "\${keycloak_realm.${cfg.settings.resourcePrefix}${realmName}.id}";

  # Comprehensive client configuration type
  clientType = types.submodule (
    { name, ... }:
    {
      options = {
        clientId = mkOption {
          type = types.str;
          default = name;
          description = "Client ID for authentication (defaults to attribute name)";
        };

        realmId = mkOption {
          type = types.str;
          description = ''
            Realm where this client belongs.
            Should reference a realm defined in the realms configuration.
          '';
        };

        name = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Human-readable client name";
        };

        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Client description";
        };

        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the client is enabled";
        };

        # Client type and access settings
        accessType = mkOption {
          type = types.enum [
            "PUBLIC"
            "CONFIDENTIAL"
            "BEARER-ONLY"
          ];
          default = "CONFIDENTIAL";
          description = ''
            Client access type:
            - PUBLIC: For client-side applications (SPAs, mobile apps)
            - CONFIDENTIAL: For server-side applications that can store secrets
            - BEARER-ONLY: For services that only accept bearer tokens
          '';
        };

        clientSecret = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Client secret for confidential clients.
            If not specified, Keycloak will generate one.
            Should reference a variable for security.
          '';
          example = "\${var.client_secret}";
        };

        # OAuth 2.0 / OpenID Connect flow settings
        standardFlowEnabled = mkOption {
          type = types.bool;
          default = true;
          description = "Whether standard flow (authorization code) is enabled";
        };

        implicitFlowEnabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether implicit flow is enabled.
            Note: Implicit flow is deprecated and not recommended for security reasons.
          '';
        };

        directAccessGrantsEnabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether direct access grants (password flow) are enabled.
            Note: Not recommended for most applications.
          '';
        };

        serviceAccountsEnabled = mkOption {
          type = types.bool;
          default = false;
          description = "Whether service accounts (client credentials flow) are enabled";
        };

        # PKCE settings
        pkceCodeChallengeMethod = mkOption {
          type = types.nullOr (
            types.enum [
              "S256"
              "plain"
            ]
          );
          default = null;
          description = ''
            PKCE code challenge method.
            S256 is recommended for security.
          '';
        };

        # URL configurations
        validRedirectUris = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of valid redirect URIs";
          example = [
            "https://app.example.com/*"
            "http://localhost:3000/*"
            "com.example.app://oauth/callback"
          ];
        };

        validPostLogoutRedirectUris = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of valid post-logout redirect URIs";
          example = [
            "https://app.example.com/logout"
            "http://localhost:3000/logout"
          ];
        };

        webOrigins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of allowed web origins for CORS";
          example = [
            "https://app.example.com"
            "http://localhost:3000"
          ];
        };

        adminUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Admin URL for the client";
        };

        baseUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Base URL for the client";
        };

        rootUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Root URL for the client";
        };

        # Token and session settings
        accessTokenLifespan = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access token lifespan for this client";
        };

        clientSessionIdleTimeout = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Client session idle timeout";
        };

        clientSessionMaxLifespan = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Client session maximum lifespan";
        };

        # Consent settings
        consentRequired = mkOption {
          type = types.bool;
          default = false;
          description = "Whether user consent is required";
        };

        displayOnConsentScreen = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to display this client on the consent screen";
        };

        consentScreenText = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Text to display on the consent screen";
        };

        # Authentication settings
        clientAuthenticatorType = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Client authenticator type";
        };

        useRefreshTokens = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to use refresh tokens";
        };

        useRefreshTokensClientCredentials = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to use refresh tokens for client credentials flow";
        };

        # Backchannel logout
        backchannelLogoutUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Backchannel logout URL";
        };

        backchannelLogoutSessionRequired = mkOption {
          type = types.bool;
          default = true;
          description = "Whether backchannel logout session is required";
        };

        backchannelLogoutRevokeOfflineTokens = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to revoke offline tokens on backchannel logout";
        };

        # Front-channel logout
        frontchannelLogoutUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Front-channel logout URL";
        };

        # OpenID Connect settings
        excludeSessionStateFromAuthResponse = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to exclude session state from auth response";
        };

        # Client scopes
        defaultClientScopes = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of default client scope names";
          example = [
            "openid"
            "profile"
            "email"
          ];
        };

        optionalClientScopes = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of optional client scope names";
        };

        # Custom attributes
        attributes = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Custom attributes for the client";
        };

        # Authorization settings (for confidential clients)
        authorizationServicesEnabled = mkOption {
          type = types.bool;
          default = false;
          description = "Whether authorization services are enabled";
        };

        # Validation
        alwaysDisplayInConsole = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to always display this client in the admin console";
        };

        fullScopeAllowed = mkOption {
          type = types.bool;
          default = true;
          description = "Whether full scope is allowed";
        };

        # OpenID Connect / OAuth 2.0 advanced settings
        loginTheme = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Login theme for this client";
        };

        surrogateAuthRequired = mkOption {
          type = types.bool;
          default = false;
          description = "Whether surrogate authentication is required";
        };

        # Client template
        protocolMappers = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "Mapper name";
                };

                protocol = mkOption {
                  type = types.str;
                  default = "openid-connect";
                  description = "Mapper protocol";
                };

                protocolMapper = mkOption {
                  type = types.str;
                  description = "Mapper type";
                };

                config = mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                  description = "Mapper configuration";
                };
              };
            }
          );
          default = [ ];
          description = "Protocol mappers for the client";
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    clients = mkOption {
      type = types.attrsOf clientType;
      default = { };
      description = "Keycloak clients to manage";
      example = {
        "web-app" = {
          clientId = "web-application";
          realmId = "company";
          name = "Web Application";
          accessType = "CONFIDENTIAL";
          standardFlowEnabled = true;
          validRedirectUris = [
            "https://app.company.com/*"
            "http://localhost:3000/*"
          ];
          webOrigins = [
            "https://app.company.com"
            "http://localhost:3000"
          ];
          defaultClientScopes = [
            "openid"
            "profile"
            "email"
          ];
          pkceCodeChallengeMethod = "S256";
        };
        "mobile-app" = {
          clientId = "mobile-application";
          realmId = "company";
          accessType = "PUBLIC";
          pkceCodeChallengeMethod = "S256";
          validRedirectUris = [ "com.company.app://oauth/callback" ];
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      keycloak_openid_client = mapAttrs' (
        clientName: clientCfg:
        nameValuePair "${cfg.settings.resourcePrefix}${clientName}" (
          filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            realm_id = realmRef clientCfg.realmId;
            client_id = clientCfg.clientId;
            inherit (clientCfg) name description enabled;

            # Access type and flows
            access_type = clientCfg.accessType;
            client_secret = clientCfg.clientSecret;
            standard_flow_enabled = clientCfg.standardFlowEnabled;
            implicit_flow_enabled = clientCfg.implicitFlowEnabled;
            direct_access_grants_enabled = clientCfg.directAccessGrantsEnabled;
            service_accounts_enabled = clientCfg.serviceAccountsEnabled;

            # PKCE
            pkce_code_challenge_method = clientCfg.pkceCodeChallengeMethod;

            # URLs
            valid_redirect_uris = lib.mkIf (clientCfg.validRedirectUris != [ ]) clientCfg.validRedirectUris;
            valid_post_logout_redirect_uris = lib.mkIf (
              clientCfg.validPostLogoutRedirectUris != [ ]
            ) clientCfg.validPostLogoutRedirectUris;
            web_origins = lib.mkIf (clientCfg.webOrigins != [ ]) clientCfg.webOrigins;
            admin_url = clientCfg.adminUrl;
            base_url = clientCfg.baseUrl;
            root_url = clientCfg.rootUrl;

            # Token settings
            access_token_lifespan = clientCfg.accessTokenLifespan;
            client_session_idle_timeout = clientCfg.clientSessionIdleTimeout;
            client_session_max_lifespan = clientCfg.clientSessionMaxLifespan;

            # Consent
            consent_required = clientCfg.consentRequired;
            display_on_consent_screen = clientCfg.displayOnConsentScreen;
            consent_screen_text = clientCfg.consentScreenText;

            # Authentication
            client_authenticator_type = clientCfg.clientAuthenticatorType;
            use_refresh_tokens = clientCfg.useRefreshTokens;
            use_refresh_tokens_client_credentials = clientCfg.useRefreshTokensClientCredentials;

            # Logout
            backchannel_logout_url = clientCfg.backchannelLogoutUrl;
            backchannel_logout_session_required = clientCfg.backchannelLogoutSessionRequired;
            backchannel_logout_revoke_offline_tokens = clientCfg.backchannelLogoutRevokeOfflineTokens;
            frontchannel_logout_url = clientCfg.frontchannelLogoutUrl;

            # OpenID Connect
            exclude_session_state_from_auth_response = clientCfg.excludeSessionStateFromAuthResponse;

            # Client scopes
            default_client_scopes = lib.mkIf (
              clientCfg.defaultClientScopes != [ ]
            ) clientCfg.defaultClientScopes;
            optional_client_scopes = lib.mkIf (
              clientCfg.optionalClientScopes != [ ]
            ) clientCfg.optionalClientScopes;

            # Authorization services
            authorization_services_enabled = clientCfg.authorizationServicesEnabled;

            # Other settings
            always_display_in_console = clientCfg.alwaysDisplayInConsole;
            full_scope_allowed = clientCfg.fullScopeAllowed;
            login_theme = clientCfg.loginTheme;
            surrogate_auth_required = clientCfg.surrogateAuthRequired;

            # Custom attributes
            inherit (clientCfg) attributes;
          }
        )
      ) cfg.clients;

      # Generate protocol mappers as separate resources
      keycloak_openid_client_protocol_mapper = lib.mkMerge (
        lib.flatten (
          lib.mapAttrsToList (
            clientName: clientCfg:
            lib.imap0 (idx: mapper: {
              "${cfg.settings.resourcePrefix}${clientName}_mapper_${toString idx}" = {
                realm_id = realmRef clientCfg.realmId;
                client_id = "\${keycloak_openid_client.${cfg.settings.resourcePrefix}${clientName}.id}";
                inherit (mapper) name protocol;
                protocol_mapper = mapper.protocolMapper;
                inherit (mapper) config;
              };
            }) clientCfg.protocolMappers
          ) cfg.clients
        )
      );
    };
  };
}
