# clan-core sshd service (clanServices/sshd/default.nix, clan-core 86d72f39).
#
# Both Clan roles with their settings, defaults and NixOS output:
#   server  sshd on the generated ed25519 host key (optional RSA key),
#           PasswordAuthentication off, CA-signed host certificate, root's
#           authorized keys, the CA and own-host known_hosts entries;
#   client  the @cert-authority known_hosts entry for <domain> plus the
#           client's and the servers' search domains.
#
# The Clan generators (openssh, openssh-ca, openssh-cert, openssh-rsa,
# sshd-root-key) are declared by openssh-keys.ncl via `declare_artifacts`
# below. OnixOS hands a module only the public artifact values declared by
# modules evaluated before it (name order), so the declarations live in
# openssh-keys and this module reads the keys and the certificate from
# args.artifacts.
#
# Differences OnixOS forces on the Clan output:
# - host keys are sops secrets at /run/secrets/<artifact>/<file>. hostKeys is
#   a list of records, which artifact_wiring cannot set, so the path is
#   written here and pinned with sops.secrets."<artifact>/<file>".path;
# - the host certificate is /etc/ssh/ssh.id_ed25519-cert.pub holding the
#   artifact contents (Clan: a store copy of the vars file);
# - a missing public key becomes a NixOS assertion instead of an evaluation
#   error, because OnixOS evaluates this module for every machine of the
#   instance, including machines this flake does not build.
fun onix =>
  let dns_name_pattern = "^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$" in
  let DnsName = std.contract.from_predicate (fun name => std.is_string name && std.string.is_match dns_name_pattern name) in
  let host_certificate_path = "/etc/ssh/ssh.id_ed25519-cert.pub" in
  # sops-nix default path of the OnixOS secret "<artifact>/<file>".
  let secret_path = fun artifact file => "/run/secrets/%{artifact}/%{file}" in
  let unique = fun items =>
    std.array.fold_left (fun acc item => if std.array.elem item acc then acc else acc @ [item]) [] items
  in
  let wildcards = fun domains => std.array.map (fun domain => "*.%{domain}") domains in
  # Public artifact contents, or null when the file is not available.
  let public_value = fun args artifact file =>
    let values = if std.record.has_field "artifacts" args then args.artifacts else {} in
    if std.record.has_field artifact values && std.record.has_field file values."%{artifact}" then
      values."%{artifact}"."%{file}"
    else
      null
  in
  let missing = fun args artifact file =>
    {
      assertion = false,
      message = "sshd: public artifact %{artifact}/%{file} is not available on %{args.machine_name}; copy or generate it under onixos/secrets and keep openssh-keys (which declares it) evaluated before sshd",
    }
  in
  let sshd_roles = {
    server = {
      authorized_keys
        | doc "SSH public keys authorized for root, keyed by name. Removing them can lock you out."
        | { _ : onix.NonEmptyString }
        | priority -5
        = {},
      generate_root_key
        | doc "Generate an SSH key pair for root access (artifact sshd-root-key) and authorize its public key for root."
        | Bool
        | priority -5
        = false,
      host_keys.rsa.enable
        | doc "Also generate and serve an RSA host key (artifact openssh-rsa)."
        | Bool
        | priority -5
        = false,
      certificate.enable
        | doc "Serve a CA-signed host certificate (artifacts openssh-ca, openssh-cert) and trust the CA."
        | Bool
        | priority -5
        = true,
      certificate.search_domains
        | doc "Domains besides `domain` for the certificate principals <machine>.<domain> and the CA known_hosts entry."
        | Array DnsName
        | priority -5
        = [],
      domain
        | doc "Clan meta.domain (unset in onix-core, so Clan's default): machines are <name>.<domain>."
        | DnsName
        | priority -5
        = "clan",
    },
    client = {
      certificate.search_domains
        | doc "Domains besides `domain` whose hosts are verified against the CA."
        | Array DnsName
        | priority -5
        = [],
      domain
        | doc "Clan meta.domain (unset in onix-core, so Clan's default)."
        | DnsName
        | priority -5
        = "clan",
      server_certificates
        | doc "Whether any server of this instance has certificate.enable (Clan reads roles.server.machines.*.settings). Installs the CA known_hosts entry."
        | Bool
        | priority -5
        = true,
      server_search_domains
        | doc "Union of the servers' certificate.search_domains in this instance (Clan reads them from roles.server.machines)."
        | Array DnsName
        | priority -5
        = [],
    },
  }
  in
  let public_file = onix.artifact_file { secret = false } in
  # Only the public half: Clan keeps id_ed25519 off every machine
  # (deploy = false), which an OnixOS artifact file cannot express, and OnixOS
  # never passes secret files to dependent generators. The CA is therefore
  # created and used outside OnixOS (Clan: ssh-keygen -t ed25519 -N "" -C "").
  let ca_artifact = {
    "openssh-ca" = {
      shared = true,
      files."id_ed25519.pub" = public_file,
      description = "Public key of the SSH host certificate authority",
    },
  }
  in
  let artifacts_for = fun args =>
    let cfg = args.settings in
    let machine = args.machine_name in
    if args.role_name == 'server then
      let principals =
        unique ([cfg.domain] @ cfg.certificate.search_domains)
        |> std.array.map (fun domain => "%{machine}.%{domain}")
      in
      let principal_list = std.string.join "," principals in
      {
        openssh = {
          files = {
            "ssh.id_ed25519" = onix.artifact_file {},
            "ssh.id_ed25519.pub" = public_file,
          },
          generator_script = m%"
            ssh-keygen -t ed25519 -N "" -C "" -f "$out"/ssh.id_ed25519
          "%,
          description = "SSH ed25519 host key of %{machine}",
        },
      }
      & (
        if cfg.certificate.enable then
          ca_artifact
          & {
            # Clan signs with the CA private key:
            #   ssh-keygen -s $in/openssh-ca/id_ed25519 -I <machine> -h -n <principals> $in/openssh/ssh.id_ed25519.pub
            # OnixOS generators never receive secret inputs, so the certificate
            # is signed outside OnixOS and copied in.
            openssh-cert = {
              files."ssh.id_ed25519-cert.pub" = public_file,
              description = "SSH host certificate of %{machine} for %{principal_list}, signed by openssh-ca",
            },
          }
        else
          {}
      )
      & (
        if cfg.host_keys.rsa.enable then
          {
            openssh-rsa = {
              files = {
                "ssh.id_rsa" = onix.artifact_file {},
                "ssh.id_rsa.pub" = public_file,
              },
              generator_script = m%"
              ssh-keygen -t rsa -b 4096 -N "" -C "" -f "$out"/ssh.id_rsa
            "%,
              description = "SSH RSA host key of %{machine}",
            },
          }
        else
          {}
      )
      & (
        if cfg.generate_root_key then
          {
            sshd-root-key = {
              files = {
                id_ed25519 = onix.artifact_file {},
                "id_ed25519.pub" = public_file,
              },
              generator_script = m%"
              ssh-keygen -t ed25519 -N "" -C "root@%{machine}" -f "$out"/id_ed25519
            "%,
              description = "SSH key pair for root access to %{machine}",
            },
          }
        else
          {}
      )
    else
      # A machine declares an artifact once: the colocated server role of
      # this instance owns openssh-ca unless it disabled certificates.
      let colocated_server_has_ca =
        args.placement_facts.colocated_roles
        |> std.array.any (fun role =>
          role.instance_name == args.instance_name
          && role.role_name == "server"
          && !(
            std.record.has_field "certificate" role.settings
            && std.record.has_field "enable" role.settings.certificate
            && role.settings.certificate.enable == false
          )
        )
      in
      if cfg.server_certificates && !colocated_server_has_ca then ca_artifact else {}
  in
  let server_output = fun args =>
    let cfg = args.settings in
    let search_domains = [cfg.domain] @ cfg.certificate.search_domains in
    let host_public_key = public_value args "openssh" "ssh.id_ed25519.pub" in
    let ca_public_key = public_value args "openssh-ca" "id_ed25519.pub" in
    let certificate = public_value args "openssh-cert" "ssh.id_ed25519-cert.pub" in
    let root_public_key = public_value args "sshd-root-key" "id_ed25519.pub" in
    let rsa = cfg.host_keys.rsa.enable in
    let assertion_list =
      (if host_public_key == null then [missing args "openssh" "ssh.id_ed25519.pub"] else [])
      @ (if cfg.certificate.enable && ca_public_key == null then [missing args "openssh-ca" "id_ed25519.pub"] else [])
    in
    {
      users.users.root.openssh.authorizedKeys.keys =
        std.record.values cfg.authorized_keys
        @ (if cfg.generate_root_key && root_public_key != null then [root_public_key] else []),
      services.openssh = {
        enable = true,
        settings.PasswordAuthentication = false,
        hostKeys =
          [{ path = secret_path "openssh" "ssh.id_ed25519", type = "ed25519" }]
          @ (if rsa then [{ path = secret_path "openssh-rsa" "ssh.id_rsa", type = "rsa" }] else []),
      },
      sops.secrets =
        { "openssh/ssh.id_ed25519".path = secret_path "openssh" "ssh.id_ed25519" }
        & (if rsa then { "openssh-rsa/ssh.id_rsa".path = secret_path "openssh-rsa" "ssh.id_rsa" } else {}),
      programs.ssh.knownHosts =
        (
          if host_public_key != null then
            {
              clan-sshd-self-ed25519 = {
                hostNames = ["localhost", args.machine_name, "%{args.machine_name}.%{cfg.domain}"],
                publicKey = host_public_key,
              },
            }
          else
            {}
        )
        & (
          if cfg.certificate.enable && ca_public_key != null then
            {
              ssh-ca = {
                certAuthority = true,
                extraHostNames = wildcards search_domains,
                publicKey = ca_public_key,
              },
            }
          else
            {}
        ),
    }
    # Clan sets HostCertificate only when the certificate exists.
    & (
      if cfg.certificate.enable && certificate != null then
        {
          services.openssh.settings.HostCertificate = host_certificate_path,
          environment.etc."ssh/ssh.id_ed25519-cert.pub".text = certificate,
        }
      else
        {}
    )
    & (if assertion_list == [] then {} else { assertions = assertion_list })
  in
  let client_output = fun args =>
    let cfg = args.settings in
    let ca_public_key = public_value args "openssh-ca" "id_ed25519.pub" in
    let domains = [cfg.domain] @ unique (cfg.certificate.search_domains @ cfg.server_search_domains) in
    if !cfg.server_certificates then
      {}
    else if ca_public_key == null then
      { assertions = [missing args "openssh-ca" "id_ed25519.pub"] }
    else
      {
        programs.ssh.knownHosts.ssh-ca = {
          certAuthority = true,
          extraHostNames = wildcards domains,
          publicKey = ca_public_key,
        },
      }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/sshd",
        description = "OpenSSH server with managed host keys and CA-signed host certificates; clients trust the CA.",
        categories = ["networking", "ssh"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "NixOS openssh, known_hosts and sops-nix options, as Clan's sshd service sets them",
          },
        ],
      },
      roles = sshd_roles,
    },

    impl = fun args =>
      { output.nixos = if args.role_name == 'server then server_output args else client_output args },

    # Shared with openssh-keys.ncl, which declares the artifacts.
    roles | not_exported = sshd_roles,
    declare_artifacts | not_exported = artifacts_for,

    tests | not_exported =
      let host_key = "ssh-ed25519 AAAAhost \n" in
      let ca_key = "ssh-ed25519 AAAAca \n" in
      let cert = "ssh-ed25519-cert-v01@openssh.com AAAAcert\n" in
      let full =
        onix.testing.artifact_values [
          { artifact = "openssh", file = "ssh.id_ed25519.pub", value = host_key },
          { artifact = "openssh-ca", file = "id_ed25519.pub", value = ca_key },
          { artifact = "openssh-cert", file = "ssh.id_ed25519-cert.pub", value = cert },
        ]
      in
      let run = fun role role_settings artifact_values =>
        (
          impl (
            onix.testing.mock_args { service = "sshd", role_name = role, settings = role_settings, machine_name = "aspen2" }
            & { artifacts = artifact_values }
          )
        ).output.nixos
      in
      let server_defaults = interface.roles.server in
      let client_defaults = interface.roles.client in
      let server = run 'server server_defaults full in
      let client = run 'client (client_defaults & { certificate.search_domains = ["local"] }) full in
      let no_cert =
        run
          'server
          server_defaults
          (
            onix.testing.artifact_values [
              { artifact = "openssh", file = "ssh.id_ed25519.pub", value = host_key },
              { artifact = "openssh-ca", file = "id_ed25519.pub", value = ca_key },
            ]
          )
      in
      let cert_off = run 'server (server_defaults & { certificate.enable = false }) full in
      let empty = run 'server server_defaults {} in
      let rsa = run 'server (server_defaults & { host_keys.rsa.enable = true }) full in
      let root_keys =
        run
          'server
          (server_defaults & { authorized_keys = { admin = "ssh-ed25519 AAAAadmin" }, generate_root_key = true })
          (full & { sshd-root-key = { "id_ed25519.pub" = "ssh-ed25519 AAAAroot root@aspen2\n" } })
      in
      [
        server.services.openssh.enable,
        server.services.openssh.settings.PasswordAuthentication == false,
        server.services.openssh.hostKeys == [{ path = "/run/secrets/openssh/ssh.id_ed25519", type = "ed25519" }],
        server.sops.secrets."openssh/ssh.id_ed25519".path == "/run/secrets/openssh/ssh.id_ed25519",
        server.services.openssh.settings.HostCertificate == "/etc/ssh/ssh.id_ed25519-cert.pub",
        server.environment.etc."ssh/ssh.id_ed25519-cert.pub".text == cert,
        server.programs.ssh.knownHosts.clan-sshd-self-ed25519 == { hostNames = ["localhost", "aspen2", "aspen2.clan"], publicKey = host_key },
        server.programs.ssh.knownHosts.ssh-ca == { certAuthority = true, extraHostNames = ["*.clan"], publicKey = ca_key },
        server.users.users.root.openssh.authorizedKeys.keys == [],
        !(std.record.has_field "assertions" server),
        # Client trusts the CA for the clan domain plus its search domains.
        client.programs.ssh.knownHosts.ssh-ca == { certAuthority = true, extraHostNames = ["*.clan", "*.local"], publicKey = ca_key },
        (run 'client (client_defaults & { certificate.search_domains = ["local"], server_search_domains = ["local", "lan"] }) full).programs.ssh.knownHosts.ssh-ca.extraHostNames == ["*.clan", "*.local", "*.lan"],
        run 'client (client_defaults & { server_certificates = false }) full == {},
        # No certificate file: no HostCertificate, like Clan's `exists` guard.
        !(std.record.has_field "HostCertificate" no_cert.services.openssh.settings),
        !(std.record.has_field "environment" no_cert),
        !(std.record.has_field "HostCertificate" cert_off.services.openssh.settings),
        !(std.record.has_field "ssh-ca" cert_off.programs.ssh.knownHosts),
        # Missing public keys fail the machine build, not the evaluation.
        std.array.length empty.assertions == 2,
        empty.programs.ssh.knownHosts == {},
        (std.array.at 1 rsa.services.openssh.hostKeys) == { path = "/run/secrets/openssh-rsa/ssh.id_rsa", type = "rsa" },
        rsa.sops.secrets."openssh-rsa/ssh.id_rsa".path == "/run/secrets/openssh-rsa/ssh.id_rsa",
        root_keys.users.users.root.openssh.authorizedKeys.keys == ["ssh-ed25519 AAAAadmin", "ssh-ed25519 AAAAroot root@aspen2\n"],
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
