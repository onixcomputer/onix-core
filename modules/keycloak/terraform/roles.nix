{ lib, config, ... }:

{
  # Keycloak Roles Management Module
  # This module handles the creation and configuration of Keycloak roles

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Generate role resources from configuration
      resources = lib.mkMerge [
        (lib.mapAttrs' (
          roleName: roleConfig:
          lib.nameValuePair "keycloak_role.${roleName}" (
            {
              realm_id = "\${keycloak_realm.${roleConfig.realm}.id}";
              name = roleName;
              description = roleConfig.description or "Role ${roleName}";

              # Composite role configuration
              composite_roles = lib.mkIf (roleConfig.compositeRoles or [ ] != [ ]) (
                map (compositeRoleName: "\${keycloak_role.${compositeRoleName}.id}") roleConfig.compositeRoles
              );

              # Role attributes
              attributes = lib.mkIf (roleConfig.attributes or { } != { }) roleConfig.attributes;
            }
            # Add client_id for client roles
            // lib.optionalAttrs (roleConfig.client or null != null) {
              client_id = "\${keycloak_openid_client.${roleConfig.client}.id}";
            }
          )
        ) config.keycloak.terraform.roles)

        # Generate client-specific roles if defined
        (lib.optionalAttrs (config.keycloak.terraform.clientRoles or { } != { }) (
          lib.mapAttrs' (
            clientRoleName: clientRoleConfig:
            lib.nameValuePair "keycloak_role.${clientRoleName}" {
              realm_id = "\${keycloak_realm.${clientRoleConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${clientRoleConfig.client}.id}";
              name = clientRoleName;
              description = clientRoleConfig.description or "Client role ${clientRoleName}";

              # Composite role configuration
              composite_roles = lib.mkIf (clientRoleConfig.compositeRoles or [ ] != [ ]) (
                map (compositeRoleName: "\${keycloak_role.${compositeRoleName}.id}") clientRoleConfig.compositeRoles
              );

              # Role attributes
              attributes = lib.mkIf (clientRoleConfig.attributes or { } != { }) clientRoleConfig.attributes;
            }
          ) config.keycloak.terraform.clientRoles
        ))

        # Generate default client scopes for roles if defined
        (lib.optionalAttrs (config.keycloak.terraform.roleDefaultClientScopes or { } != { }) (
          lib.mapAttrs' (
            scopeName: scopeConfig:
            lib.nameValuePair "keycloak_openid_client_default_scopes.${scopeName}" {
              realm_id = "\${keycloak_realm.${scopeConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${scopeConfig.client}.id}";
              default_scopes = map (roleName: "\${keycloak_role.${roleName}.name}") scopeConfig.roles;
            }
          ) config.keycloak.terraform.roleDefaultClientScopes
        ))

        # Generate role policies if defined (for authorization)
        (lib.optionalAttrs (config.keycloak.terraform.rolePolicies or { } != { }) (
          lib.mapAttrs' (
            policyName: policyConfig:
            lib.nameValuePair "keycloak_role_policy.${policyName}" {
              realm_id = "\${keycloak_realm.${policyConfig.realm}.id}";
              resource_server_id = "\${keycloak_openid_client.${policyConfig.resourceServer}.resource_server_id}";
              name = policyName;

              # Policy configuration
              description = policyConfig.description or "Role policy for ${policyName}";
              decision_strategy = policyConfig.decisionStrategy or "UNANIMOUS";
              logic = policyConfig.logic or "POSITIVE";

              # Roles included in the policy
              roles = map (roleName: {
                id = "\${keycloak_role.${roleName}.id}";
                required = policyConfig.required or false;
              }) policyConfig.roles;
            }
          ) config.keycloak.terraform.rolePolicies
        ))

        # Generate scope-based permissions for roles if defined
        (lib.optionalAttrs (config.keycloak.terraform.roleScopePermissions or { } != { }) (
          lib.mapAttrs' (
            permissionName: permissionConfig:
            lib.nameValuePair "keycloak_openid_client_scope_based_permission.${permissionName}" {
              realm_id = "\${keycloak_realm.${permissionConfig.realm}.id}";
              resource_server_id = "\${keycloak_openid_client.${permissionConfig.resourceServer}.resource_server_id}";
              name = permissionName;

              # Permission configuration
              description = permissionConfig.description or "Scope permission for ${permissionName}";
              decision_strategy = permissionConfig.decisionStrategy or "UNANIMOUS";

              # Scopes and policies
              scopes = permissionConfig.scopes or [ ];
              policies = map (policyName: "\${keycloak_role_policy.${policyName}.id}") permissionConfig.policies;
            }
          ) config.keycloak.terraform.roleScopePermissions
        ))

        # Generate client role mappers if defined
        (lib.optionalAttrs (config.keycloak.terraform.clientRoleMappers or { } != { }) (
          lib.mapAttrs' (
            mapperName: mapperConfig:
            lib.nameValuePair "keycloak_openid_client_role_protocol_mapper.${mapperName}" {
              realm_id = "\${keycloak_realm.${mapperConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${mapperConfig.client}.id}";
              name = mapperName;

              # Mapper configuration
              claim_name = mapperConfig.claimName or "roles";
              claim_value_type = mapperConfig.claimValueType or "String";

              # Token inclusion
              add_to_id_token = mapperConfig.addToIdToken or true;
              add_to_access_token = mapperConfig.addToAccessToken or true;
              add_to_userinfo = mapperConfig.addToUserinfo or false;

              # Role configuration
              multivalued = mapperConfig.multivalued or true;
              client_role_prefix = mapperConfig.clientRolePrefix or "";
              client_id_for_role_mappings = lib.mkIf (
                mapperConfig.clientIdForRoleMappings or null != null
              ) "\${keycloak_openid_client.${mapperConfig.clientIdForRoleMappings}.id}";
            }
          ) config.keycloak.terraform.clientRoleMappers
        ))

        # Generate audience protocol mappers for client roles if defined
        (lib.optionalAttrs (config.keycloak.terraform.roleAudienceMappers or { } != { }) (
          lib.mapAttrs' (
            mapperName: mapperConfig:
            lib.nameValuePair "keycloak_openid_audience_protocol_mapper.${mapperName}" {
              realm_id = "\${keycloak_realm.${mapperConfig.realm}.id}";
              client_id = "\${keycloak_openid_client.${mapperConfig.client}.id}";
              name = mapperName;

              # Audience configuration
              included_client_audience = lib.mkIf (
                mapperConfig.includedClientAudience or null != null
              ) "\${keycloak_openid_client.${mapperConfig.includedClientAudience}.client_id}";
              included_custom_audience = mapperConfig.includedCustomAudience or "";

              # Token inclusion
              add_to_id_token = mapperConfig.addToIdToken or false;
              add_to_access_token = mapperConfig.addToAccessToken or true;
            }
          ) config.keycloak.terraform.roleAudienceMappers
        ))
      ];
    };
  };
}
