# Laya English typed decisions, CPU backend.
#
# Port of onix-core's Clan laya service (modules/laya) for the cpu backend:
# same settings, defaults, unit, tailscale0 firewall opening and bind-address
# assertion. `prepare` and `serve` run from systemd preStart/script with the
# package on `path`. The vulkan-compensated-fp32 backend (laya-aspen1) is not
# ported: its assertion reads config.hardware.graphics.enable, which Nickel
# cannot see, so `backend` admits only "cpu".
fun onix =>
  let shell_arg = fun word =>
    if std.string.is_match "^[A-Za-z0-9,._+:@%/-]+$" word then
      word
    else
      let escaped = std.string.replace "'" "'\\''" word in
      "'%{escaped}'"
  in
  let shell_args = fun words => words |> std.array.map shell_arg |> std.string.join " " in
  let is_private_bind_address = fun address =>
    address == "127.0.0.1"
    || std.string.is_match "^100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}$" address
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/laya",
        description = "Laya English typed decisions on CPU",
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
      packages = ["laya"],
      roles.server = {
        backend
          | doc "Laya runtime. Only cpu is ported; vulkan-compensated-fp32 stays on the Clan module."
          | std.enum.TagOrString
          | [| 'cpu |]
          | priority -5
          = 'cpu,
        host
          | doc "Loopback or Tailscale IPv4 bind address."
          | onix.NonEmptyString
          | priority -5
          = "127.0.0.1",
        port
          | doc "Private JSON API port."
          | onix.Port
          | priority -5
          = 7999,
        revision
          | doc "Immutable Hugging Face resource commit."
          | onix.NonEmptyString
          | priority -5
          = "1c5edc17a7acd8701df6fc341c0d179f1c62c982",
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let name = "laya-%{args.instance_name}" in
      let state = "/var/lib/%{name}" in
      let base_args = ["--state-dir", state, "--revision", cfg.revision] in
      let prepare_args = shell_args base_args in
      let serve_args = shell_args (base_args @ ["--host", cfg.host, "--port", std.to_string cfg.port, "--threads", "4"]) in
      let backend_name = std.to_string cfg.backend in
      {
        output.nixos = {
          assertions = [
            {
              assertion = is_private_bind_address cfg.host,
              message = "laya must bind loopback or a Tailscale IPv4 address, never a public interface",
            },
          ],
          networking.firewall.interfaces.tailscale0.allowedTCPPorts =
            if cfg.host != "127.0.0.1" then [cfg.port] else [],
          systemd.services."%{name}" = {
            description = "Laya English typed decisions (%{backend_name})",
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
            path = [args.packages.laya],
            preStart = "exec laya-server prepare %{prepare_args}",
            script = "exec laya-server serve %{serve_args}",
            serviceConfig = {
              Type = "simple",
              DynamicUser = true,
              StateDirectory = name,
              StateDirectoryMode = "0700",
              TimeoutStartSec = "2h",
              Restart = "on-failure",
              RestartSec = 5,
              MemoryMax = "6G",
              CPUQuota = "400%",
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
              service = "laya",
              role_name = 'server,
              settings = defaults & overrides,
              instance_name = "laya-aspen2",
              machine_name = "aspen2",
              packages = { laya = "laya-pkg" },
            }
          )
        ).output.nixos
      in
      let bind_ok = fun address => (std.array.first (run { host = address }).assertions).assertion in
      let tailnet = run { host = "100.82.25.30" } in
      let unit = tailnet.systemd.services.laya-laya-aspen2 in
      [
        defaults.backend == 'cpu,
        defaults.port == 7999,
        defaults.revision == "1c5edc17a7acd8701df6fc341c0d179f1c62c982",
        # Settings from per-machine bindings arrive as strings.
        (run { backend = "cpu" }).systemd.services.laya-laya-aspen2.description == "Laya English typed decisions (cpu)",
        unit.description == "Laya English typed decisions (cpu)",
        unit.path == ["laya-pkg"],
        unit.preStart == "exec laya-server prepare --state-dir /var/lib/laya-laya-aspen2 --revision 1c5edc17a7acd8701df6fc341c0d179f1c62c982",
        unit.script == "exec laya-server serve --state-dir /var/lib/laya-laya-aspen2 --revision 1c5edc17a7acd8701df6fc341c0d179f1c62c982 --host 100.82.25.30 --port 7999 --threads 4",
        unit.environment.XDG_CACHE_HOME == "/var/lib/laya-laya-aspen2/cache",
        unit.serviceConfig.MemoryMax == "6G",
        unit.serviceConfig.CPUQuota == "400%",
        unit.serviceConfig.PrivateDevices,
        tailnet.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [7999],
        (run {}).networking.firewall.interfaces.tailscale0.allowedTCPPorts == [],
        bind_ok "100.82.25.30",
        !(bind_ok "0.0.0.0"),
        !(bind_ok "192.168.1.5"),
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
