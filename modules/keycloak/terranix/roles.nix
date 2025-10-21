# Keycloak Roles Module
{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    mkIf
    types
    mapAttrs'
    nameValuePair
    filterAttrs
    mkMerge
    mapAttrsToList
    optionalAttrs
    mapAttrs
    ;

  cfg = config.services.keycloak;

  # Helper function to generate realm reference
  realmRef = realmName: "\${keycloak_realm.${cfg.settings.resourcePrefix}${realmName}.id}";

  # Comprehensive role configuration type
  roleType = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = "Role name (defaults to attribute name)";
        };

        realmId = mkOption {
          type = types.str;
          description = ''
            Realm where this role belongs.
            Should reference a realm defined in the realms configuration.
          '';
        };

        # Role type - realm or client role
        clientId = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Client ID for client roles.
            If null, this will be a realm role.
            Should reference a client defined in the clients configuration.
          '';
        };

        description = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Role description";
        };

        # Role composition
        compositeRoles = mkOption {
          type = types.submodule {
            options = {
              realmRoles = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "List of realm role names to include in this composite role";
              };

              clientRoles = mkOption {
                type = types.attrsOf (types.listOf types.str);
                default = { };
                description = ''
                  Client roles to include in this composite role.
                  Key is the client name, value is list of role names.
                '';
              };
            };
          };
          default = { };
          description = ''
            Composite roles configuration.
            Composite roles automatically include permissions from other roles.
          '';
        };

        # Role attributes
        attributes = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = ''
            Custom attributes for the role.
            Values are lists of strings to support multi-value attributes.
          '';
          example = {
            permissions = [
              "read"
              "write"
              "delete"
            ];
            department = [ "engineering" ];
            access_level = [ "admin" ];
          };
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    roles = mkOption {
      type = types.attrsOf roleType;
      default = { };
      description = "Keycloak roles to manage";
      example = {
        # Realm roles
        "admin" = {
          name = "admin";
          realmId = "company";
          description = "Administrator role with full access";
          attributes = {
            permissions = [ "full_access" ];
            level = [ "admin" ];
          };
        };
        "user" = {
          name = "user";
          realmId = "company";
          description = "Standard user role";
          attributes = {
            permissions = [ "basic_access" ];
            level = [ "user" ];
          };
        };
        "developer" = {
          name = "developer";
          realmId = "company";
          description = "Developer role with development access";
          compositeRoles = {
            realmRoles = [ "user" ];
          };
          attributes = {
            permissions = [
              "dev_access"
              "api_access"
            ];
            level = [ "developer" ];
          };
        };

        # Client roles
        "web-app-admin" = {
          name = "admin";
          realmId = "company";
          clientId = "web-app";
          description = "Web application administrator";
          attributes = {
            app_permissions = [
              "admin_panel"
              "user_management"
            ];
          };
        };
        "web-app-user" = {
          name = "user";
          realmId = "company";
          clientId = "web-app";
          description = "Web application user";
          attributes = {
            app_permissions = [ "basic_features" ];
          };
        };

        # API service roles
        "api-read" = {
          name = "read";
          realmId = "company";
          clientId = "api-service";
          description = "API read access";
          attributes = {
            api_permissions = [ "read" ];
          };
        };
        "api-write" = {
          name = "write";
          realmId = "company";
          clientId = "api-service";
          description = "API write access";
          compositeRoles = {
            clientRoles = {
              "api-service" = [ "read" ];
            };
          };
          attributes = {
            api_permissions = [ "write" ];
          };
        };
        "api-admin" = {
          name = "admin";
          realmId = "company";
          clientId = "api-service";
          description = "API full access";
          compositeRoles = {
            clientRoles = {
              "api-service" = [
                "read"
                "write"
              ];
            };
          };
          attributes = {
            api_permissions = [ "admin" ];
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      # Create role resources
      keycloak_role = mapAttrs' (
        roleName: roleCfg:
        let
          # Generate unique resource name
          resourceName =
            if roleCfg.clientId != null then
              "${cfg.settings.resourcePrefix}${roleCfg.clientId}_${roleName}"
            else
              "${cfg.settings.resourcePrefix}${roleName}";
        in
        nameValuePair resourceName (
          filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            realm_id = realmRef roleCfg.realmId;
            inherit (roleCfg) name description;

            # Client ID for client roles
            client_id = mkIf (
              roleCfg.clientId != null
            ) "\${keycloak_openid_client.${cfg.settings.resourcePrefix}${roleCfg.clientId}.id}";

            # Custom attributes
            inherit (roleCfg) attributes;
          }
        )
      ) cfg.roles;

      # Create composite role associations
      keycloak_role_composites = mkMerge (
        mapAttrsToList (
          roleName: roleCfg:
          let
            resourceName =
              if roleCfg.clientId != null then
                "${cfg.settings.resourcePrefix}${roleCfg.clientId}_${roleName}"
              else
                "${cfg.settings.resourcePrefix}${roleName}";

            hasCompositeRoles =
              roleCfg.compositeRoles.realmRoles != [ ] || roleCfg.compositeRoles.clientRoles != { };
          in
          optionalAttrs hasCompositeRoles {
            "${resourceName}_composites" = filterAttrs (_: v: v != null && v != [ ]) {
              realm_id = realmRef roleCfg.realmId;
              role_id = "\${keycloak_role.${resourceName}.id}";

              # Realm role associations
              realm_roles = mkIf (roleCfg.compositeRoles.realmRoles != [ ]) (
                map (
                  realmRoleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${realmRoleName}.id}"
                ) roleCfg.compositeRoles.realmRoles
              );

              # Client role associations
              client_roles = mkIf (roleCfg.compositeRoles.clientRoles != { }) (
                mapAttrs (
                  clientName: roleNames:
                  map (
                    clientRoleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${clientName}_${clientRoleName}.id}"
                  ) roleNames
                ) roleCfg.compositeRoles.clientRoles
              );
            };
          }
        ) cfg.roles
      );
    };
  };
}
