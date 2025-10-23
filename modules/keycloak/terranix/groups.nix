# Keycloak Groups Module
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

  # Comprehensive group configuration type
  groupType = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = "Group name (defaults to attribute name)";
        };

        realmId = mkOption {
          type = types.str;
          description = ''
            Realm where this group belongs.
            Should reference a realm defined in the realms configuration.
          '';
        };

        # Hierarchy
        parentGroup = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Name of the parent group.
            Should reference another group defined in the groups configuration.
          '';
        };

        # Custom attributes
        attributes = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = ''
            Custom attributes for the group.
            Values are lists of strings to support multi-value attributes.
          '';
          example = {
            department = [ "engineering" ];
            permissions = [
              "read"
              "write"
            ];
            cost_center = [ "CC-1234" ];
          };
        };

        # Role assignments
        realmRoles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of realm role names to assign to the group";
          example = [
            "user"
            "developer"
          ];
        };

        clientRoles = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = ''
            Client roles to assign to the group.
            Key is the client name, value is list of role names.
          '';
          example = {
            "web-app" = [ "app-user" ];
            "api-service" = [
              "read"
              "write"
            ];
          };
        };

        # Group management settings
        access = mkOption {
          type = types.submodule {
            options = {
              view = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the group can be viewed";
              };

              manage = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the group can be managed";
              };

              manageMembership = mkOption {
                type = types.bool;
                default = true;
                description = "Whether group membership can be managed";
              };

              viewMembers = mkOption {
                type = types.bool;
                default = true;
                description = "Whether group members can be viewed";
              };
            };
          };
          default = { };
          description = "Group access permissions";
        };

        # Default group settings
        defaultGroup = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether this is a default group.
            Default groups are automatically assigned to new users.
          '';
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    groups = mkOption {
      type = types.attrsOf groupType;
      default = { };
      description = "Keycloak groups to manage";
      example = {
        "administrators" = {
          name = "administrators";
          realmId = "company";
          realmRoles = [ "admin" ];
          clientRoles = {
            "web-app" = [ "admin" ];
            "api-service" = [
              "read"
              "write"
              "admin"
            ];
          };
          attributes = {
            department = [ "it" ];
            level = [ "admin" ];
          };
        };
        "developers" = {
          name = "developers";
          realmId = "company";
          parentGroup = "employees";
          realmRoles = [
            "user"
            "developer"
          ];
          clientRoles = {
            "api-service" = [
              "read"
              "write"
            ];
          };
          attributes = {
            department = [ "engineering" ];
            access_level = [ "developer" ];
          };
        };
        "employees" = {
          name = "employees";
          realmId = "company";
          realmRoles = [ "user" ];
          defaultGroup = true;
          attributes = {
            organization = [ "company" ];
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      # Create group resources
      keycloak_group = mapAttrs' (
        groupName: groupCfg:
        nameValuePair "${cfg.settings.resourcePrefix}${groupName}" (
          filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            realm_id = realmRef groupCfg.realmId;
            inherit (groupCfg) name;

            # Parent group reference
            parent_id = lib.mkIf (
              groupCfg.parentGroup != null
            ) "\${keycloak_group.${cfg.settings.resourcePrefix}${groupCfg.parentGroup}.id}";

            # Custom attributes
            inherit (groupCfg) attributes;
          }
        )
      ) cfg.groups;

      # Create realm role mappings for groups
      keycloak_group_realm_role_mapping = lib.mkMerge (
        lib.mapAttrsToList (
          groupName: groupCfg:
          lib.optionalAttrs (groupCfg.realmRoles != [ ]) {
            "${cfg.settings.resourcePrefix}${groupName}_realm_roles" = {
              realm_id = realmRef groupCfg.realmId;
              group_id = "\${keycloak_group.${cfg.settings.resourcePrefix}${groupName}.id}";
              role_ids = map (
                roleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${roleName}.id}"
              ) groupCfg.realmRoles;
            };
          }
        ) cfg.groups
      );

      # Create client role mappings for groups
      keycloak_group_client_role_mapping = lib.mkMerge (
        lib.flatten (
          lib.mapAttrsToList (
            groupName: groupCfg:
            lib.mapAttrsToList (clientName: roles: {
              "${cfg.settings.resourcePrefix}${groupName}_${clientName}_roles" = {
                realm_id = realmRef groupCfg.realmId;
                group_id = "\${keycloak_group.${cfg.settings.resourcePrefix}${groupName}.id}";
                client_id = "\${keycloak_openid_client.${cfg.settings.resourcePrefix}${clientName}.id}";
                role_ids = map (
                  roleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${clientName}_${roleName}.id}"
                ) roles;
              };
            }) groupCfg.clientRoles
          ) cfg.groups
        )
      );

      # Create default group mappings
      keycloak_default_groups =
        lib.mkIf (lib.any (group: group.defaultGroup) (lib.attrValues cfg.groups))
          (
            lib.mkMerge (
              lib.mapAttrsToList (
                groupName: groupCfg:
                lib.optionalAttrs groupCfg.defaultGroup {
                  "${cfg.settings.resourcePrefix}${groupName}_default" = {
                    realm_id = realmRef groupCfg.realmId;
                    group_ids = [ "\${keycloak_group.${cfg.settings.resourcePrefix}${groupName}.id}" ];
                  };
                }
              ) cfg.groups
            )
          );
    };
  };
}
