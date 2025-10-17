{ lib, config, ... }:

{
  # Keycloak Users Management Module
  # This module handles the creation and configuration of Keycloak users

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Generate user resources from configuration
      resources = lib.mkMerge [
        (lib.mapAttrs' (
          userName: userConfig:
          lib.nameValuePair "keycloak_user.${userName}" {
            realm_id = "\${keycloak_realm.${userConfig.realm}.id}";
            username = userName;

            # Basic user information
            email = userConfig.email;
            email_verified = userConfig.emailVerified or false;
            first_name = userConfig.firstName;
            last_name = userConfig.lastName;

            # User status
            enabled = userConfig.enabled or true;

            # User attributes
            attributes = lib.mkIf (userConfig.attributes or { } != { }) userConfig.attributes;

            # Initial password configuration
            initial_password = lib.mkIf (userConfig.initialPassword or null != null) {
              value = userConfig.initialPassword;
              temporary = userConfig.temporary or true;
            };

            # Federation link (for users from external identity providers)
            federated_identity = lib.mkIf (userConfig.federatedIdentity or [ ] != [ ]) (
              map (identity: {
                identity_provider = identity.identityProvider;
                user_id = identity.userId;
                user_name = identity.userName;
              }) userConfig.federatedIdentity
            );
          }
        ) config.keycloak.terraform.users)

        # Generate user group memberships if defined
        (lib.optionalAttrs (config.keycloak.terraform.userGroupMemberships or { } != { }) (
          lib.mapAttrs' (
            membershipName: membershipConfig:
            lib.nameValuePair "keycloak_user_groups.${membershipName}" {
              realm_id = "\${keycloak_realm.${membershipConfig.realm}.id}";
              user_id = "\${keycloak_user.${membershipConfig.user}.id}";
              group_ids = map (groupName: "\${keycloak_group.${groupName}.id}") membershipConfig.groups;
            }
          ) config.keycloak.terraform.userGroupMemberships
        ))

        # Generate user role assignments if defined
        (lib.optionalAttrs (config.keycloak.terraform.userRoleAssignments or { } != { }) (
          lib.mapAttrs' (
            assignmentName: assignmentConfig:
            lib.nameValuePair "keycloak_user_roles.${assignmentName}" {
              realm_id = "\${keycloak_realm.${assignmentConfig.realm}.id}";
              user_id = "\${keycloak_user.${assignmentConfig.user}.id}";
              role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") assignmentConfig.roles;
            }
          ) config.keycloak.terraform.userRoleAssignments
        ))

        # Generate user client role assignments if defined
        (lib.optionalAttrs (config.keycloak.terraform.userClientRoleAssignments or { } != { }) (
          lib.mapAttrs' (
            assignmentName: assignmentConfig:
            lib.nameValuePair "keycloak_user_roles.${assignmentName}" {
              realm_id = "\${keycloak_realm.${assignmentConfig.realm}.id}";
              user_id = "\${keycloak_user.${assignmentConfig.user}.id}";
              role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") assignmentConfig.roles;
            }
          ) config.keycloak.terraform.userClientRoleAssignments
        ))

        # Generate user sessions if defined (for testing/demo purposes)
        (lib.optionalAttrs (config.keycloak.terraform.userSessions or { } != { }) (
          lib.mapAttrs' (
            sessionName: sessionConfig:
            lib.nameValuePair "keycloak_user_session_note.${sessionName}" {
              realm_id = "\${keycloak_realm.${sessionConfig.realm}.id}";
              user_id = "\${keycloak_user.${sessionConfig.user}.id}";
              session_note = sessionConfig.sessionNote or { };
            }
          ) config.keycloak.terraform.userSessions
        ))

        # Generate required actions for users if defined
        (lib.optionalAttrs (config.keycloak.terraform.userRequiredActions or { } != { }) (
          lib.mapAttrs' (
            actionName: actionConfig:
            lib.nameValuePair "keycloak_required_action.${actionName}" {
              realm_id = "\${keycloak_realm.${actionConfig.realm}.id}";
              alias = actionConfig.alias;
              enabled = actionConfig.enabled or true;
              default_action = actionConfig.defaultAction or false;
              priority = actionConfig.priority or 10;
              name = actionConfig.name or actionName;
            }
          ) config.keycloak.terraform.userRequiredActions
        ))

        # Generate user consent configurations if defined
        (lib.optionalAttrs (config.keycloak.terraform.userConsents or { } != { }) (
          lib.mapAttrs' (
            consentName: consentConfig:
            lib.nameValuePair "keycloak_user_consent.${consentName}" {
              realm_id = "\${keycloak_realm.${consentConfig.realm}.id}";
              user_id = "\${keycloak_user.${consentConfig.user}.id}";
              client_id = "\${keycloak_openid_client.${consentConfig.client}.id}";
              granted_scopes = consentConfig.grantedScopes or [ ];
            }
          ) config.keycloak.terraform.userConsents
        ))
      ];
    };
  };
}
