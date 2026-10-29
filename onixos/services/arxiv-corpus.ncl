# Private arXiv Complete metadata search and selective paper text.
#
# Port of onix-core's Clan arxiv-corpus service (modules/arxiv-corpus): same
# settings, defaults, unit, tailscale0 firewall opening and bind-address
# assertion. Nickel cannot interpolate a package into ExecStart, so `prepare`
# and `serve` run from systemd preStart/script with the package on `path`.
fun onix =>
  # lib.escapeShellArg: safe words stay bare, anything else is single-quoted.
  let shell_arg = fun word =>
    if std.string.is_match "^[A-Za-z0-9,._+:@%/-]+$" word then
      word
    else
      let escaped = std.string.replace "'" "'\\''" word in
      "'%{escaped}'"
  in
  let shell_args = fun words => words |> std.array.map shell_arg |> std.string.join " " in
  # Loopback, or an IPv4 address in Tailscale's 100.64.0.0/10.
  let is_private_bind_address = fun address =>
    address == "127.0.0.1"
    || std.string.is_match "^100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}$" address
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/arxiv-corpus",
        description = "arXiv Complete metadata search and selective paper text",
        categories = ["AI/ML"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Hardened DynamicUser systemd unit with a tailscale0-only firewall opening",
          },
        ],
      },
      packages = ["arxiv-corpus"],
      roles.server = {
        host
          | doc "Loopback or Tailscale IPv4 bind address."
          | onix.NonEmptyString
          | priority -5
          = "127.0.0.1",
        port
          | doc "Private JSON API port."
          | onix.Port
          | priority -5
          = 7998,
        revision
          | doc "Immutable Hugging Face resource commit."
          | onix.NonEmptyString
          | priority -5
          = "cee894837962fede5612cccf2a4c7cacf49b4c3a",
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let name = "arxiv-corpus-%{args.instance_name}" in
      let state = "/var/lib/%{name}" in
      let prepare_args = shell_args ["--state-dir", state, "--revision", cfg.revision] in
      let serve_args = shell_args ["--state-dir", state, "--host", cfg.host, "--port", std.to_string cfg.port] in
      {
        output.nixos = {
          assertions = [
            {
              assertion = is_private_bind_address cfg.host,
              message = "arxiv-corpus must bind loopback or a Tailscale IPv4 address, never a public interface",
            },
          ],
          networking.firewall.interfaces.tailscale0.allowedTCPPorts =
            if cfg.host != "127.0.0.1" then [cfg.port] else [],
          systemd.services."%{name}" = {
            description = "arXiv Complete metadata search and selective paper text",
            wantedBy = ["multi-user.target"],
            wants = ["network-online.target"],
            after = ["network-online.target", "tailscaled.service"],
            environment = {
              HOME = state,
              HF_HOME = state,
              XDG_CACHE_HOME = "%{state}/cache",
              HF_HUB_DISABLE_TELEMETRY = "1",
              HF_HUB_DOWNLOAD_TIMEOUT = "60",
              HF_HUB_ETAG_TIMEOUT = "30",
              PYTHONUNBUFFERED = "1",
            },
            path = [args.packages.arxiv-corpus],
            preStart = "exec arxiv-corpus prepare %{prepare_args}",
            script = "exec arxiv-corpus serve %{serve_args}",
            serviceConfig = {
              Type = "simple",
              DynamicUser = true,
              StateDirectory = name,
              StateDirectoryMode = "0700",
              TimeoutStartSec = "2h",
              Restart = "on-failure",
              RestartSec = 5,
              MemoryMax = "4G",
              CPUQuota = "200%",
              NoNewPrivileges = true,
              PrivateTmp = true,
              PrivateDevices = true,
              ProtectHome = true,
              ProtectSystem = "strict",
              RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_UNIX"],
            },
          },
        },
      },

    tests | not_exported =
      let defaults = interface.roles.server in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "arxiv-corpus",
              role_name = 'server,
              settings = defaults & overrides,
              instance_name = "arxiv-aspen2",
              machine_name = "aspen2",
              packages = { arxiv-corpus = "arxiv-corpus-pkg" },
            }
          )
        ).output.nixos
      in
      let bind_ok = fun address => (std.array.first (run { host = address }).assertions).assertion in
      let tailnet = run { host = "100.82.25.30" } in
      let loopback = run {} in
      let unit = tailnet.systemd.services.arxiv-corpus-arxiv-aspen2 in
      [
        defaults.host == "127.0.0.1",
        defaults.port == 7998,
        defaults.revision == "cee894837962fede5612cccf2a4c7cacf49b4c3a",
        # Unit, state and cache paths follow the Clan instance name.
        unit.serviceConfig.StateDirectory == "arxiv-corpus-arxiv-aspen2",
        unit.environment.XDG_CACHE_HOME == "/var/lib/arxiv-corpus-arxiv-aspen2/cache",
        unit.after == ["network-online.target", "tailscaled.service"],
        unit.path == ["arxiv-corpus-pkg"],
        unit.preStart == "exec arxiv-corpus prepare --state-dir /var/lib/arxiv-corpus-arxiv-aspen2 --revision cee894837962fede5612cccf2a4c7cacf49b4c3a",
        unit.script == "exec arxiv-corpus serve --state-dir /var/lib/arxiv-corpus-arxiv-aspen2 --host 100.82.25.30 --port 7998",
        unit.serviceConfig.DynamicUser,
        unit.serviceConfig.MemoryMax == "4G",
        unit.serviceConfig.CPUQuota == "200%",
        unit.serviceConfig.TimeoutStartSec == "2h",
        # A tailnet bind opens the port on tailscale0 only; loopback opens nothing.
        tailnet.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [7998],
        loopback.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [],
        bind_ok "100.82.25.30",
        bind_ok "127.0.0.1",
        !(bind_ok "0.0.0.0"),
        !(bind_ok "100.128.0.1"),
        !(bind_ok "203.0.113.7"),
        # Unsafe words reach the shell quoted, like lib.escapeShellArgs.
        std.string.contains "--revision 'a b'" (run { revision = "a b" }).systemd.services.arxiv-corpus-arxiv-aspen2.preStart,
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
