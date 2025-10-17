{ lib, config, ... }:

{
  # Keycloak Realms Management Module
  # This module handles the creation and configuration of Keycloak realms

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Generate realm resources from configuration
      resources = lib.mkMerge [
        (lib.mapAttrs' (
          realmName: realmConfig:
          lib.nameValuePair "keycloak_realm.${realmName}" {
            realm = realmName;
            enabled = realmConfig.enabled or true;
            display_name = realmConfig.displayName or realmName;
            display_name_html =
              realmConfig.displayNameHtml or "<h1>${realmConfig.displayName or realmName}</h1>";

            # Login settings
            login_with_email_allowed = realmConfig.loginWithEmailAllowed or true;
            duplicate_emails_allowed = realmConfig.duplicateEmailsAllowed or false;
            verify_email = realmConfig.verifyEmail or true;
            registration_allowed = realmConfig.registrationAllowed or false;
            registration_email_as_username = realmConfig.registrationEmailAsUsername or true;
            reset_password_allowed = realmConfig.resetPasswordAllowed or true;
            remember_me = realmConfig.rememberMe or true;

            # Security settings
            ssl_required = realmConfig.sslRequired or "external";
            password_policy = realmConfig.passwordPolicy or "upperCase(1) and length(8) and notUsername";

            # Session settings
            sso_session_idle_timeout = realmConfig.ssoSessionIdleTimeout or "30m";
            sso_session_max_lifespan = realmConfig.ssoSessionMaxLifespan or "10h";
            offline_session_idle_timeout = realmConfig.offlineSessionIdleTimeout or "720h";
            offline_session_max_lifespan = realmConfig.offlineSessionMaxLifespan or "8760h";

            # Themes
            login_theme = realmConfig.loginTheme or "base";
            admin_theme = realmConfig.adminTheme or "base";
            account_theme = realmConfig.accountTheme or "base";
            email_theme = realmConfig.emailTheme or "base";

            # Internationalization
            internationalization = lib.mkIf (realmConfig.internationalization or null != null) {
              supported_locales = realmConfig.internationalization.supportedLocales or [ "en" ];
              default_locale = realmConfig.internationalization.defaultLocale or "en";
            };

            # SMTP configuration if provided
            smtp_server = lib.mkIf (realmConfig.smtp or null != null) {
              host = realmConfig.smtp.host;
              port = realmConfig.smtp.port or 587;
              from = realmConfig.smtp.from;
              from_display_name = realmConfig.smtp.fromDisplayName or "Keycloak";
              reply_to = realmConfig.smtp.replyTo or realmConfig.smtp.from;
              reply_to_display_name = realmConfig.smtp.replyToDisplayName or "Keycloak";
              envelope_from = realmConfig.smtp.envelopeFrom or realmConfig.smtp.from;
              starttls = realmConfig.smtp.starttls or true;
              ssl = realmConfig.smtp.ssl or false;
              auth = lib.mkIf (realmConfig.smtp.auth or false) {
                username = realmConfig.smtp.username;
                password = realmConfig.smtp.password;
              };
            };

            # Security defenses
            security_defenses = lib.mkIf (realmConfig.securityDefenses or null != null) {
              headers = lib.mkIf (realmConfig.securityDefenses.headers or null != null) {
                x_frame_options = realmConfig.securityDefenses.headers.xFrameOptions or "DENY";
                content_security_policy =
                  realmConfig.securityDefenses.headers.contentSecurityPolicy
                    or "frame-src 'self'; frame-ancestors 'self'; object-src 'none';";
                content_security_policy_report_only =
                  realmConfig.securityDefenses.headers.contentSecurityPolicyReportOnly or "";
                x_content_type_options = realmConfig.securityDefenses.headers.xContentTypeOptions or "nosniff";
                x_robots_tag = realmConfig.securityDefenses.headers.xRobotsTag or "none";
                x_xss_protection = realmConfig.securityDefenses.headers.xXssProtection or "1; mode=block";
                strict_transport_security =
                  realmConfig.securityDefenses.headers.strictTransportSecurity
                    or "max-age=31536000; includeSubDomains";
              };

              brute_force_detection =
                lib.mkIf (realmConfig.securityDefenses.bruteForceDetection or null != null)
                  {
                    permanent_lockout = realmConfig.securityDefenses.bruteForceDetection.permanentLockout or false;
                    max_login_failures = realmConfig.securityDefenses.bruteForceDetection.maxLoginFailures or 30;
                    wait_increment_seconds =
                      realmConfig.securityDefenses.bruteForceDetection.waitIncrementSeconds or 60;
                    quick_login_check_milli_seconds =
                      realmConfig.securityDefenses.bruteForceDetection.quickLoginCheckMilliSeconds or 1000;
                    minimum_quick_login_wait_seconds =
                      realmConfig.securityDefenses.bruteForceDetection.minimumQuickLoginWaitSeconds or 60;
                    max_failure_wait_seconds =
                      realmConfig.securityDefenses.bruteForceDetection.maxFailureWaitSeconds or 900;
                    failure_reset_time_seconds =
                      realmConfig.securityDefenses.bruteForceDetection.failureResetTimeSeconds or 43200;
                  };
            };

            # Web authentication policies
            web_authn_policy = lib.mkIf (realmConfig.webAuthnPolicy or null != null) {
              relying_party_entity_name = realmConfig.webAuthnPolicy.relyingPartyEntityName or "keycloak";
              relying_party_id = realmConfig.webAuthnPolicy.relyingPartyId or "";
              require_resident_key = realmConfig.webAuthnPolicy.requireResidentKey or "not specified";
              user_verification_requirement =
                realmConfig.webAuthnPolicy.userVerificationRequirement or "not specified";
              create_timeout = realmConfig.webAuthnPolicy.createTimeout or 0;
              avoid_same_authenticator_register =
                realmConfig.webAuthnPolicy.avoidSameAuthenticatorRegister or false;
              acceptable_aaguids = realmConfig.webAuthnPolicy.acceptableAaguids or [ ];
            };

            # Custom attributes
            attributes = lib.mkIf (realmConfig.attributes or { } != { }) realmConfig.attributes;
          }
        ) config.keycloak.terraform.realms)
      ];
    };
  };
}
