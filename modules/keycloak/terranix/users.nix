# Keycloak Users Module
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

  # Comprehensive user configuration type
  userType = types.submodule (
    { name, ... }:
    {
      options = {
        username = mkOption {
          type = types.str;
          default = name;
          description = "Username (defaults to attribute name)";
        };

        realmId = mkOption {
          type = types.str;
          description = ''
            Realm where this user belongs.
            Should reference a realm defined in the realms configuration.
          '';
        };

        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the user is enabled";
        };

        # Basic user information
        email = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "User email address";
        };

        emailVerified = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the user's email is verified";
        };

        firstName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "User's first name";
        };

        lastName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "User's last name";
        };

        # Password settings
        initialPassword = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                value = mkOption {
                  type = types.str;
                  description = ''
                    Initial password value.
                    Should reference a variable for security.
                  '';
                  example = "\${var.user_password}";
                };

                temporary = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether the password is temporary (user must change on first login)";
                };
              };
            }
          );
          default = null;
          description = "Initial password configuration";
        };

        # Custom attributes
        attributes = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = ''
            Custom attributes for the user.
            Values are lists of strings to support multi-value attributes.
          '';
          example = {
            department = [ "engineering" ];
            team = [
              "backend"
              "devops"
            ];
            employee_id = [ "EMP-12345" ];
          };
        };

        # Group memberships
        groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            List of group names the user should be a member of.
            Groups should be defined in the groups configuration.
          '';
          example = [
            "developers"
            "admin"
          ];
        };

        # Role assignments
        realmRoles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of realm role names to assign to the user";
          example = [
            "user"
            "admin"
          ];
        };

        clientRoles = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          description = ''
            Client roles to assign to the user.
            Key is the client name, value is list of role names.
          '';
          example = {
            "web-app" = [
              "app-user"
              "app-admin"
            ];
            "api-service" = [
              "read"
              "write"
            ];
          };
        };

        # Federation and identity provider links
        federatedIdentities = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                identityProvider = mkOption {
                  type = types.str;
                  description = "Identity provider alias";
                };

                userId = mkOption {
                  type = types.str;
                  description = "User ID in the identity provider";
                };

                userName = mkOption {
                  type = types.str;
                  description = "Username in the identity provider";
                };
              };
            }
          );
          default = [ ];
          description = "Federated identity provider links";
        };

        # Required actions
        requiredActions = mkOption {
          type = types.listOf (
            types.enum [
              "VERIFY_EMAIL"
              "UPDATE_PROFILE"
              "CONFIGURE_TOTP"
              "UPDATE_PASSWORD"
              "terms_and_conditions"
            ]
          );
          default = [ ];
          description = "Required actions the user must complete";
        };

        # Access settings
        access = mkOption {
          type = types.submodule {
            options = {
              manageGroupMembership = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the user can manage group membership";
              };

              view = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the user can be viewed";
              };

              mapRoles = mkOption {
                type = types.bool;
                default = true;
                description = "Whether roles can be mapped to the user";
              };

              impersonate = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the user can be impersonated";
              };

              manage = mkOption {
                type = types.bool;
                default = true;
                description = "Whether the user can be managed";
              };
            };
          };
          default = { };
          description = "User access permissions";
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    users = mkOption {
      type = types.attrsOf userType;
      default = { };
      description = "Keycloak users to manage";
      example = {
        "admin-user" = {
          username = "admin";
          realmId = "company";
          email = "admin@company.com";
          emailVerified = true;
          firstName = "System";
          lastName = "Administrator";
          initialPassword = {
            value = "\${var.admin_password}";
            temporary = true;
          };
          groups = [ "administrators" ];
          realmRoles = [ "admin" ];
          attributes = {
            department = [ "it" ];
            role = [ "system-admin" ];
          };
        };
        "john-doe" = {
          username = "john.doe";
          realmId = "company";
          email = "john.doe@company.com";
          emailVerified = true;
          firstName = "John";
          lastName = "Doe";
          groups = [ "developers" ];
          realmRoles = [ "user" ];
          clientRoles = {
            "web-app" = [ "app-user" ];
            "api-service" = [
              "read"
              "write"
            ];
          };
          attributes = {
            department = [ "engineering" ];
            team = [ "backend" ];
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource = {
      # Create user resources
      keycloak_user = mapAttrs' (
        userName: userCfg:
        nameValuePair "${cfg.settings.resourcePrefix}${userName}" (
          filterAttrs (_: v: v != null && v != [ ] && v != { }) {
            realm_id = realmRef userCfg.realmId;
            inherit (userCfg) username enabled email;
            email_verified = userCfg.emailVerified;
            first_name = userCfg.firstName;
            last_name = userCfg.lastName;

            # Initial password
            initial_password = lib.mkIf (userCfg.initialPassword != null) {
              inherit (userCfg.initialPassword) value temporary;
            };

            # Custom attributes
            inherit (userCfg) attributes;

            # Required actions
            required_actions = lib.mkIf (userCfg.requiredActions != [ ]) userCfg.requiredActions;
          }
        )
      ) cfg.users;

      # Create group memberships
      keycloak_user_groups = lib.mkMerge (
        lib.mapAttrsToList (
          userName: userCfg:
          lib.optionalAttrs (userCfg.groups != [ ]) {
            "${cfg.settings.resourcePrefix}${userName}_groups" = {
              realm_id = realmRef userCfg.realmId;
              user_id = "\${keycloak_user.${cfg.settings.resourcePrefix}${userName}.id}";
              group_ids = map (
                groupName: "\${keycloak_group.${cfg.settings.resourcePrefix}${groupName}.id}"
              ) userCfg.groups;
            };
          }
        ) cfg.users
      );

      # Create realm role mappings
      keycloak_user_realm_role_mapping = lib.mkMerge (
        lib.mapAttrsToList (
          userName: userCfg:
          lib.optionalAttrs (userCfg.realmRoles != [ ]) {
            "${cfg.settings.resourcePrefix}${userName}_realm_roles" = {
              realm_id = realmRef userCfg.realmId;
              user_id = "\${keycloak_user.${cfg.settings.resourcePrefix}${userName}.id}";
              role_ids = map (
                roleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${roleName}.id}"
              ) userCfg.realmRoles;
            };
          }
        ) cfg.users
      );

      # Create client role mappings
      keycloak_user_client_role_mapping = lib.mkMerge (
        lib.flatten (
          lib.mapAttrsToList (
            userName: userCfg:
            lib.mapAttrsToList (clientName: roles: {
              "${cfg.settings.resourcePrefix}${userName}_${clientName}_roles" = {
                realm_id = realmRef userCfg.realmId;
                user_id = "\${keycloak_user.${cfg.settings.resourcePrefix}${userName}.id}";
                client_id = "\${keycloak_openid_client.${cfg.settings.resourcePrefix}${clientName}.id}";
                role_ids = map (
                  roleName: "\${keycloak_role.${cfg.settings.resourcePrefix}${clientName}_${roleName}.id}"
                ) roles;
              };
            }) userCfg.clientRoles
          ) cfg.users
        )
      );

      # Create federated identity links
      keycloak_user_federated_identity = lib.mkMerge (
        lib.flatten (
          lib.mapAttrsToList (
            userName: userCfg:
            lib.imap0 (idx: fedId: {
              "${cfg.settings.resourcePrefix}${userName}_federated_${toString idx}" = {
                realm_id = realmRef userCfg.realmId;
                user_id = "\${keycloak_user.${cfg.settings.resourcePrefix}${userName}.id}";
                identity_provider = fedId.identityProvider;
                federated_user_id = fedId.userId;
                federated_username = fedId.userName;
              };
            }) userCfg.federatedIdentities
          ) cfg.users
        )
      );
    };
  };
}
