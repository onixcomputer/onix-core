{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "thunderbird";
    description = "Thunderbird desktop mail profile with clan-managed account secrets";
    readme = "Installs Thunderbird and writes a managed profile for Fastmail and Gmail. Account addresses and app passwords/OAuth bootstrap data are supplied by clan vars prompts.";
    categories = [
      "Desktop"
      "Messaging"
    ];
  };

  roles.default = {
    description = "Configure a Thunderbird profile for a local desktop user";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);

            generatorName = "thunderbird-${instanceName}";
            serviceName = "thunderbird-profile-${instanceName}";
            loginFile = config.clan.core.vars.generators.${generatorName}.files."login-json".path;

            syncProfile = pkgs.writeShellApplication {
              name = "thunderbird-sync-profile";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.python3
              ];
              text = ''
                umask 077
                export THUNDERBIRD_LOGIN_FILE=${lib.escapeShellArg loginFile}
                export THUNDERBIRD_USER_HOME=${lib.escapeShellArg settings.userHome}
                export THUNDERBIRD_PROFILE_NAME=${lib.escapeShellArg settings.profileName}
                export THUNDERBIRD_FULL_NAME=${lib.escapeShellArg settings.fullName}
                export THUNDERBIRD_FASTMAIL_LABEL=${lib.escapeShellArg settings.fastmailLabel}
                export THUNDERBIRD_GMAIL_LABEL=${lib.escapeShellArg settings.gmailLabel}
                export THUNDERBIRD_GMAIL_AUTH_METHOD=${lib.escapeShellArg settings.gmailAuthMethod}

                python3 <<'PY'
                import json
                import os
                import pathlib
                import time

                login_file = pathlib.Path(os.environ["THUNDERBIRD_LOGIN_FILE"])
                user_home = pathlib.Path(os.environ["THUNDERBIRD_USER_HOME"])
                profile_name = os.environ["THUNDERBIRD_PROFILE_NAME"]
                full_name = os.environ["THUNDERBIRD_FULL_NAME"]
                fastmail_label = os.environ["THUNDERBIRD_FASTMAIL_LABEL"]
                gmail_label = os.environ["THUNDERBIRD_GMAIL_LABEL"]
                gmail_auth_method = os.environ["THUNDERBIRD_GMAIL_AUTH_METHOD"]

                placeholder = "Welcome to SOPS! Edit this file as you please!"
                data = json.loads(login_file.read_text(encoding="utf-8"))

                def required(name):
                    value = str(data.get(name, "")).strip()
                    if not value or value == placeholder:
                        raise SystemExit(f"Thunderbird login field {name!r} is unset; run clan vars generate for this service")
                    return value

                fastmail_email = required("fastmailEmail")
                fastmail_password = required("fastmailAppPassword")
                gmail_email = required("gmailEmail")
                gmail_password = str(data.get("gmailAppPassword", "")).strip()
                if gmail_password == placeholder:
                    gmail_password = ""
                if gmail_auth_method == "password" and not gmail_password:
                    raise SystemExit("Thunderbird Gmail app password is unset while gmailAuthMethod = 'password'")

                tb_dir = user_home / ".thunderbird"
                profile_dir = tb_dir / f"{profile_name}.default"
                config_dir = user_home / ".config" / "thunderbird"
                tb_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
                profile_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
                config_dir.mkdir(mode=0o700, parents=True, exist_ok=True)

                # Keep the Thunderbird profile location deterministic so the generated
                # account prefs are applied before the first interactive launch.
                (tb_dir / "profiles.ini").write_text(
                    "[Profile0]\n"
                    f"Name={profile_name}\n"
                    "IsRelative=1\n"
                    f"Path={profile_name}.default\n"
                    "Default=1\n"
                    "\n[General]\nStartWithLastProfile=1\nVersion=2\n",
                    encoding="utf-8",
                )
                os.chmod(tb_dir / "profiles.ini", 0o600)

                gmail_auth = 10 if gmail_auth_method == "oauth2" else 3
                gmail_note = "OAuth2 browser login" if gmail_auth_method == "oauth2" else "app password from login-json"

                def js_string(value):
                    return json.dumps(str(value))

                prefs = {
                    "mail.accountmanager.accounts": "account1,account2",
                    "mail.accountmanager.defaultaccount": "account1",
                    "mail.account.account1.server": "server1",
                    "mail.account.account1.identities": "id1",
                    "mail.account.account2.server": "server2",
                    "mail.account.account2.identities": "id2",
                    "mail.identity.id1.fullName": full_name,
                    "mail.identity.id1.useremail": fastmail_email,
                    "mail.identity.id1.valid": True,
                    "mail.identity.id1.smtpServer": "smtp1",
                    "mail.identity.id2.fullName": full_name,
                    "mail.identity.id2.useremail": gmail_email,
                    "mail.identity.id2.valid": True,
                    "mail.identity.id2.smtpServer": "smtp2",
                    "mail.server.server1.type": "imap",
                    "mail.server.server1.name": fastmail_label,
                    "mail.server.server1.hostname": "imap.fastmail.com",
                    "mail.server.server1.port": 993,
                    "mail.server.server1.socketType": 3,
                    "mail.server.server1.authMethod": 3,
                    "mail.server.server1.userName": fastmail_email,
                    "mail.server.server1.login_at_startup": True,
                    "mail.server.server1.check_new_mail": True,
                    "mail.server.server2.type": "imap",
                    "mail.server.server2.name": gmail_label,
                    "mail.server.server2.hostname": "imap.gmail.com",
                    "mail.server.server2.port": 993,
                    "mail.server.server2.socketType": 3,
                    "mail.server.server2.authMethod": gmail_auth,
                    "mail.server.server2.userName": gmail_email,
                    "mail.server.server2.login_at_startup": True,
                    "mail.server.server2.check_new_mail": True,
                    "mail.smtpservers": "smtp1,smtp2",
                    "mail.smtp.defaultserver": "smtp1",
                    "mail.smtpserver.smtp1.hostname": "smtp.fastmail.com",
                    "mail.smtpserver.smtp1.port": 465,
                    "mail.smtpserver.smtp1.try_ssl": 3,
                    "mail.smtpserver.smtp1.authMethod": 3,
                    "mail.smtpserver.smtp1.username": fastmail_email,
                    "mail.smtpserver.smtp1.description": fastmail_label,
                    "mail.smtpserver.smtp2.hostname": "smtp.gmail.com",
                    "mail.smtpserver.smtp2.port": 465,
                    "mail.smtpserver.smtp2.try_ssl": 3,
                    "mail.smtpserver.smtp2.authMethod": gmail_auth,
                    "mail.smtpserver.smtp2.username": gmail_email,
                    "mail.smtpserver.smtp2.description": gmail_label,
                    "signon.rememberSignons": True,
                }

                lines = [
                    "// Managed by onix-core Thunderbird clan service.",
                    "// Account passwords are not written to user.js; see ~/.config/thunderbird/onix-login.json.",
                ]
                for key in sorted(prefs):
                    value = prefs[key]
                    if isinstance(value, bool):
                        rendered = "true" if value else "false"
                    elif isinstance(value, int):
                        rendered = str(value)
                    else:
                        rendered = js_string(value)
                    lines.append(f"user_pref({js_string(key)}, {rendered});")
                (profile_dir / "user.js").write_text("\n".join(lines) + "\n", encoding="utf-8")
                os.chmod(profile_dir / "user.js", 0o600)

                # Keep generated login material outside the Nix store and readable only
                # by the target user. Thunderbird still owns password import/OAuth;
                # this file gives the user the exact app passwords/prompts to paste
                # when the configured accounts first ask for credentials.
                login_out = {
                    "managedAt": int(time.time()),
                    "fastmail": {
                        "email": fastmail_email,
                        "imap": "imap.fastmail.com:993 SSL/TLS normal-password",
                        "smtp": "smtp.fastmail.com:465 SSL/TLS normal-password",
                        "appPassword": fastmail_password,
                    },
                    "gmail": {
                        "email": gmail_email,
                        "imap": "imap.gmail.com:993 SSL/TLS",
                        "smtp": "smtp.gmail.com:465 SSL/TLS",
                        "auth": gmail_note,
                        "appPassword": gmail_password,
                    },
                }
                (config_dir / "onix-login.json").write_text(json.dumps(login_out, indent=2) + "\n", encoding="utf-8")
                os.chmod(config_dir / "onix-login.json", 0o600)

                (config_dir / "README").write_text(
                    "Thunderbird account prefs are managed in ~/.thunderbird/"
                    f"{profile_name}.default/user.js. Secret login material is in "
                    "~/.config/thunderbird/onix-login.json (0600). Gmail defaults "
                    "to OAuth2, so Thunderbird will open a browser/device login on "
                    "first use; Fastmail should use an app password.\n",
                    encoding="utf-8",
                )
                os.chmod(config_dir / "README", 0o600)
                PY
              '';
            };
          in
          {
            programs.thunderbird.enable = true;

            clan.core.vars.generators.${generatorName} = {
              share = true;
              files."login-json" = {
                secret = true;
                deploy = true;
                owner = settings.user;
                inherit (settings) group;
              };
              prompts = {
                fastmail-email = {
                  description = "Fastmail email address for Thunderbird";
                  persist = true;
                };
                fastmail-app-password = {
                  description = "Fastmail app password for Thunderbird IMAP/SMTP";
                  type = "hidden";
                  persist = true;
                };
                gmail-email = {
                  description = "Gmail address for Thunderbird";
                  persist = true;
                };
                gmail-app-password = {
                  description = "Optional Gmail app password if gmailAuthMethod = password; leave SOPS placeholder when using OAuth2";
                  type = "hidden";
                  persist = true;
                };
              };
              runtimeInputs = [
                pkgs.coreutils
                pkgs.jq
              ];
              script = ''
                fastmail_email="$(tr -d '\n' < "$prompts/fastmail-email")"
                fastmail_app_password="$(tr -d '\n' < "$prompts/fastmail-app-password")"
                gmail_email="$(tr -d '\n' < "$prompts/gmail-email")"
                gmail_app_password="$(tr -d '\n' < "$prompts/gmail-app-password")"
                gmail_auth_method=${lib.escapeShellArg settings.gmailAuthMethod}

                placeholder='Welcome to SOPS! Edit this file as you please!'
                if [ -z "$fastmail_email" ] || [ "$fastmail_email" = "$placeholder" ]; then
                  echo "Fastmail email is unset" >&2
                  exit 1
                fi
                if [ -z "$fastmail_app_password" ] || [ "$fastmail_app_password" = "$placeholder" ]; then
                  echo "Fastmail app password is unset" >&2
                  exit 1
                fi
                if [ -z "$gmail_email" ] || [ "$gmail_email" = "$placeholder" ]; then
                  echo "Gmail email is unset" >&2
                  exit 1
                fi
                if [ "$gmail_auth_method" = "password" ] && { [ -z "$gmail_app_password" ] || [ "$gmail_app_password" = "$placeholder" ]; }; then
                  echo "Gmail app password is unset while gmailAuthMethod = password" >&2
                  exit 1
                fi

                jq -n \
                  --arg fastmailEmail "$fastmail_email" \
                  --arg fastmailAppPassword "$fastmail_app_password" \
                  --arg gmailEmail "$gmail_email" \
                  --arg gmailAppPassword "$gmail_app_password" \
                  '{
                    fastmailEmail: $fastmailEmail,
                    fastmailAppPassword: $fastmailAppPassword,
                    gmailEmail: $gmailEmail,
                    gmailAppPassword: $gmailAppPassword
                  }' > "$out/login-json"
              '';
            };

            systemd.tmpfiles.rules = [
              "d ${settings.userHome}/.thunderbird 0700 ${settings.user} ${settings.group} -"
              "d ${settings.userHome}/.config/thunderbird 0700 ${settings.user} ${settings.group} -"
            ];

            systemd.services.${serviceName} = {
              description = "Sync Thunderbird profile (${instanceName})";
              wantedBy = [ "multi-user.target" ];
              after = [ "local-fs.target" ];
              serviceConfig = {
                Type = "oneshot";
                User = settings.user;
                Group = settings.group;
                UMask = "0077";
                ExecStart = lib.getExe syncProfile;
                RemainAfterExit = true;
              };
            };
          };
      };
  };
}
