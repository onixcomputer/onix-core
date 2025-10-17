{ lib, config, ... }:

{
  # Keycloak OIDC Clients Management Module
  # This module handles the creation and configuration of Keycloak OIDC clients

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Generate client resources from configuration
      resources = lib.mkMerge [
        (lib.mapAttrs' (
          clientName: clientConfig:
          lib.nameValuePair "keycloak_openid_client.${clientName}" {
            realm_id = "\${keycloak_realm.${clientConfig.realm}.id}";
            client_id = clientName;
            name = clientConfig.name or clientName;
            description = clientConfig.description or "OIDC client for ${clientName}";

            # Basic configuration
            enabled = clientConfig.enabled or true;
            access_type = clientConfig.accessType or "CONFIDENTIAL";

            # Flow configuration
            standard_flow_enabled = clientConfig.standardFlowEnabled or true;
            implicit_flow_enabled = clientConfig.implicitFlowEnabled or false;
            direct_access_grants_enabled = clientConfig.directAccessGrantsEnabled or false;
            service_accounts_enabled = clientConfig.serviceAccountsEnabled or false;

            # Advanced flow settings
            oauth2_device_authorization_grant_enabled =
              clientConfig.oauth2DeviceAuthorizationGrantEnabled or false;
            oidc_ciba_grant_enabled = clientConfig.oidcCibaGrantEnabled or false;

            # URLs and redirects
            root_url = clientConfig.rootUrl or "";
            admin_url = clientConfig.adminUrl or "";
            base_url = clientConfig.baseUrl or "/";
            web_origins = clientConfig.webOrigins or [ ];
            valid_redirect_uris = clientConfig.validRedirectUris or [ ];
            valid_post_logout_redirect_uris = clientConfig.validPostLogoutRedirectUris or [ ];

            # Security settings
            pkce_code_challenge_method = clientConfig.pkceCodeChallengeMethod or "";
            exclude_session_state_from_auth_response =
              clientConfig.excludeSessionStateFromAuthResponse or false;

            # Client authentication
            client_authenticator_type = clientConfig.clientAuthenticatorType or "client-secret";
            client_secret = lib.mkIf (clientConfig.clientSecret or null != null) clientConfig.clientSecret;

            # Consent settings
            consent_required = clientConfig.consentRequired or false;
            display_on_consent_screen = clientConfig.displayOnConsentScreen or true;
            consent_screen_text = clientConfig.consentScreenText or "";

            # Login settings
            login_theme = clientConfig.loginTheme or "";

            # Access settings
            full_scope_allowed = clientConfig.fullScopeAllowed or true;
            frontchannel_logout_enabled = clientConfig.frontchannelLogoutEnabled or false;
            frontchannel_logout_url = clientConfig.frontchannelLogoutUrl or "";
            backchannel_logout_url = clientConfig.backchannelLogoutUrl or "";
            backchannel_logout_session_required = clientConfig.backchannelLogoutSessionRequired or true;
            backchannel_logout_revoke_offline_sessions =
              clientConfig.backchannelLogoutRevokeOfflineSessions or false;

            # Token settings
            access_token_lifespan = clientConfig.accessTokenLifespan or "";
            client_session_idle_timeout = clientConfig.clientSessionIdleTimeout or "";
            client_session_max_lifespan = clientConfig.clientSessionMaxLifespan or "";
            client_offline_session_idle_timeout = clientConfig.clientOfflineSessionIdleTimeout or "";
            client_offline_session_max_lifespan = clientConfig.clientOfflineSessionMaxLifespan or "";

            # Authentication flow overrides
            authentication_flow_binding_overrides =
              lib.mkIf (clientConfig.authenticationFlowBindingOverrides or { } != { })
                {
                  browser_id = clientConfig.authenticationFlowBindingOverrides.browserId or "";
                  direct_grant_id = clientConfig.authenticationFlowBindingOverrides.directGrantId or "";
                };

            # Custom attributes
            extra_config = lib.mkIf (clientConfig.extraConfig or { } != { }) clientConfig.extraConfig;
          }
        ) config.keycloak.terraform.clients)

        # Generate client scopes if defined
        (lib.optionalAttrs (config.keycloak.terraform.clientScopes or { } != { }) (
          lib.mapAttrs' (
            scopeName: scopeConfig:
            lib.nameValuePair "keycloak_openid_client_scope.${scopeName}" {
              realm_id = "\${keycloak_realm.${scopeConfig.realm}.id}";
              name = scopeName;
              description = scopeConfig.description or "Client scope for ${scopeName}";

              # Scope configuration
              consent_screen_text = scopeConfig.consentScreenText or "";
              include_in_token_scope = scopeConfig.includeInTokenScope or true;
              gui_order = scopeConfig.guiOrder or 1;
            }
          ) config.keycloak.terraform.clientScopes
        ))

        # Generate client scope mappings if defined
        (lib.optionalAttrs (config.keycloak.terraform.clientScopeMappings or { } != { }) (
          lib.mapAttrs' (
            mappingName: mappingConfig:
            lib.nameValuePair "keycloak_openid_client_default_scopes.${mappingName}" {
              realm_id = "\${keycloak_realm.${mappingConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${mappingConfig.client}.id}";
              default_scopes = mappingConfig.defaultScopes or [ ];
            }
          ) config.keycloak.terraform.clientScopeMappings
        ))

        # Generate client protocol mappers if defined
        (lib.optionalAttrs (config.keycloak.terraform.clientProtocolMappers or { } != { }) (
          lib.mapAttrs' (
            mapperName: mapperConfig:
            lib.nameValuePair "keycloak_openid_user_attribute_protocol_mapper.${mapperName}" {
              realm_id = "\${keycloak_realm.${mapperConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${mapperConfig.client}.id}";
              name = mapperName;

              # Mapper configuration
              user_attribute = mapperConfig.userAttribute;
              claim_name = mapperConfig.claimName;
              claim_value_type = mapperConfig.claimValueType or "String";

              # Token inclusion
              add_to_id_token = mapperConfig.addToIdToken or true;
              add_to_access_token = mapperConfig.addToAccessToken or true;
              add_to_userinfo = mapperConfig.addToUserinfo or true;

              # Multivalued
              multivalued = mapperConfig.multivalued or false;
              aggregate_attributes = mapperConfig.aggregateAttributes or false;
            }
          ) config.keycloak.terraform.clientProtocolMappers
        ))
      ];
    };
  };
}
