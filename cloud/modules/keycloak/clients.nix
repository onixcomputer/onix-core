{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    types
    mapAttrs'
    nameValuePair
    ;
  cfg = config.services.keycloak;

  clientType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Client name/ID";
      };

      realmId = mkOption {
        type = types.str;
        description = "Realm ID where this client belongs";
      };

      clientId = mkOption {
        type = types.str;
        description = "Client ID for authentication";
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the client is enabled";
      };

      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client description";
      };

      accessType = mkOption {
        type = types.enum [
          "PUBLIC"
          "CONFIDENTIAL"
          "BEARER-ONLY"
        ];
        default = "CONFIDENTIAL";
        description = "Client access type";
      };

      clientSecret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client secret (for confidential clients)";
      };

      standardFlowEnabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether standard flow (authorization code) is enabled";
      };

      implicitFlowEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether implicit flow is enabled";
      };

      directAccessGrantsEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether direct access grants (password flow) are enabled";
      };

      serviceAccountsEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether service accounts are enabled";
      };

      validRedirectUris = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of valid redirect URIs";
        example = [
          "https://app.example.com/*"
          "http://localhost:3000/*"
        ];
      };

      validPostLogoutRedirectUris = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of valid post-logout redirect URIs";
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

      pkceCodeChallengeMethod = mkOption {
        type = types.nullOr (
          types.enum [
            "plain"
            "S256"
          ]
        );
        default = null;
        description = "PKCE code challenge method";
      };

      accessTokenLifespan = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Access token lifespan for this client";
      };

      clientOfflineSessionIdleTimeout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client offline session idle timeout";
      };

      clientOfflineSessionMaxLifespan = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client offline session max lifespan";
      };

      clientSessionIdleTimeout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client session idle timeout";
      };

      clientSessionMaxLifespan = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client session max lifespan";
      };

      consentRequired = mkOption {
        type = types.bool;
        default = false;
        description = "Whether user consent is required";
      };

      displayOnConsentScreen = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to display on consent screen";
      };

      frontchannelLogout = mkOption {
        type = types.bool;
        default = false;
        description = "Whether front-channel logout is enabled";
      };

      fullScopeAllowed = mkOption {
        type = types.bool;
        default = true;
        description = "Whether full scope is allowed";
      };

      attributes = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Custom client attributes";
      };

      authenticationFlowBindingOverrides = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Authentication flow binding overrides";
      };

      defaultClientScopes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of default client scopes";
        example = [
          "openid"
          "profile"
          "email"
        ];
      };

      optionalClientScopes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of optional client scopes";
      };
    };
  };

  clientScopeType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Client scope name";
      };

      realmId = mkOption {
        type = types.str;
        description = "Realm ID where this client scope belongs";
      };

      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client scope description";
      };

      protocol = mkOption {
        type = types.str;
        default = "openid-connect";
        description = "Protocol for the client scope";
      };

      attributes = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Custom client scope attributes";
      };

      consentScreenText = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Text to display on consent screen";
      };

      guiOrder = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "GUI order for display";
      };

      includeInTokenScope = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to include in token scope";
      };
    };
  };
in
{
  options.services.keycloak = {
    clients = mkOption {
      type = types.attrsOf clientType;
      default = { };
      description = "Keycloak clients to manage";
      example = {
        "my-app" = {
          name = "my-app";
          realmId = "my-realm";
          clientId = "my-application";
          accessType = "CONFIDENTIAL";
          validRedirectUris = [ "https://app.example.com/*" ];
          webOrigins = [ "https://app.example.com" ];
        };
      };
    };

    clientScopes = mkOption {
      type = types.attrsOf clientScopeType;
      default = { };
      description = "Keycloak client scopes to manage";
      example = {
        "custom-scope" = {
          name = "custom-scope";
          realmId = "my-realm";
          description = "Custom application scope";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Client Scopes
    resource.keycloak_openid_client_scope = mapAttrs' (
      scopeId: scopeCfg:
      nameValuePair scopeId {
        realm_id = scopeCfg.realmId;
        name = scopeCfg.name;
        description = scopeCfg.description;
        protocol = scopeCfg.protocol;
        attributes = scopeCfg.attributes;
        consent_screen_text = scopeCfg.consentScreenText;
        gui_order = scopeCfg.guiOrder;
        include_in_token_scope = scopeCfg.includeInTokenScope;
      }
    ) cfg.clientScopes;

    # Clients
    resource.keycloak_openid_client = mapAttrs' (
      clientName: clientCfg:
      nameValuePair clientName {
        realm_id = clientCfg.realmId;
        client_id = clientCfg.clientId;
        name = clientCfg.name;
        enabled = clientCfg.enabled;
        description = clientCfg.description;
        access_type = clientCfg.accessType;
        client_secret = clientCfg.clientSecret;

        standard_flow_enabled = clientCfg.standardFlowEnabled;
        implicit_flow_enabled = clientCfg.implicitFlowEnabled;
        direct_access_grants_enabled = clientCfg.directAccessGrantsEnabled;
        service_accounts_enabled = clientCfg.serviceAccountsEnabled;

        valid_redirect_uris = clientCfg.validRedirectUris;
        valid_post_logout_redirect_uris = clientCfg.validPostLogoutRedirectUris;
        web_origins = clientCfg.webOrigins;

        admin_url = clientCfg.adminUrl;
        base_url = clientCfg.baseUrl;
        root_url = clientCfg.rootUrl;

        pkce_code_challenge_method = clientCfg.pkceCodeChallengeMethod;

        access_token_lifespan = clientCfg.accessTokenLifespan;
        client_offline_session_idle_timeout = clientCfg.clientOfflineSessionIdleTimeout;
        client_offline_session_max_lifespan = clientCfg.clientOfflineSessionMaxLifespan;
        client_session_idle_timeout = clientCfg.clientSessionIdleTimeout;
        client_session_max_lifespan = clientCfg.clientSessionMaxLifespan;

        consent_required = clientCfg.consentRequired;
        display_on_consent_screen = clientCfg.displayOnConsentScreen;
        frontchannel_logout = clientCfg.frontchannelLogout;
        full_scope_allowed = clientCfg.fullScopeAllowed;

        attributes = clientCfg.attributes;
        authentication_flow_binding_overrides = clientCfg.authenticationFlowBindingOverrides;
      }
    ) cfg.clients;

    # Default Client Scope Mappings
    resource.keycloak_openid_client_default_scopes = mapAttrs' (
      clientName: clientCfg:
      nameValuePair "${clientName}_default_scopes" {
        realm_id = clientCfg.realmId;
        client_id = "\${keycloak_openid_client.${clientName}.id}";
        default_scopes = clientCfg.defaultClientScopes;
      }
    ) (lib.filterAttrs (_: clientCfg: clientCfg.defaultClientScopes != [ ]) cfg.clients);

    # Optional Client Scope Mappings
    resource.keycloak_openid_client_optional_scopes = mapAttrs' (
      clientName: clientCfg:
      nameValuePair "${clientName}_optional_scopes" {
        realm_id = clientCfg.realmId;
        client_id = "\${keycloak_openid_client.${clientName}.id}";
        optional_scopes = clientCfg.optionalClientScopes;
      }
    ) (lib.filterAttrs (_: clientCfg: clientCfg.optionalClientScopes != [ ]) cfg.clients);
  };
}
