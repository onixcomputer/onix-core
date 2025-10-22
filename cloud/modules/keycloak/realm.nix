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

  realmType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Realm name";
      };

      displayName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display name for the realm";
      };

      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the realm is enabled";
      };

      registrationAllowed = mkOption {
        type = types.bool;
        default = false;
        description = "Whether user registration is allowed";
      };

      registrationEmailAsUsername = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to use email as username during registration";
      };

      editUsernameAllowed = mkOption {
        type = types.bool;
        default = false;
        description = "Whether users can edit their username";
      };

      resetPasswordAllowed = mkOption {
        type = types.bool;
        default = true;
        description = "Whether password reset is allowed";
      };

      rememberMe = mkOption {
        type = types.bool;
        default = true;
        description = "Whether 'Remember Me' functionality is enabled";
      };

      verifyEmail = mkOption {
        type = types.bool;
        default = false;
        description = "Whether email verification is required";
      };

      loginWithEmailAllowed = mkOption {
        type = types.bool;
        default = true;
        description = "Whether login with email is allowed";
      };

      duplicateEmailsAllowed = mkOption {
        type = types.bool;
        default = false;
        description = "Whether duplicate emails are allowed";
      };

      sslRequired = mkOption {
        type = types.enum [
          "external"
          "none"
          "all"
        ];
        default = "external";
        description = "SSL requirement level";
      };

      loginTheme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Login theme for the realm";
      };

      adminTheme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Admin theme for the realm";
      };

      accountTheme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Account management theme for the realm";
      };

      emailTheme = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Email theme for the realm";
      };

      accessCodeLifespan = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Access code lifespan (e.g., '1m', '30s')";
      };

      accessTokenLifespan = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Access token lifespan (e.g., '5m', '1h')";
      };

      refreshTokenMaxReuse = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum number of times a refresh token can be reused";
      };

      bruteForceProtected = mkOption {
        type = types.bool;
        default = false;
        description = "Whether brute force protection is enabled";
      };

      permanentLockout = mkOption {
        type = types.bool;
        default = false;
        description = "Whether permanent lockout is enabled";
      };

      maxFailureWaitSeconds = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum wait time in seconds after failed login attempts";
      };

      minimumQuickLoginWaitSeconds = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Minimum wait time for quick login attempts";
      };

      waitIncrementSeconds = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Wait increment in seconds for failed attempts";
      };

      quickLoginCheckMilliSeconds = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Quick login check interval in milliseconds";
      };

      maxDeltaTimeSeconds = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum delta time in seconds";
      };

      failureFactor = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Failure factor for brute force protection";
      };

      attributes = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Custom attributes for the realm";
      };

      internationalizationEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether internationalization is enabled";
      };

      supportedLocales = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of supported locales";
        example = [
          "en"
          "de"
          "fr"
        ];
      };

      defaultLocale = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default locale for the realm";
        example = "en";
      };
    };
  };
in
{
  options.services.keycloak = {
    realms = mkOption {
      type = types.attrsOf realmType;
      default = { };
      description = "Keycloak realms to manage";
      example = {
        "my-realm" = {
          name = "my-realm";
          displayName = "My Application Realm";
          enabled = true;
          registrationAllowed = true;
          loginTheme = "base";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource.keycloak_realm = mapAttrs' (
      realmId: realmCfg:
      nameValuePair realmId {
        realm = realmCfg.name;
        inherit (realmCfg) enabled;
        display_name = realmCfg.displayName;

        registration_allowed = realmCfg.registrationAllowed;
        registration_email_as_username = realmCfg.registrationEmailAsUsername;
        edit_username_allowed = realmCfg.editUsernameAllowed;
        reset_password_allowed = realmCfg.resetPasswordAllowed;
        remember_me = realmCfg.rememberMe;
        verify_email = realmCfg.verifyEmail;
        login_with_email_allowed = realmCfg.loginWithEmailAllowed;
        duplicate_emails_allowed = realmCfg.duplicateEmailsAllowed;
        ssl_required = realmCfg.sslRequired;

        login_theme = realmCfg.loginTheme;
        admin_theme = realmCfg.adminTheme;
        account_theme = realmCfg.accountTheme;
        email_theme = realmCfg.emailTheme;

        access_code_lifespan = realmCfg.accessCodeLifespan;
        access_token_lifespan = realmCfg.accessTokenLifespan;
        refresh_token_max_reuse = realmCfg.refreshTokenMaxReuse;

        brute_force_protected = realmCfg.bruteForceProtected;
        permanent_lockout = realmCfg.permanentLockout;
        max_failure_wait_seconds = realmCfg.maxFailureWaitSeconds;
        minimum_quick_login_wait_seconds = realmCfg.minimumQuickLoginWaitSeconds;
        wait_increment_seconds = realmCfg.waitIncrementSeconds;
        quick_login_check_milli_seconds = realmCfg.quickLoginCheckMilliSeconds;
        max_delta_time_seconds = realmCfg.maxDeltaTimeSeconds;
        failure_factor = realmCfg.failureFactor;

        inherit (realmCfg) attributes;

        internationalization = mkIf realmCfg.internationalizationEnabled {
          supported_locales = realmCfg.supportedLocales;
          default_locale = realmCfg.defaultLocale;
        };
      }
    ) cfg.realms;
  };
}
