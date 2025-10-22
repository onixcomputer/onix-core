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

  userType = types.submodule {
    options = {
      username = mkOption {
        type = types.str;
        description = "Username for the user";
      };

      realmId = mkOption {
        type = types.str;
        description = "Realm ID where this user belongs";
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the user is enabled";
      };

      email = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email address for the user";
      };

      emailVerified = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the email is verified";
      };

      firstName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "First name of the user";
      };

      lastName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Last name of the user";
      };

      attributes = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Custom attributes for the user";
        example = {
          department = [ "engineering" ];
        };
      };

      initialPassword = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Initial password for the user (temporary)";
      };

      temporaryPassword = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the initial password is temporary and must be changed";
      };

      groups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of group names this user belongs to";
      };

      realmRoles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of realm role names assigned to this user";
      };

      clientRoles = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Client roles assigned to this user, keyed by client ID";
        example = {
          "my-client" = [
            "admin"
            "user"
          ];
        };
      };
    };
  };

  groupType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Group name";
      };

      realmId = mkOption {
        type = types.str;
        description = "Realm ID where this group belongs";
      };

      parentId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Parent group ID for nested groups";
      };

      attributes = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Custom attributes for the group";
      };

      realmRoles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of realm role names assigned to this group";
      };

      clientRoles = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Client roles assigned to this group, keyed by client ID";
      };
    };
  };

  roleType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Role name";
      };

      realmId = mkOption {
        type = types.str;
        description = "Realm ID where this role belongs";
      };

      clientId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Client ID for client roles (null for realm roles)";
      };

      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Role description";
      };

      attributes = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "Custom attributes for the role";
      };

      composite = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is a composite role";
      };

      compositeRoles = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of role names that this composite role includes";
      };
    };
  };
in
{
  options.services.keycloak = {
    users = mkOption {
      type = types.attrsOf userType;
      default = { };
      description = "Keycloak users to manage";
      example = {
        "john-doe" = {
          username = "john.doe";
          realmId = "my-realm";
          email = "john.doe@example.com";
          firstName = "John";
          lastName = "Doe";
          groups = [ "developers" ];
          realmRoles = [ "user" ];
        };
      };
    };

    groups = mkOption {
      type = types.attrsOf groupType;
      default = { };
      description = "Keycloak groups to manage";
      example = {
        "developers" = {
          name = "developers";
          realmId = "my-realm";
          realmRoles = [ "developer" ];
        };
      };
    };

    roles = mkOption {
      type = types.attrsOf roleType;
      default = { };
      description = "Keycloak roles to manage";
      example = {
        "developer" = {
          name = "developer";
          realmId = "my-realm";
          description = "Developer role with access to development resources";
        };
        "admin-role" = {
          name = "admin";
          realmId = "my-realm";
          clientId = "my-client";
          description = "Client-specific admin role";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      # Realm Roles
      keycloak_role = mapAttrs' (
        roleId: roleCfg:
        nameValuePair roleId (
          let
            baseRole = {
              realm_id = roleCfg.realmId;
              inherit (roleCfg) name description;
              inherit (roleCfg) attributes;
              composite_roles = if roleCfg.composite then roleCfg.compositeRoles else null;
            };
          in
          if roleCfg.clientId != null then
            baseRole
            // {
              client_id = roleCfg.clientId;
            }
          else
            baseRole
        )
      ) cfg.roles;

      # Groups
      keycloak_group = mapAttrs' (
        groupId: groupCfg:
        nameValuePair groupId {
          realm_id = groupCfg.realmId;
          inherit (groupCfg) name;
          parent_id = groupCfg.parentId;
          inherit (groupCfg) attributes;
        }
      ) cfg.groups;

      # Group Realm Role Mappings
      keycloak_group_roles = mapAttrs' (
        groupId: groupCfg:
        nameValuePair "${groupId}_realm_roles" {
          realm_id = groupCfg.realmId;
          group_id = "\${keycloak_group.${groupId}.id}";
          role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") groupCfg.realmRoles;
        }
      ) (lib.filterAttrs (_: groupCfg: groupCfg.realmRoles != [ ]) cfg.groups);

      # Users
      keycloak_user = mapAttrs' (
        userId: userCfg:
        nameValuePair userId {
          realm_id = userCfg.realmId;
          inherit (userCfg) username enabled email;
          email_verified = userCfg.emailVerified;
          first_name = userCfg.firstName;
          last_name = userCfg.lastName;
          inherit (userCfg) attributes;
          initial_password = mkIf (userCfg.initialPassword != null) {
            value = userCfg.initialPassword;
            temporary = userCfg.temporaryPassword;
          };
        }
      ) cfg.users;

      # User Group Memberships
      keycloak_user_groups = mapAttrs' (
        userId: userCfg:
        nameValuePair "${userId}_groups" {
          inherit (userCfg) realm_id;
          user_id = "\${keycloak_user.${userId}.id}";
          group_ids = map (groupName: "\${keycloak_group.${groupName}.id}") userCfg.groups;
        }
      ) (lib.filterAttrs (_: userCfg: userCfg.groups != [ ]) cfg.users);

      # User Realm Role Mappings
      keycloak_user_roles = mapAttrs' (
        userId: userCfg:
        nameValuePair "${userId}_realm_roles" {
          inherit (userCfg) realm_id;
          user_id = "\${keycloak_user.${userId}.id}";
          role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") userCfg.realmRoles;
        }
      ) (lib.filterAttrs (_: userCfg: userCfg.realmRoles != [ ]) cfg.users);

      # Client Role Mappings for Users
      keycloak_user_client_roles = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            userId: userCfg:
            lib.mapAttrsToList (
              clientId: roles:
              nameValuePair "${userId}_${clientId}_roles" {
                inherit (userCfg) realm_id;
                user_id = "\${keycloak_user.${userId}.id}";
                inherit clientId;
                role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") roles;
              }
            ) userCfg.clientRoles
          ) (lib.filterAttrs (_: userCfg: userCfg.clientRoles != { }) cfg.users)
        )
      );

      # Client Role Mappings for Groups
      keycloak_group_client_roles = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            groupId: groupCfg:
            lib.mapAttrsToList (
              clientId: roles:
              nameValuePair "${groupId}_${clientId}_roles" {
                inherit (groupCfg) realm_id;
                group_id = "\${keycloak_group.${groupId}.id}";
                inherit clientId;
                role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") roles;
              }
            ) groupCfg.clientRoles
          ) (lib.filterAttrs (_: groupCfg: groupCfg.clientRoles != { }) cfg.groups)
        )
      );
    };
  };
}
