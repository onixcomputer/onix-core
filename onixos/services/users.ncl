# clan-core users service (clanServices/users/default.nix, clan-core 86d72f39).
#
# Creates the account with its groups, a password hash from the per-user
# artifact user-password-<user> decrypted before users are created
# (neededForUsers), and immutable users on every machine of the service.
#
# Clan also keeps the plaintext password in the generator (file
# user-password, deploy = false, persisted prompt). OnixOS deploys every
# declared secret file, so only the hash is an OnixOS file; the prompt keeps
# Clan's name and the script drops the plaintext after hashing.
fun onix =>
  let Identity = {
    email | doc "IdP email; empty means <user>@mail.<domain>." | String | default = "",
    groups | doc "IdP groups." | Array String | default = [],
    displayname | doc "Display name; unset means the user name." | String | optional,
  }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/users",
        description = "User account with groups and a generated or prompted password hash.",
        categories = ["system", "users"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "NixOS users.users, users.mutableUsers and sops-nix secrets-for-users, as Clan's users service sets them",
          },
        ],
      },
      roles.default = {
        user
          | doc "Account name. Clan defaults it to the instance name."
          | onix.UnixName
          | optional,
        system_user
          | doc "Create the Unix account (false: identity-only user)."
          | Bool
          | priority -5
          = true,
        prompt
          | doc "Ask for the password when generating instead of generating one."
          | Bool
          | priority -5
          = false,
        groups
          | doc "Additional groups (extraGroups); they must exist on every machine."
          | Array onix.UnixName
          | priority -5
          = [],
        share
          | doc "Same password on every machine (shared artifact)."
          | Bool
          | priority -5
          = false,
        identity
          | doc "IdP identities keyed by IdP instance name, exported as auth.users."
          | { _ : Identity }
          | priority -5
          = {},
        openssh.authorized_keys.keys
          | doc "OpenSSH public keys added to the user's authorized keys."
          | Array onix.NonEmptyString
          | priority -5
          = [],
        openssh.authorized_keys.key_files
          | doc "Files with one OpenSSH public key each, read at build time (store paths)."
          | Array onix.Path
          | priority -5
          = [],
        domain
          | doc "Clan meta.domain (unset in onix-core, so Clan's default), used for default identity emails."
          | onix.NonEmptyString
          | priority -5
          = "clan",
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let user = if std.record.has_field "user" cfg then cfg.user else args.instance_name in
      let artifact_name = "user-password-%{user}" in
      let machines = if std.record.has_field "machines" args.inventory then args.inventory.machines else {} in
      let machine = if std.record.has_field args.machine_name machines then machines."%{args.machine_name}" else {} in
      let userborn = std.record.has_field "userborn" machine && machine.userborn in
      # Only the hash is an artifact file: OnixOS deploys every declared
      # secret, and Clan never deployed the plaintext password.
      let password_script =
        (
          if cfg.prompt then
            m%"
            password=$(tr -d "\n" < "$prompts"/user-password)
            if [[ -z "$password" ]]; then
              password=$(xkcdpass --numwords 6 --delimiter - --count 1 | tr -d "\n")
            fi
          "%
          else
            m%"
            password=$(xkcdpass --numwords 6 --delimiter - --count 1 | tr -d "\n")
          "%
        )
        ++ "\n"
        ++ m%"
          printf '%s' "$password" | mkpasswd -s | tr -d "\n" > "$out"/user-password-hash
        "%
      in
      let account =
        if cfg.system_user then
          {
            nixos = {
              users.users."%{user}" = {
                isNormalUser = user != "root",
                extraGroups = cfg.groups,
                openssh.authorizedKeys = {
                  keys = cfg.openssh.authorized_keys.keys,
                  keyFiles = cfg.openssh.authorized_keys.key_files,
                },
              },
              sops.secrets."%{artifact_name}/user-password-hash" = {
                neededForUsers = true,
                restartUnits = if userborn then ["userborn.service"] else [],
              },
            },
            artifact_wiring = [
              onix.artifact_wiring {
                artifact = artifact_name,
                file = "user-password-hash",
                nixos_option = "users.users.%{user}.hashedPasswordFile",
              },
            ],
          }
          & onix.artifact_declaration {
            name = artifact_name,
            shared = cfg.share,
            files.user-password-hash = onix.artifact_file {},
            prompts = if cfg.prompt then { user-password.description = "Password for %{user}" } else {},
            # Needs xkcdpass and mkpasswd on PATH (Clan runtimeInputs).
            generator_script = password_script,
            description = "Password hash of %{user}",
          }
        else
          {}
      in
      let exports =
        if cfg.identity == {} then
          {}
        else
          {
            exports.auth.users =
              cfg.identity
              |> std.record.map (fun _idp id =>
                {
                  username = user,
                  email = if id.email != "" then id.email else "%{user}@mail.%{cfg.domain}",
                  groups = id.groups,
                  displayname = if std.record.has_field "displayname" id then id.displayname else user,
                }
              ),
          }
      in
      # Clan perMachine: immutable users on every machine of the service.
      { output = { nixos.users.mutableUsers = false } & account & exports },

    tests | not_exported =
      let defaults = interface.roles.default in
      let run = fun instance overrides extra =>
        (
          impl (
            onix.testing.mock_args { service = "users", role_name = 'default, settings = defaults & overrides, instance_name = instance, machine_name = "aspen2" }
            & extra
          )
        ).output
      in
      let out = run "user-brittonr" { user = "brittonr", prompt = true, groups = ["wheel", "docker"] } {} in
      let artifact = out.artifacts.user-password-brittonr in
      let wiring = std.array.first out.artifact_wiring in
      let unprompted = (run "alice" {} {}).artifacts.user-password-alice in
      let identity_only = run "svc" { user = "svc", system_user = false } {} in
      [
        out.nixos.users.mutableUsers == false,
        out.nixos.users.users.brittonr.isNormalUser,
        out.nixos.users.users.brittonr.extraGroups == ["wheel", "docker"],
        out.nixos.users.users.brittonr.openssh.authorizedKeys == { keys = [], keyFiles = [] },
        # Only the hash is deployed, before users exist.
        std.record.fields artifact.files == ["user-password-hash"],
        artifact.files.user-password-hash.secret,
        artifact.files.user-password-hash.mode == "0400",
        out.nixos.sops.secrets."user-password-brittonr/user-password-hash".neededForUsers,
        out.nixos.sops.secrets."user-password-brittonr/user-password-hash".restartUnits == [],
        wiring.nixos_option == "users.users.brittonr.hashedPasswordFile",
        wiring.file == "user-password-hash",
        !(std.record.has_field "value" wiring),
        std.record.has_field "user-password" artifact.prompts,
        std.string.contains "$prompts\"/user-password" artifact.generator_script,
        std.string.contains "mkpasswd -s" artifact.generator_script,
        !artifact.shared,
        # Clan defaults the user to the instance name; no prompt by default.
        (run "alice" {} {}).nixos.users.users.alice.isNormalUser,
        unprompted.prompts == {},
        !(std.string.contains "$prompts" unprompted.generator_script),
        (run "root" {} {}).nixos.users.users.root.isNormalUser == false,
        (run "u" { user = "brittonr", share = true } {}).artifacts.user-password-brittonr.shared,
        (run "u" { user = "brittonr" } { inventory.machines.aspen2.userborn = true }).nixos.sops.secrets."user-password-brittonr/user-password-hash".restartUnits == ["userborn.service"],
        identity_only.nixos == { users.mutableUsers = false },
        !(std.record.has_field "artifacts" identity_only),
        (run "u" { user = "brittonr", identity.main = { groups = ["admins"] } } {}).exports.auth.users.main == { username = "brittonr", email = "brittonr@mail.clan", groups = ["admins"], displayname = "brittonr" },
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
