# Keycloak Validation Module
# Provides cross-resource validation and dependency checking
{ config, lib, ... }:

let
  inherit (lib)
    mkIf
    elem
    attrNames
    attrValues
    mapAttrsToList
    flatten
    unique
    concatStringsSep
    length
    filter
    ;

  cfg = config.services.keycloak;

  # Helper functions for validation
  validators = {
    # Check if a realm reference is valid
    isValidRealmRef = realmName: cfg.realms ? ${realmName};

    # Check if a client reference is valid
    isValidClientRef = clientName: cfg.clients ? ${clientName};

    # Check if a group reference is valid
    isValidGroupRef = groupName: cfg.groups ? ${groupName};

    # Check if a role reference is valid (either realm or client role)
    isValidRoleRef = roleName: cfg.roles ? ${roleName};

    # Check if a client scope reference is valid
    isValidClientScopeRef = scopeName: cfg.clientScopes ? ${scopeName};

    # Get all realm names referenced in the configuration
    getReferencedRealms =
      let
        clientRealms = mapAttrsToList (_: client: client.realmId) cfg.clients;
        userRealms = mapAttrsToList (_: user: user.realmId) cfg.users;
        groupRealms = mapAttrsToList (_: group: group.realmId) cfg.groups;
        roleRealms = mapAttrsToList (_: role: role.realmId) cfg.roles;
        scopeRealms = mapAttrsToList (_: scope: scope.realmId) cfg.clientScopes;
      in
      unique (clientRealms ++ userRealms ++ groupRealms ++ roleRealms ++ scopeRealms);

    # Get all client names referenced in roles, users, and groups
    getReferencedClients =
      let
        roleClients = mapAttrsToList (
          _: role: if role.clientId != null then [ role.clientId ] else [ ]
        ) cfg.roles;
        userClientRoles = mapAttrsToList (_: user: attrNames user.clientRoles) cfg.users;
        groupClientRoles = mapAttrsToList (_: group: attrNames group.clientRoles) cfg.groups;
      in
      unique (flatten (roleClients ++ userClientRoles ++ groupClientRoles));

    # Get all group names referenced in users
    getReferencedGroups = unique (flatten (mapAttrsToList (_: user: user.groups) cfg.users));

    # Get all role names referenced in users and groups
    getReferencedRoles =
      let
        userRealmRoles = flatten (mapAttrsToList (_: user: user.realmRoles) cfg.users);
        userClientRoles = flatten (
          mapAttrsToList (_: user: flatten (attrValues user.clientRoles)) cfg.users
        );
        groupRealmRoles = flatten (mapAttrsToList (_: group: group.realmRoles) cfg.groups);
        groupClientRoles = flatten (
          mapAttrsToList (_: group: flatten (attrValues group.clientRoles)) cfg.groups
        );
      in
      unique (userRealmRoles ++ userClientRoles ++ groupRealmRoles ++ groupClientRoles);

    # Get all client scope names referenced in clients
    getReferencedClientScopes =
      let
        defaultScopes = flatten (mapAttrsToList (_: client: client.defaultClientScopes) cfg.clients);
        optionalScopes = flatten (mapAttrsToList (_: client: client.optionalClientScopes) cfg.clients);
      in
      unique (defaultScopes ++ optionalScopes);
  };

  # Individual validation functions
  validationChecks = {
    # Validate realm references
    realmReferences =
      let
        referencedRealms = validators.getReferencedRealms;
        invalidRealms = filter (realm: !validators.isValidRealmRef realm) referencedRealms;
      in
      {
        assertion = invalidRealms == [ ];
        message = ''
          Invalid realm references found: ${concatStringsSep ", " invalidRealms}

          Available realms: ${concatStringsSep ", " (attrNames cfg.realms)}

          Make sure all referenced realms are defined in services.keycloak.realms.
        '';
      };

    # Validate client references
    clientReferences =
      let
        referencedClients = validators.getReferencedClients;
        invalidClients = filter (client: !validators.isValidClientRef client) referencedClients;
      in
      {
        assertion = invalidClients == [ ];
        message = ''
          Invalid client references found: ${concatStringsSep ", " invalidClients}

          Available clients: ${concatStringsSep ", " (attrNames cfg.clients)}

          Make sure all referenced clients are defined in services.keycloak.clients.
        '';
      };

    # Validate group references
    groupReferences =
      let
        referencedGroups = validators.getReferencedGroups;
        invalidGroups = filter (group: !validators.isValidGroupRef group) referencedGroups;
      in
      {
        assertion = invalidGroups == [ ];
        message = ''
          Invalid group references found: ${concatStringsSep ", " invalidGroups}

          Available groups: ${concatStringsSep ", " (attrNames cfg.groups)}

          Make sure all referenced groups are defined in services.keycloak.groups.
        '';
      };

    # Validate client scope references
    clientScopeReferences =
      let
        referencedScopes = validators.getReferencedClientScopes;
        invalidScopes = filter (scope: !validators.isValidClientScopeRef scope) referencedScopes;
      in
      {
        assertion = invalidScopes == [ ];
        message = ''
          Invalid client scope references found: ${concatStringsSep ", " invalidScopes}

          Available client scopes: ${concatStringsSep ", " (attrNames cfg.clientScopes)}

          Make sure all referenced client scopes are defined in services.keycloak.clientScopes.
        '';
      };

    # Validate group hierarchy (no circular dependencies)
    groupHierarchy =
      let
        # Build dependency graph for groups

        # Check for circular dependencies
        hasCircularDependency =
          groupName:
          let
            checkCircular =
              current: path:
              if elem current path then
                true
              else if !(cfg.groups ? ${current}) then
                false
              else
                let
                  parent = cfg.groups.${current}.parentGroup;
                in
                if parent == null then false else checkCircular parent (path ++ [ current ]);
          in
          checkCircular groupName [ ];

        circularGroups = filter hasCircularDependency (attrNames cfg.groups);
      in
      {
        assertion = circularGroups == [ ];
        message = ''
          Circular group dependencies detected: ${concatStringsSep ", " circularGroups}

          Group parent relationships must form a tree (no cycles).
          Check the parentGroup settings in your group configurations.
        '';
      };

    # Validate that parent groups exist
    parentGroupExists =
      let
        invalidParents = flatten (
          mapAttrsToList (
            groupName: group:
            if group.parentGroup != null && !(cfg.groups ? ${group.parentGroup}) then
              [ "${groupName} -> ${group.parentGroup}" ]
            else
              [ ]
          ) cfg.groups
        );
      in
      {
        assertion = invalidParents == [ ];
        message = ''
          Invalid parent group references: ${concatStringsSep ", " invalidParents}

          Make sure all parent groups are defined in services.keycloak.groups.
        '';
      };

    # Validate unique usernames within realms
    uniqueUsernames =
      let
        # Group users by realm
        usersByRealm = builtins.groupBy (user: user.realmId) (attrValues cfg.users);

        # Check for duplicate usernames within each realm
        duplicatesInRealm =
          _realmId: users:
          let
            usernames = map (user: user.username) users;
            uniqueUsernames = unique usernames;
          in
          length usernames != length uniqueUsernames;

        realmsWithDuplicates = filter (realmId: duplicatesInRealm realmId usersByRealm.${realmId}) (
          attrNames usersByRealm
        );
      in
      {
        assertion = realmsWithDuplicates == [ ];
        message = ''
          Duplicate usernames found in realms: ${concatStringsSep ", " realmsWithDuplicates}

          Usernames must be unique within each realm.
        '';
      };

    # Validate unique group names within realms
    uniqueGroupNames =
      let
        # Group groups by realm
        groupsByRealm = builtins.groupBy (group: group.realmId) (attrValues cfg.groups);

        # Check for duplicate group names within each realm
        duplicatesInRealm =
          _realmId: groups:
          let
            groupNames = map (group: group.name) groups;
            uniqueGroupNames = unique groupNames;
          in
          length groupNames != length uniqueGroupNames;

        realmsWithDuplicates = filter (realmId: duplicatesInRealm realmId groupsByRealm.${realmId}) (
          attrNames groupsByRealm
        );
      in
      {
        assertion = realmsWithDuplicates == [ ];
        message = ''
          Duplicate group names found in realms: ${concatStringsSep ", " realmsWithDuplicates}

          Group names must be unique within each realm.
        '';
      };

    # Validate unique client IDs within realms
    uniqueClientIds =
      let
        # Group clients by realm
        clientsByRealm = builtins.groupBy (client: client.realmId) (attrValues cfg.clients);

        # Check for duplicate client IDs within each realm
        duplicatesInRealm =
          _realmId: clients:
          let
            clientIds = map (client: client.clientId) clients;
            uniqueClientIds = unique clientIds;
          in
          length clientIds != length uniqueClientIds;

        realmsWithDuplicates = filter (realmId: duplicatesInRealm realmId clientsByRealm.${realmId}) (
          attrNames clientsByRealm
        );
      in
      {
        assertion = realmsWithDuplicates == [ ];
        message = ''
          Duplicate client IDs found in realms: ${concatStringsSep ", " realmsWithDuplicates}

          Client IDs must be unique within each realm.
        '';
      };

    # Validate PKCE configuration for public clients
    pkceForPublicClients =
      let
        publicClientsWithoutPkce = mapAttrsToList (
          clientName: client:
          if client.accessType == "PUBLIC" && client.pkceCodeChallengeMethod == null then clientName else null
        ) cfg.clients;

        invalidClients = filter (x: x != null) publicClientsWithoutPkce;
      in
      {
        assertion = !cfg.settings.validation.strictMode || invalidClients == [ ];
        message = ''
          Public clients without PKCE found: ${concatStringsSep ", " invalidClients}

          In strict mode, public clients should use PKCE for security.
          Set pkceCodeChallengeMethod = "S256" for these clients.
        '';
      };
  };

  # Combine all validation checks
  allValidations = attrValues validationChecks;

in
{
  config = mkIf (cfg.enable && cfg.settings.validation.enableCrossResourceValidation) {
    # Apply all validation assertions
    assertions = allValidations;

    # Add validation metadata to terraform output
    output.keycloak_validation_summary = mkIf (cfg.outputs ? keycloak_validation_summary) {
      value = builtins.toJSON {
        validationEnabled = cfg.settings.validation.enableCrossResourceValidation;
        inherit (cfg.settings.validation) strictMode;
        referencedRealms = validators.getReferencedRealms;
        referencedClients = validators.getReferencedClients;
        referencedGroups = validators.getReferencedGroups;
        referencedClientScopes = validators.getReferencedClientScopes;
        totalResources = {
          realms = length (attrNames cfg.realms);
          clients = length (attrNames cfg.clients);
          users = length (attrNames cfg.users);
          groups = length (attrNames cfg.groups);
          roles = length (attrNames cfg.roles);
          clientScopes = length (attrNames cfg.clientScopes);
        };
      };
      description = "Keycloak configuration validation summary";
    };
  };
}
