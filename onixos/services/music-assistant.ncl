# Music Assistant, as aspen2 runs it (machines/aspen2/configuration.nix enables
# services.music-assistant): the `mass` server with its state in
# /var/lib/music-assistant and its web port open.
fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    let cfg = args.settings in
    {
      output.host =
        {
          units."music-assistant.service" = {
            sections = {
              Unit = {
                Description = "Music Assistant",
                After = "network-online.target",
                Wants = "network-online.target",
              },
              Service = {
                Type = "simple",
                DynamicUser = "true",
                User = "music-assistant",
                Group = "music-assistant",
                StateDirectory = "music-assistant",
                Environment = "HOME=/var/lib/music-assistant",
                ExecStart = "%{p."music-assistant"}/bin/mass --config /var/lib/music-assistant",
                Restart = "on-failure",
                PrivateTmp = "true",
                ProtectHome = "true",
              },
            },
            wanted_by = ["multi-user.target"],
          },
        }
        & (if cfg.open_firewall then { firewall.allowed_tcp_ports = [cfg.port] } else {}),
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/music-assistant",
        description = "Music Assistant server for OnixOS systemd hosts.",
        categories = ["media"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts run the same package and state directory as services.music-assistant",
          },
        ],
      },
      packages = ["music-assistant"],
      roles.host = {
        port | onix.Port | default = 8095,
        open_firewall | Bool | default = true,
      },
    },

    impl = host_impl,

    tests | not_exported =
      let pkgs = { "music-assistant" = "mass-pkg" } in
      let out = (host_impl (onix.testing.mock_args { service = "music-assistant", role_name = 'host, settings = interface.roles.host, packages = pkgs, package_paths = pkgs })).output.host in
      [
        std.string.contains "mass --config /var/lib/music-assistant" out.units."music-assistant.service".sections.Service.ExecStart,
        out.units."music-assistant.service".sections.Service.DynamicUser == "true",
        out.firewall.allowed_tcp_ports == [8095],
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
