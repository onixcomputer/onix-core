{ lib, config, ... }:

{
  # Keycloak Groups Management Module
  # This module handles the creation and configuration of Keycloak groups

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Generate group resources from configuration
      resources = lib.mkMerge [
        (lib.mapAttrs' (
          groupName: groupConfig:
          lib.nameValuePair "keycloak_group.${groupName}" {
            realm_id = "\${keycloak_realm.${groupConfig.realm}.id}";
            name = groupName;

            # Parent group configuration
            parent_id = lib.mkIf (
              groupConfig.parentGroup or null != null
            ) "\${keycloak_group.${groupConfig.parentGroup}.id}";

            # Group attributes
            attributes = lib.mkIf (groupConfig.attributes or { } != { }) groupConfig.attributes;
          }
        ) config.keycloak.terraform.groups)

        # Generate group role mappings if defined
        (lib.optionalAttrs (config.keycloak.terraform.groupRoleMappings or { } != { }) (
          lib.mapAttrs' (
            mappingName: mappingConfig:
            lib.nameValuePair "keycloak_group_roles.${mappingName}" {
              realm_id = "\${keycloak_realm.${mappingConfig.realm}.id}";
              group_id = "\${keycloak_group.${mappingConfig.group}.id}";
              role_ids = map (roleName: "\${keycloak_role.${roleName}.id}") mappingConfig.roles;
            }
          ) config.keycloak.terraform.groupRoleMappings
        ))

        # Generate group client role mappings if defined
        (lib.optionalAttrs (config.keycloak.terraform.groupClientRoleMappings or { } != { }) (
          lib.mapAttrs' (
            mappingName: mappingConfig:
            lib.nameValuePair "keycloak_group_roles.${mappingName}" {
              realm_id = "\${keycloak_realm.${mappingConfig.realm}.id}";
              group_id = "\${keycloak_group.${mappingConfig.group}.id}";
              role_ids = map (
                roleName:
                if mappingConfig.client or null != null then
                  "\${keycloak_role.${roleName}.id}" # Client role
                else
                  "\${keycloak_role.${roleName}.id}" # Realm role
              ) mappingConfig.roles;
            }
          ) config.keycloak.terraform.groupClientRoleMappings
        ))

        # Generate group permissions if defined
        (lib.optionalAttrs (config.keycloak.terraform.groupPermissions or { } != { }) (
          lib.mapAttrs' (
            permissionName: permissionConfig:
            lib.nameValuePair "keycloak_group_permissions.${permissionName}" {
              realm_id = "\${keycloak_realm.${permissionConfig.realm}.id}";
              group_id = "\${keycloak_group.${permissionConfig.group}.id}";

              # Permission configuration
              enabled = permissionConfig.enabled or true;

              # Manage permissions
              manage_enabled = permissionConfig.manageEnabled or false;
              manage_policy = permissionConfig.managePolicy or "";
              manage_scope = permissionConfig.manageScope or "";

              # Membership permissions
              membership_enabled = permissionConfig.membershipEnabled or false;
              membership_policy = permissionConfig.membershipPolicy or "";
              membership_scope = permissionConfig.membershipScope or "";

              # View permissions
              view_enabled = permissionConfig.viewEnabled or true;
              view_policy = permissionConfig.viewPolicy or "";
              view_scope = permissionConfig.viewScope or "";
            }
          ) config.keycloak.terraform.groupPermissions
        ))

        # Generate group policies if defined (for authorization)
        (lib.optionalAttrs (config.keycloak.terraform.groupPolicies or { } != { }) (
          lib.mapAttrs' (
            policyName: policyConfig:
            lib.nameValuePair "keycloak_group_policy.${policyName}" {
              realm_id = "\${keycloak_realm.${policyConfig.realm}.id}";
              resource_server_id = "\${keycloak_openid_client.${policyConfig.resourceServer}.resource_server_id}";
              name = policyName;

              # Policy configuration
              description = policyConfig.description or "Group policy for ${policyName}";
              decision_strategy = policyConfig.decisionStrategy or "UNANIMOUS";
              logic = policyConfig.logic or "POSITIVE";

              # Groups included in the policy
              groups = map (groupName: {
                id = "\${keycloak_group.${groupName}.id}";
                extend_children = policyConfig.extendChildren or false;
              }) policyConfig.groups;
            }
          ) config.keycloak.terraform.groupPolicies
        ))

        # Generate group mappers if defined (for LDAP federation)
        (lib.optionalAttrs (config.keycloak.terraform.groupMappers or { } != { }) (
          lib.mapAttrs' (
            mapperName: mapperConfig:
            lib.nameValuePair "keycloak_ldap_group_mapper.${mapperName}" {
              realm_id = "\${keycloak_realm.${mapperConfig.realm}.id}";
              ldap_user_federation_id = "\${keycloak_ldap_user_federation.${mapperConfig.ldapFederation}.id}";
              name = mapperName;

              # LDAP configuration
              ldap_groups_dn = mapperConfig.ldapGroupsDn;
              group_name_ldap_attribute = mapperConfig.groupNameLdapAttribute or "cn";
              group_object_classes = mapperConfig.groupObjectClasses or [ "groupOfNames" ];
              preserve_group_inheritance = mapperConfig.preserveGroupInheritance or true;
              ignore_missing_groups = mapperConfig.ignoreMissingGroups or false;
              membership_ldap_attribute = mapperConfig.membershipLdapAttribute or "member";
              membership_attribute_type = mapperConfig.membershipAttributeType or "DN";
              membership_user_ldap_attribute = mapperConfig.membershipUserLdapAttribute or "uid";

              # Keycloak group configuration
              groups_path = mapperConfig.groupsPath or "/";
              mode = mapperConfig.mode or "READ_ONLY";
              user_roles_retrieve_strategy =
                mapperConfig.userRolesRetrieveStrategy or "LOAD_GROUPS_BY_MEMBER_ATTRIBUTE";
              mapped_group_attributes = mapperConfig.mappedGroupAttributes or [ ];
              drop_non_existing_groups_during_sync = mapperConfig.dropNonExistingGroupsDuringSync or false;
            }
          ) config.keycloak.terraform.groupMappers
        ))
      ];
    };
  };
}
