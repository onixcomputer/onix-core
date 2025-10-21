# Keycloak Client Scopes Module
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

  # Protocol mapper type for client scopes
  protocolMapperType = types.submodule {
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
        example = "oidc-usermodel-property-mapper";
      };

      consentRequired = mkOption {
        type = types.bool;
        default = false;
        description = "Whether consent is required for this mapper";
      };

      consentText = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Consent text for this mapper";
      };

      config = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Mapper configuration";
        example = {
          "user.attribute" = "email";
          "claim.name" = "email";
          "jsonType.label" = "String";
          "id.token.claim" = "true";
          "access.token.claim" = "true";
          "userinfo.token.claim" = "true";
        };
      };
    };
  };

  # Comprehensive client scope configuration type
  clientScopeType = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = "Client scope name (defaults to attribute name)";
        };

        realmId = mkOption {
          type = types.str;
          description = ''
            Realm where this client scope belongs.
            Should reference a realm defined in the realms configuration.
          '';
        };

        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Client scope description";
        };

        protocol = mkOption {
          type = types.str;
          default = "openid-connect";
          description = "Protocol for this client scope";
        };

        # Consent settings
        consentScreenText = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Text to display on the consent screen for this scope";
        };

        displayOnConsentScreen = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to display this scope on the consent screen";
        };

        # Token inclusion settings
        includeInTokenScope = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to include this scope in token scope";
        };

        guiOrder = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "GUI order for displaying this scope";
        };

        # Custom attributes
        attributes = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Custom attributes for the client scope";
        };

        # Protocol mappers
        protocolMappers = mkOption {
          type = types.listOf protocolMapperType;
          default = [ ];
          description = "Protocol mappers for this client scope";
          example = [
            {
              name = "email";
              protocolMapper = "oidc-usermodel-property-mapper";
              config = {
                "user.attribute" = "email";
                "claim.name" = "email";
                "jsonType.label" = "String";
                "id.token.claim" = "true";
                "access.token.claim" = "true";
                "userinfo.token.claim" = "true";
              };
            }
            {
              name = "groups";
              protocolMapper = "oidc-group-membership-mapper";
              config = {
                "claim.name" = "groups";
                "full.path" = "false";
                "id.token.claim" = "true";
                "access.token.claim" = "true";
                "userinfo.token.claim" = "true";
              };
            }
          ];
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    clientScopes = mkOption {
      type = types.attrsOf clientScopeType;
      default = { };
      description = "Keycloak client scopes to manage";
      example = {
        "company-profile" = {
          name = "company-profile";
          realmId = "company";
          description = "Company-specific profile information";
          consentScreenText = "Access to your company profile";
          protocolMappers = [
            {
              name = "department";
              protocolMapper = "oidc-usermodel-attribute-mapper";
              config = {
                "user.attribute" = "department";
                "claim.name" = "department";
                "jsonType.label" = "String";
                "id.token.claim" = "true";
                "access.token.claim" = "true";
                "userinfo.token.claim" = "true";
              };
            }
            {
              name = "employee_id";
              protocolMapper = "oidc-usermodel-attribute-mapper";
              config = {
                "user.attribute" = "employee_id";
                "claim.name" = "employee_id";
                "jsonType.label" = "String";
                "id.token.claim" = "false";
                "access.token.claim" = "true";
                "userinfo.token.claim" = "true";
              };
            }
          ];
        };
        "api-access" = {
          name = "api-access";
          realmId = "company";
          description = "API access scope for backend services";
          displayOnConsentScreen = false;
          protocolMappers = [
            {
              name = "audience";
              protocolMapper = "oidc-audience-mapper";
              config = {
                "included.client.audience" = "api-service";
                "id.token.claim" = "false";
                "access.token.claim" = "true";
              };
            }
          ];
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      # Create client scope resources
      keycloak_openid_client_scope = mapAttrs' (
        scopeName: scopeCfg:
        nameValuePair "${cfg.settings.resourcePrefix}${scopeName}" (
          filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            realm_id = realmRef scopeCfg.realmId;
            inherit (scopeCfg) name description protocol;
            consent_screen_text = scopeCfg.consentScreenText;
            display_on_consent_screen = scopeCfg.displayOnConsentScreen;
            include_in_token_scope = scopeCfg.includeInTokenScope;
            gui_order = scopeCfg.guiOrder;
            inherit (scopeCfg) attributes;
          }
        )
      ) cfg.clientScopes;

      # Create protocol mappers for client scopes
      keycloak_openid_client_scope_protocol_mapper = lib.mkMerge (
        lib.flatten (
          lib.mapAttrsToList (
            scopeName: scopeCfg:
            lib.imap0 (idx: mapper: {
              "${cfg.settings.resourcePrefix}${scopeName}_mapper_${toString idx}" = {
                realm_id = realmRef scopeCfg.realmId;
                client_scope_id = "\${keycloak_openid_client_scope.${cfg.settings.resourcePrefix}${scopeName}.id}";
                inherit (mapper) name protocol;
                protocol_mapper = mapper.protocolMapper;
                consent_required = mapper.consentRequired;
                consent_text = mapper.consentText;
                inherit (mapper) config;
              };
            }) scopeCfg.protocolMappers
          ) cfg.clientScopes
        )
      );
    };
  };
}
