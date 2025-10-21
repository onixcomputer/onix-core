# Keycloak Realms Module
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

  # Comprehensive realm configuration type
  realmType = types.submodule (
    { name, ... }:
    {
      options = {
        realm = mkOption {
          type = types.str;
          default = name;
          description = "Realm name (defaults to attribute name)";
        };

        enabled = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the realm is enabled";
        };

        displayName = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Display name for the realm";
        };

        displayNameHtml = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "HTML display name for the realm";
        };

        # Authentication settings
        loginWithEmailAllowed = mkOption {
          type = types.bool;
          default = false;
          description = "Whether login with email is allowed";
        };

        duplicateEmailsAllowed = mkOption {
          type = types.bool;
          default = false;
          description = "Whether duplicate emails are allowed";
        };

        verifyEmail = mkOption {
          type = types.bool;
          default = false;
          description = "Whether email verification is required";
        };

        # Registration settings
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
          default = false;
          description = "Whether password reset is allowed";
        };

        rememberMe = mkOption {
          type = types.bool;
          default = false;
          description = "Whether 'Remember Me' functionality is enabled";
        };

        # Security settings
        sslRequired = mkOption {
          type = types.enum [
            "external"
            "none"
            "all"
          ];
          default = "external";
          description = "SSL requirement level";
        };

        passwordPolicy = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Password policy for the realm.
            Example: "length(8) and digits(2) and lowerCase(2) and upperCase(2) and specialChars(2) and notUsername(undefined) and notEmail(undefined)"
          '';
          example = "length(8) and digits(2) and lowerCase(2) and upperCase(2)";
        };

        # Session settings
        ssoSessionIdleTimeout = mkOption {
          type = types.str;
          default = "30m";
          description = "SSO session idle timeout";
        };

        ssoSessionMaxLifespan = mkOption {
          type = types.str;
          default = "10h";
          description = "SSO session maximum lifespan";
        };

        offlineSessionIdleTimeout = mkOption {
          type = types.str;
          default = "720h";
          description = "Offline session idle timeout";
        };

        offlineSessionMaxLifespan = mkOption {
          type = types.str;
          default = "8760h";
          description = "Offline session maximum lifespan";
        };

        accessCodeLifespan = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access code lifespan";
        };

        accessTokenLifespan = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Access token lifespan";
        };

        refreshTokenMaxReuse = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum number of times a refresh token can be reused";
        };

        # Theme settings
        loginTheme = mkOption {
          type = types.nullOr types.str;
          default = "base";
          description = "Login theme for the realm";
        };

        adminTheme = mkOption {
          type = types.nullOr types.str;
          default = "base";
          description = "Admin theme for the realm";
        };

        accountTheme = mkOption {
          type = types.nullOr types.str;
          default = "base";
          description = "Account management theme for the realm";
        };

        emailTheme = mkOption {
          type = types.nullOr types.str;
          default = "base";
          description = "Email theme for the realm";
        };

        # Brute force protection
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

        # Internationalization
        internationalization = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                enabled = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether internationalization is enabled";
                };

                supportedLocales = mkOption {
                  type = types.listOf types.str;
                  default = [ "en" ];
                  description = "List of supported locales";
                  example = [
                    "en"
                    "de"
                    "fr"
                    "es"
                  ];
                };

                defaultLocale = mkOption {
                  type = types.str;
                  default = "en";
                  description = "Default locale for the realm";
                };
              };
            }
          );
          default = null;
          description = "Internationalization settings";
        };

        # Custom attributes
        attributes = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Custom attributes for the realm";
        };

        # SMTP configuration
        smtpServer = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                host = mkOption {
                  type = types.str;
                  description = "SMTP server host";
                };

                port = mkOption {
                  type = types.int;
                  default = 587;
                  description = "SMTP server port";
                };

                from = mkOption {
                  type = types.str;
                  description = "From email address";
                };

                fromDisplayName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "From display name";
                };

                replyTo = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Reply-to email address";
                };

                replyToDisplayName = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Reply-to display name";
                };

                envelopeFrom = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Envelope from address";
                };

                starttls = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether to use STARTTLS";
                };

                ssl = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether to use SSL";
                };

                auth = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Whether authentication is required";
                };

                user = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "SMTP username";
                };

                password = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "SMTP password (should reference a variable)";
                };
              };
            }
          );
          default = null;
          description = "SMTP server configuration for email sending";
        };

        # OAuth 2.0 settings
        oauth2DeviceCodeLifespan = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OAuth 2.0 device code lifespan";
        };

        oauth2DevicePollingInterval = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "OAuth 2.0 device polling interval in seconds";
        };

        # WebAuthn settings
        webAuthnPolicy = mkOption {
          type = types.nullOr (
            types.submodule {
              options = {
                relyingPartyEntityName = mkOption {
                  type = types.str;
                  description = "Relying party entity name";
                };

                relyingPartyId = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Relying party ID";
                };

                signature_algorithms = mkOption {
                  type = types.listOf types.str;
                  default = [
                    "ES256"
                    "RS256"
                  ];
                  description = "Allowed signature algorithms";
                };

                attestationConveyancePreference = mkOption {
                  type = types.enum [
                    "none"
                    "indirect"
                    "direct"
                  ];
                  default = "none";
                  description = "Attestation conveyance preference";
                };

                authenticatorAttachment = mkOption {
                  type = types.enum [
                    "platform"
                    "cross-platform"
                  ];
                  default = "cross-platform";
                  description = "Authenticator attachment";
                };

                requireResidentKey = mkOption {
                  type = types.enum [
                    "Yes"
                    "No"
                  ];
                  default = "No";
                  description = "Whether resident key is required";
                };

                userVerificationRequirement = mkOption {
                  type = types.enum [
                    "required"
                    "preferred"
                    "discouraged"
                  ];
                  default = "preferred";
                  description = "User verification requirement";
                };

                createTimeout = mkOption {
                  type = types.int;
                  default = 0;
                  description = "Create timeout in seconds";
                };

                avoidSameAuthenticatorRegister = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether to avoid same authenticator registration";
                };

                acceptableAaguids = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "List of acceptable AAGUIDs";
                };
              };
            }
          );
          default = null;
          description = "WebAuthn policy configuration";
        };
      };
    }
  );

in
{
  options.services.keycloak = {
    realms = mkOption {
      type = types.attrsOf realmType;
      default = { };
      description = "Keycloak realms to manage";
      example = {
        "company" = {
          realm = "company";
          displayName = "Company Realm";
          enabled = true;
          registrationAllowed = true;
          loginWithEmailAllowed = true;
          verifyEmail = true;
          resetPasswordAllowed = true;
          rememberMe = true;
          bruteForceProtected = true;
          failureFactor = 5;
          maxFailureWaitSeconds = 900;
          internationalization = {
            enabled = true;
            supportedLocales = [
              "en"
              "de"
              "fr"
            ];
            defaultLocale = "en";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    resource.keycloak_realm = mapAttrs' (
      realmName: realmCfg:
      nameValuePair "${cfg.settings.resourcePrefix}${realmName}" (
        filterAttrs (_: v: v != null) {
          inherit (realmCfg) realm enabled;
          display_name = realmCfg.displayName;
          display_name_html = realmCfg.displayNameHtml;

          # Authentication settings
          login_with_email_allowed = realmCfg.loginWithEmailAllowed;
          duplicate_emails_allowed = realmCfg.duplicateEmailsAllowed;
          verify_email = realmCfg.verifyEmail;

          # Registration settings
          registration_allowed = realmCfg.registrationAllowed;
          registration_email_as_username = realmCfg.registrationEmailAsUsername;
          edit_username_allowed = realmCfg.editUsernameAllowed;
          reset_password_allowed = realmCfg.resetPasswordAllowed;
          remember_me = realmCfg.rememberMe;

          # Security settings
          ssl_required = realmCfg.sslRequired;
          password_policy = realmCfg.passwordPolicy;

          # Session settings
          sso_session_idle_timeout = realmCfg.ssoSessionIdleTimeout;
          sso_session_max_lifespan = realmCfg.ssoSessionMaxLifespan;
          offline_session_idle_timeout = realmCfg.offlineSessionIdleTimeout;
          offline_session_max_lifespan = realmCfg.offlineSessionMaxLifespan;
          access_code_lifespan = realmCfg.accessCodeLifespan;
          access_token_lifespan = realmCfg.accessTokenLifespan;
          refresh_token_max_reuse = realmCfg.refreshTokenMaxReuse;

          # Theme settings
          login_theme = realmCfg.loginTheme;
          admin_theme = realmCfg.adminTheme;
          account_theme = realmCfg.accountTheme;
          email_theme = realmCfg.emailTheme;

          # Brute force protection
          brute_force_protected = realmCfg.bruteForceProtected;
          permanent_lockout = realmCfg.permanentLockout;
          max_failure_wait_seconds = realmCfg.maxFailureWaitSeconds;
          minimum_quick_login_wait_seconds = realmCfg.minimumQuickLoginWaitSeconds;
          wait_increment_seconds = realmCfg.waitIncrementSeconds;
          quick_login_check_milli_seconds = realmCfg.quickLoginCheckMilliSeconds;
          max_delta_time_seconds = realmCfg.maxDeltaTimeSeconds;
          failure_factor = realmCfg.failureFactor;

          # Custom attributes
          inherit (realmCfg) attributes;

          # OAuth 2.0 settings
          oauth2_device_code_lifespan = realmCfg.oauth2DeviceCodeLifespan;
          oauth2_device_polling_interval = realmCfg.oauth2DevicePollingInterval;

          # Internationalization
          internationalization = lib.mkIf (realmCfg.internationalization != null) {
            supported_locales = realmCfg.internationalization.supportedLocales;
            default_locale = realmCfg.internationalization.defaultLocale;
          };

          # SMTP server configuration
          smtp_server = lib.mkIf (realmCfg.smtpServer != null) (
            filterAttrs (_: v: v != null) {
              inherit (realmCfg.smtpServer) host from;
              port = toString realmCfg.smtpServer.port;
              from_display_name = realmCfg.smtpServer.fromDisplayName;
              reply_to = realmCfg.smtpServer.replyTo;
              reply_to_display_name = realmCfg.smtpServer.replyToDisplayName;
              envelope_from = realmCfg.smtpServer.envelopeFrom;
              inherit (realmCfg.smtpServer)
                starttls
                ssl
                auth
                user
                password
                ;
            }
          );

          # WebAuthn policy
          web_authn_policy = lib.mkIf (realmCfg.webAuthnPolicy != null) (
            filterAttrs (_: v: v != null) {
              relying_party_entity_name = realmCfg.webAuthnPolicy.relyingPartyEntityName;
              relying_party_id = realmCfg.webAuthnPolicy.relyingPartyId;
              inherit (realmCfg.webAuthnPolicy) signature_algorithms;
              attestation_conveyance_preference = realmCfg.webAuthnPolicy.attestationConveyancePreference;
              authenticator_attachment = realmCfg.webAuthnPolicy.authenticatorAttachment;
              require_resident_key = realmCfg.webAuthnPolicy.requireResidentKey;
              user_verification_requirement = realmCfg.webAuthnPolicy.userVerificationRequirement;
              create_timeout = realmCfg.webAuthnPolicy.createTimeout;
              avoid_same_authenticator_register = realmCfg.webAuthnPolicy.avoidSameAuthenticatorRegister;
              acceptable_aaguids = realmCfg.webAuthnPolicy.acceptableAaguids;
            }
          );
        }
      )
    ) cfg.realms;
  };
}
