# Private Mesh-LLM sidecar for an existing OpenAI-compatible endpoint.
#
# Port of onix-core's Clan mesh-llm service (modules/mesh-llm: default.nix,
# mk-nixos-config.nix, mk-launch-args.nix): same settings, defaults, units,
# user, tmpfiles, firewall, assertions and shared invites generator. Clan read
# each node's mode through `roles`; `mesh_nodes` carries those facts.
#
# Ported: seed and joiner modes, openai-endpoint plugins, research provider,
# forwarder or disabled, and the API/peer-loss watchdog. Not ported (the
# settings reject a value): mesh_bind_interface (interface launcher, dgx-spark)
# and research_http_bind_address (nginx research gateway, britton-desktop).
#
# Nickel cannot put a package into a string, so:
# - the sidecar starts from systemd `script` with mesh-llm and mesh-research
#   on `path`; config.toml names plugins by command name, which mesh-llm finds
#   on that PATH (it spawns `command` with Command::new);
# - config.toml and research.json live in /etc/<unit>/, and restartTriggers
#   carries their text so a change still restarts the sidecar;
# - the start script exports LD_LIBRARY_PATH from the gcc lib output.
fun onix =>
  let shell_arg = fun word =>
    if std.string.is_match "^[A-Za-z0-9,._+:@%/-]+$" word then
      word
    else
      let escaped = std.string.replace "'" "'\\''" word in
      "'%{escaped}'"
  in
  let shell_args = fun words => words |> std.array.map shell_arg |> std.string.join " " in
  # builtins.toJSON for strings and null.
  let json = fun scalar => if scalar == null then "null" else std.serialize 'Json scalar in
  let mode_name = fun mode => if std.is_enum mode then std.to_string mode else mode in
  let NodeMode =
    std.contract.custom (fun label mode =>
      if (std.is_enum mode || std.is_string mode) && std.array.elem (mode_name mode) ["seed", "joiner"] then
        'Ok mode
      else
        label
        |> std.contract.label.with_message "expected \"seed\" or \"joiner\""
        |> std.contract.blame
    )
  in
  let NullOrString =
    std.contract.custom (fun label text =>
      if text == null || std.is_string text then
        'Ok text
      else
        label
        |> std.contract.label.with_message "expected a string or null"
        |> std.contract.blame
    )
  in
  let NotPorted = fun feature =>
    std.contract.custom (fun label setting =>
      if setting == null then
        'Ok setting
      else
        label
        |> std.contract.label.with_message "%{feature} is not ported to OnixOS; keep this node on the Clan mesh-llm module"
        |> std.contract.blame
    )
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/mesh-llm",
        description = "Routes local OpenAI-compatible models through a private Mesh-LLM node",
        categories = ["AI/ML", "Inference"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Hardened systemd sidecar, watchdog timer, system user and firewall opening",
          },
        ],
      },
      packages = ["mesh-llm", "mesh-research", "stdenv.cc.cc.lib", "bash", "coreutils", "curl", "jq", "systemd"],
      roles.default = {
        mode
          | doc "Whether this node creates the private mesh or joins with a managed credential."
          | std.enum.TagOrString
          | [| 'seed, 'joiner |]
          | priority -5
          = 'seed,
        mesh_nodes
          | doc "Mode of every node in this instance, keyed by machine name (Clan read it from roles.default.machines). Sets the invite artifact's files and a joiner's join order."
          | { _ : NodeMode }
          | priority -5
          = {},
        endpoint_url
          | doc "Local OpenAI-compatible endpoint advertised by the openai-endpoint plugin; null for a node without a local inference backend."
          | NullOrString
          | priority -5
          = "http://127.0.0.1:13305/v1",
        extra_endpoints
          | doc "Additional externally managed loopback OpenAI /v1 endpoints keyed by plugin name; openai-endpoint is reserved for endpoint_url."
          | { _ : String }
          | priority -5
          = {},
        research_mode
          | doc "Native research plugin: local provider or authenticated peer-stream forwarder."
          | std.enum.TagOrString
          | [| 'disabled, 'provider, 'forwarder |]
          | priority -5
          = 'disabled,
        research_arxiv_address
          | doc "Provider-only private arXiv backend IP:port; unset disables corpus operations on this peer."
          | onix.NonEmptyString
          | optional,
        research_laya_address
          | doc "Provider-only private Laya backend IP:port; unset disables Laya operations on this peer."
          | onix.NonEmptyString
          | optional,
        research_target_peer
          | doc "Forwarder-only full lowercase Mesh peer ID of the research provider."
          | String
          | priority -5
          = "",
        research_backend_units
          | doc "Local research service units ordered before the provider sidecar."
          | Array onix.NonEmptyString
          | priority -5
          = [],
        research_http_bind_address
          | doc "Tailscale address for research-only HTTP ingress. Not ported: the nginx research gateway stays on Clan."
          | NotPorted "research_http_bind_address (nginx research gateway)"
          | optional,
        research_http_port
          | doc "Private research-only HTTP ingress port (only used by the unported gateway)."
          | onix.Port
          | priority -5
          = 7997,
        proxy_activation_model
          | doc "Small CPU bootstrap model that activates Mesh-LLM v0.72.2's plugin-aware API proxy."
          | String
          | priority -5
          = "Qwen3-0.6B-Q4_K_M",
        proxy_activation_context_size
          | doc "Bounded context size for the CPU proxy-activation model."
          | onix.PositiveInteger
          | priority -5
          = 512,
        api_port
          | doc "Loopback OpenAI-compatible Mesh-LLM API port."
          | onix.Port
          | priority -5
          = 9337,
        console_port
          | doc "Loopback Mesh-LLM management API port."
          | onix.Port
          | priority -5
          = 3131,
        mesh_bind_address
          | doc "Explicit private interface address for Mesh-LLM QUIC transport."
          | String
          | priority -5
          = "0.0.0.0",
        mesh_bind_interface
          | doc "Interface whose global IPv4 address is resolved at start. Not ported: the interface launcher stays on Clan."
          | NotPorted "mesh_bind_interface (interface launcher)"
          | optional,
        mesh_port
          | doc "Fixed UDP port for private Mesh-LLM QUIC transport."
          | onix.Port
          | priority -5
          = 47916,
        mesh_name
          | doc "Friendly private mesh name."
          | onix.NonEmptyString
          | priority -5
          = "onix-private-inference",
        node_name
          | doc "Mesh-LLM node display name; defaults to the machine name."
          | onix.NonEmptyString
          | optional,
        backend_unit
          | doc "Local inference systemd unit ordered before the sidecar."
          | onix.NonEmptyString
          | optional,
        backend_externally_managed
          | doc "Declare that an external owner provides the loopback inference backend."
          | Bool
          | priority -5
          = false,
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let opt = fun field => if std.record.has_field field cfg then cfg."%{field}" else null in
      let instance = args.instance_name in
      let service_name = "mesh-llm-%{instance}" in
      let invites_artifact = "%{service_name}-invites" in
      let watchdog_name = "%{service_name}-api-watchdog" in
      let user = "mesh-llm" in
      let state_path = "/var/lib/%{service_name}" in
      let config_path = "/etc/%{service_name}/config.toml" in
      let research_config_path = "/etc/%{service_name}/research.json" in
      let is_joiner = cfg.mode == 'joiner in
      let node_name = if opt "node_name" == null then args.machine_name else cfg.node_name in
      let api_port = std.to_string cfg.api_port in
      let console_port = std.to_string cfg.console_port in

      # Join order (Clan default.nix): every other node, joiners first, the seed last.
      let node_names = std.record.fields cfg.mesh_nodes |> std.array.sort std.string.compare in
      let peers = node_names |> std.array.filter (fun n => n != args.machine_name) in
      let peer_is_joiner = fun n => mode_name cfg.mesh_nodes."%{n}" == "joiner" in
      let join_peers =
        if is_joiner then
          (peers |> std.array.filter peer_is_joiner) @ (peers |> std.array.filter (fun n => !(peer_is_joiner n)))
        else
          []
      in
      let credential = fun peer => "invite-%{peer}" in
      let credential_names = join_peers |> std.array.map credential in

      # Plugins: openai-endpoint (endpoint_url) plus extra endpoints, then research.
      let endpoint_urls =
        if cfg.endpoint_url != null && !(std.record.has_field "openai-endpoint" cfg.extra_endpoints) then
          std.record.insert "openai-endpoint" cfg.endpoint_url cfg.extra_endpoints
        else
          cfg.extra_endpoints
      in
      let endpoint_names = std.record.fields endpoint_urls |> std.array.sort std.string.compare in
      let research_enabled = cfg.research_mode != 'disabled in
      let arxiv_address = opt "research_arxiv_address" in
      let laya_address = opt "research_laya_address" in
      let research_json =
        if cfg.research_mode == 'provider then
          "{\"arxiv\":%{json arxiv_address},\"laya\":%{json laya_address},\"mode\":\"provider\"}"
        else
          "{\"mode\":\"forwarder\",\"target_peer\":%{json cfg.research_target_peer}}"
      in
      let endpoint_block = fun plugin =>
        let url = endpoint_urls."%{plugin}" in
        "[[plugin]]\nname = %{json plugin}\ncommand = \"openai-endpoint\"\nurl = %{json url}\n"
      in
      let endpoint_blocks = endpoint_names |> std.array.map endpoint_block |> std.string.join "\n" in
      let research_block =
        if research_enabled then
          "[[plugin]]\nname = \"research\"\ncommand = \"onix-mesh-research\"\nargs = [%{json research_config_path}]\n"
        else
          ""
      in
      let config_toml = "version = 1\n\n%{endpoint_blocks}%{research_block}" in

      let launch_args = [
        "--config",
        config_path,
        "--model",
        cfg.proxy_activation_model,
        "--ctx-size",
        std.to_string cfg.proxy_activation_context_size,
        "--headless",
        "--mesh-discovery-mode",
        "mdns",
        "--bind-ip",
        cfg.mesh_bind_address,
        "--bind-port",
        std.to_string cfg.mesh_port,
        "--port",
        api_port,
        "--console",
        console_port,
        "--mesh-name",
        cfg.mesh_name,
        "--name",
        node_name,
        "--log-format",
        "json",
      ]
      in
      let join_file_args =
        credential_names
        |> std.array.map (fun name => "--join-file \"$CREDENTIALS_DIRECTORY\"/%{shell_arg name}")
      in
      let start_script =
        std.string.join
          "\n"
          [
            "export LD_LIBRARY_PATH=\"$MESH_LLM_GCC_LIB/lib\"",
            "unset MESH_LLM_GCC_LIB",
            std.string.join " " (["exec mesh-llm", shell_args launch_args] @ join_file_args),
          ]
      in

      let watchdog_api = m%"
          set -o errexit -o nounset -o pipefail
          unit=%{service_name}.service
          failures_file=/run/%{watchdog_name}/failures
          if [ "$(systemctl show -p ActiveState --value "$unit")" != active ]; then
            rm -f "$failures_file" /run/%{watchdog_name}/peer-loss
            exit 0
          fi
          read -r uptime _ < /proc/uptime
          now=${uptime%.*}
          started=$(( $(systemctl show -p ActiveEnterTimestampMonotonic --value "$unit") / 1000000 ))
          if [ $(( now - started )) -lt 300 ]; then
            exit 0
          fi
          if ! timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/%{api_port}' 2>/dev/null; then
            failures=$(( $(cat "$failures_file" 2>/dev/null || echo 0) + 1 ))
            if [ "$failures" -lt 3 ]; then
              echo "$failures" > "$failures_file"
              echo "API listener 127.0.0.1:%{api_port} refused a connection ($failures/3)"
              exit 0
            fi
            rm -f "$failures_file"
            echo "API listener 127.0.0.1:%{api_port} refused 3 checks in a row; restarting $unit"
            systemctl restart "$unit"
            exit 0
          fi
          rm -f "$failures_file"
        "%
      in
      let watchdog_peers = m%"
          peer_loss_file=/run/%{watchdog_name}/peer-loss
          peer_restart_file=/run/%{watchdog_name}/peer-restart
          # An unanswered console says nothing about peers; only a reported empty list counts.
          if ! peers=$(curl -fsS -m 5 http://127.0.0.1:%{console_port}/api/status | jq -e '.peers | length'); then
            exit 0
          fi
          if [ "$peers" -gt 0 ]; then
            rm -f "$peer_loss_file"
            exit 0
          fi
          losses=$(( $(cat "$peer_loss_file" 2>/dev/null || echo 0) + 1 ))
          if [ "$losses" -lt 5 ]; then
            echo "$losses" > "$peer_loss_file"
            echo "joiner has no mesh peer ($losses/5)"
            exit 0
          fi
          last_restart=$(cat "$peer_restart_file" 2>/dev/null || echo 0)
          if [ "$last_restart" -gt 0 ] && [ $(( now - last_restart )) -lt 1800 ]; then
            echo "joiner has no mesh peer; the last rejoin restart was $(( now - last_restart )) s ago"
            exit 0
          fi
          rm -f "$peer_loss_file"
          echo "$now" > "$peer_restart_file"
          echo "joiner had no mesh peer for 5 checks in a row; restarting $unit to join its invites again"
          systemctl restart "$unit"
        "%
      in
      let watchdog_script = if is_joiner then "%{watchdog_api}\n%{watchdog_peers}" else watchdog_api in

      let backend_units = if opt "backend_unit" == null then [] else [cfg.backend_unit] in
      let research_backend_units = if cfg.research_mode == 'provider then cfg.research_backend_units else [] in
      let unit_deps = ["network-online.target"] @ backend_units @ research_backend_units in
      let backend_owned = backend_units != [] || cfg.backend_externally_managed in
      let has_endpoints = endpoint_names != [] in
      let wildcard = std.array.elem cfg.mesh_bind_address ["0.0.0.0", "::"] in
      let check = fun ok text => { assertion = ok, message = "%{service_name}: %{text}" } in
      let own_mode_listed =
        cfg.mesh_nodes == {}
        || (
          std.record.has_field args.machine_name cfg.mesh_nodes
          && mode_name cfg.mesh_nodes."%{args.machine_name}" == std.to_string cfg.mode
        )
      in
      let assertion_list = [
        check (!wildcard) "set exactly one private meshBindAddress or meshBindInterface.",
        check
          (wildcard || !(std.string.is_match "^127\\." cfg.mesh_bind_address || cfg.mesh_bind_address == "::1"))
          "meshBindAddress must be reachable by the other mesh node, not loopback.",
        check
          (endpoint_names |> std.array.all (fun n => std.string.is_match "^http://127\\.0\\.0\\.1:.*/v1$" endpoint_urls."%{n}"))
          "all endpoints must be loopback OpenAI-compatible /v1 endpoints.",
        check (!(std.record.has_field "openai-endpoint" cfg.extra_endpoints)) "extraEndpoints must not replace the primary openai-endpoint.",
        check (!(std.record.has_field "research" cfg.extra_endpoints)) "the research plugin name is reserved for native research operations.",
        check
          (cfg.research_mode != 'provider || arxiv_address != null || laya_address != null)
          "a research provider requires at least one configured backend.",
        check
          (cfg.research_mode != 'forwarder || std.string.is_match "^[0-9a-f]{64}$" cfg.research_target_peer)
          "a research forwarder requires the provider's full lowercase peer ID.",
        check (!has_endpoints || backend_owned) "a loopback backend requires backendUnit or explicit external ownership.",
        check (has_endpoints || !backend_owned) "a node without a local endpoint must not declare a backend.",
        check (!is_joiner || join_peers != []) "joiner mode requires at least one runtime invite token path.",
        check
          (credential_names |> std.array.all (fun name => std.string.is_match "^[a-zA-Z0-9_.-]+$" name))
          "invite tokens need distinct credential names and non-empty paths.",
        check own_mode_listed "mesh_nodes must list this machine with its own mode.",
        check (cfg.proxy_activation_model != "") "proxyActivationModel must name the CPU model that activates the plugin-aware proxy.",
        check (cfg.proxy_activation_context_size >= 512) "proxyActivationContextSize must be at least 512.",
        check
          (cfg.api_port != cfg.console_port && cfg.api_port != cfg.mesh_port && cfg.console_port != cfg.mesh_port)
          "apiPort, consolePort, and meshPort must be distinct.",
      ]
      in

      # One shared invite token per node, read from that node's /api/status.
      let placeholder_arg = shell_arg "Welcome to SOPS! Edit this file as you please!" in
      let generator_block = fun n =>
        m%"
          token="$(tr -d '\r\n' < "$prompts/%{n}")"
          if [ -z "$token" ] || [ "$token" = %{placeholder_arg} ]; then
            echo "Mesh-LLM invite token for %{n} is unset" >&2
            exit 1
          fi
          printf '%s' "$token" > "$out/%{n}"
        "%
      in
      let invites =
        if is_joiner && node_names != [] then
          onix.artifact_declaration {
            name = invites_artifact,
            shared = true,
            files = node_names |> std.array.map (fun n => { field = n, value = onix.artifact_file {} }) |> std.record.from_array,
            prompts =
              node_names
              |> std.array.map (fun n => { field = n, value = { description = "Invite token of %{n}'s Mesh-LLM sidecar (the token field of its /api/status)" } })
              |> std.record.from_array,
            generator_script = node_names |> std.array.map generator_block |> std.string.join "\n\n",
            description = "Mesh-LLM invite token of every %{instance} node",
          }
        else
          {}
      in
      # OnixOS applies a service's appended wirings in one mkMerge inside
      # systemd.services.<unit>, which the module system merges last-first.
      # Emitting them seed first loads the credentials in join order, as
      # Clan's LoadCredential does.
      let wiring =
        std.array.reverse join_peers
        |> std.array.map (fun peer =>
          onix.artifact_wiring {
            artifact = invites_artifact,
            file = peer,
            nixos_option = "systemd.services.%{service_name}.serviceConfig.LoadCredential",
            append = true,
            value = "%{credential peer}:__PATH__",
          }
        )
      in
      {
        output =
          {
            nixos = {
              assertions = assertion_list,
              environment.systemPackages = [args.packages.mesh-llm],
              environment.etc =
                { "%{service_name}/config.toml".text = config_toml }
                & (if research_enabled then { "%{service_name}/research.json".text = research_json } else {}),
              users.groups."%{user}" = {},
              users.users."%{user}" = { isSystemUser = true, group = user, home = state_path },
              systemd.tmpfiles.rules = ["Z %{state_path} - %{user} %{user} -"],
              systemd.services."%{service_name}" = {
                description = "Private Mesh-LLM sidecar (%{instance}, %{std.to_string cfg.mode})",
                wantedBy = ["multi-user.target"],
                wants = unit_deps,
                after = unit_deps,
                environment = {
                  HOME = state_path,
                  MESH_LLM_NO_SELF_UPDATE = "1",
                  # gcc lib output; the start script exports <it>/lib as LD_LIBRARY_PATH.
                  MESH_LLM_GCC_LIB = args.packages.lib,
                },
                path = [args.packages.mesh-llm, args.packages.mesh-research],
                script = start_script,
                restartTriggers = [config_toml] @ (if research_enabled then [research_json] else []),
                serviceConfig = {
                  Type = "simple",
                  User = user,
                  Group = user,
                  StateDirectory = service_name,
                  StateDirectoryMode = "0700",
                  WorkingDirectory = state_path,
                  Restart = "on-failure",
                  RestartSec = "10s",
                  TimeoutStopSec = "30s",
                  CapabilityBoundingSet = "",
                  LockPersonality = true,
                  MemoryDenyWriteExecute = false,
                  NoNewPrivileges = true,
                  PrivateDevices = true,
                  PrivateTmp = true,
                  ProtectClock = true,
                  ProtectControlGroups = true,
                  ProtectHome = true,
                  ProtectHostname = true,
                  ProtectKernelLogs = true,
                  ProtectKernelModules = true,
                  ProtectKernelTunables = true,
                  ProtectSystem = "strict",
                  RemoveIPC = true,
                  RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_UNIX"],
                  RestrictNamespaces = true,
                  RestrictRealtime = true,
                  RestrictSUIDSGID = true,
                  SystemCallArchitectures = "native",
                  UMask = "0077",
                },
              },
              systemd.services."%{watchdog_name}" = {
                description = "Restart %{service_name} when its API listener disappears or a joiner loses every peer",
                path = [args.packages.bash, args.packages.coreutils, args.packages.curl, args.packages.jq, args.packages.systemd],
                script = watchdog_script,
                serviceConfig = {
                  Type = "oneshot",
                  RuntimeDirectory = watchdog_name,
                  RuntimeDirectoryPreserve = "yes",
                },
              },
              systemd.timers."%{watchdog_name}" = {
                description = "Check the %{service_name} API listener every minute",
                wantedBy = ["timers.target"],
                timerConfig = { OnBootSec = "2min", OnUnitActiveSec = "1min", AccuracySec = "10s" },
              },
              networking.firewall.allowedUDPPorts = [cfg.mesh_port],
              # Research gateway is not ported, so nothing opens on tailscale0.
              networking.firewall.interfaces.tailscale0.allowedTCPPorts = [],
            },
            artifact_wiring = wiring,
          }
          & invites,
      },

    tests | not_exported =
      let defaults = interface.roles.default in
      let svc = "mesh-llm-mesh-llm-private-inference" in
      let nodes = { aspen1 = "seed", aspen2 = "joiner", aspen3 = "joiner", britton-desktop = "joiner" } in
      let aspen2_settings = {
        mode = "joiner",
        mesh_nodes = nodes,
        endpoint_url = null,
        mesh_bind_address = "100.82.25.30",
        research_mode = "provider",
        research_arxiv_address = "100.82.25.30:7998",
        research_laya_address = "100.82.25.30:7999",
        research_backend_units = ["arxiv-corpus-arxiv-aspen2.service", "laya-laya-aspen2.service"],
      }
      in
      let run = fun machine overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "mesh-llm",
              role_name = 'default,
              settings = defaults & overrides,
              instance_name = "mesh-llm-private-inference",
              machine_name = machine,
              packages = {
                mesh-llm = "mesh-llm-pkg",
                mesh-research = "mesh-research-pkg",
                lib = "gcc-lib-pkg",
                bash = "bash-pkg",
                coreutils = "coreutils-pkg",
                curl = "curl-pkg",
                jq = "jq-pkg",
                systemd = "systemd-pkg",
              },
            }
          )
        ).output
      in
      let failed = fun out => out.nixos.assertions |> std.array.filter (fun a => !a.assertion) |> std.array.map (fun a => a.message) in
      let joiner = run "aspen2" aspen2_settings in
      let unit = joiner.nixos.systemd.services.mesh-llm-mesh-llm-private-inference in
      let watchdog = joiner.nixos.systemd.services.mesh-llm-mesh-llm-private-inference-api-watchdog in
      let invites = joiner.artifacts.mesh-llm-mesh-llm-private-inference-invites in
      let seed =
        run
          "aspen1"
          {
            mode = "seed",
            mesh_nodes = nodes,
            mesh_bind_address = "100.100.103.95",
            backend_unit = "docker-diffusion-gemma.service",
            extra_endpoints = { spark = "http://127.0.0.1:18999/v1" },
          }
      in
      [
        defaults.mode == 'seed,
        defaults.endpoint_url == "http://127.0.0.1:13305/v1",
        defaults.mesh_port == 47916,
        failed joiner == [],
        unit.description == "Private Mesh-LLM sidecar (mesh-llm-private-inference, joiner)",
        unit.wants == ["network-online.target", "arxiv-corpus-arxiv-aspen2.service", "laya-laya-aspen2.service"],
        unit.after == unit.wants,
        unit.path == ["mesh-llm-pkg", "mesh-research-pkg"],
        unit.environment.MESH_LLM_GCC_LIB == "gcc-lib-pkg",
        std.string.contains "export LD_LIBRARY_PATH=\"$MESH_LLM_GCC_LIB/lib\"" unit.script,
        std.string.contains "exec mesh-llm --config /etc/mesh-llm-mesh-llm-private-inference/config.toml --model Qwen3-0.6B-Q4_K_M --ctx-size 512 --headless --mesh-discovery-mode mdns --bind-ip 100.82.25.30 --bind-port 47916 --port 9337 --console 3131 --mesh-name onix-private-inference --name aspen2 --log-format json" unit.script,
        # Clan join order: joiners first (sorted), the seed last.
        std.string.contains "--join-file \"$CREDENTIALS_DIRECTORY\"/invite-aspen3 --join-file \"$CREDENTIALS_DIRECTORY\"/invite-britton-desktop --join-file \"$CREDENTIALS_DIRECTORY\"/invite-aspen1" unit.script,
        # Wirings are emitted in reverse join order; OnixOS merges them
        # last-first, so LoadCredential lists the invites in join order.
        (joiner.artifact_wiring |> std.array.map (fun w => w.value)) == ["invite-aspen1:__PATH__", "invite-britton-desktop:__PATH__", "invite-aspen3:__PATH__"],
        (joiner.artifact_wiring |> std.array.map (fun w => w.file)) == ["aspen1", "britton-desktop", "aspen3"],
        (std.array.first joiner.artifact_wiring).nixos_option == "systemd.services.%{svc}.serviceConfig.LoadCredential",
        (std.array.first joiner.artifact_wiring).append,
        # The shared invites artifact has one file per node, including this one.
        invites.shared,
        (std.record.fields invites.files |> std.array.sort std.string.compare) == ["aspen1", "aspen2", "aspen3", "britton-desktop"],
        (std.record.fields invites.prompts |> std.array.sort std.string.compare) == ["aspen1", "aspen2", "aspen3", "britton-desktop"],
        invites.files.aspen1.secret,
        invites.files.aspen1.mode == "0400",
        invites.files.aspen1.owner == "root",
        std.string.contains "'Welcome to SOPS! Edit this file as you please!'" invites.generator_script,
        std.string.contains "> \"$out/britton-desktop\"" invites.generator_script,
        joiner.nixos.environment.etc."%{svc}/config.toml".text == "version = 1\n\n[[plugin]]\nname = \"research\"\ncommand = \"onix-mesh-research\"\nargs = [\"/etc/mesh-llm-mesh-llm-private-inference/research.json\"]\n",
        joiner.nixos.environment.etc."%{svc}/research.json".text == "{\"arxiv\":\"100.82.25.30:7998\",\"laya\":\"100.82.25.30:7999\",\"mode\":\"provider\"}",
        std.array.length unit.restartTriggers == 2,
        joiner.nixos.users.users.mesh-llm.home == "/var/lib/%{svc}",
        joiner.nixos.systemd.tmpfiles.rules == ["Z /var/lib/%{svc} - mesh-llm mesh-llm -"],
        joiner.nixos.environment.systemPackages == ["mesh-llm-pkg"],
        joiner.nixos.networking.firewall.allowedUDPPorts == [47916],
        # Research gateway off.
        joiner.nixos.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [],
        !(std.record.has_field "%{svc}-research-http" joiner.nixos.systemd.services),
        # Watchdog: joiners also restart on peer loss.
        std.string.contains "exec 3<>/dev/tcp/127.0.0.1/9337" watchdog.script,
        std.string.contains "http://127.0.0.1:3131/api/status" watchdog.script,
        watchdog.path == ["bash-pkg", "coreutils-pkg", "curl-pkg", "jq-pkg", "systemd-pkg"],
        watchdog.serviceConfig.RuntimeDirectoryPreserve == "yes",
        joiner.nixos.systemd.timers.mesh-llm-mesh-llm-private-inference-api-watchdog.timerConfig.OnUnitActiveSec == "1min",
        # A seed declares no invites, joins nobody and advertises its endpoints in name order.
        failed seed == [],
        !(std.record.has_field "artifacts" seed),
        seed.artifact_wiring == [],
        !(std.string.contains "--join-file" seed.nixos.systemd.services.mesh-llm-mesh-llm-private-inference.script),
        !(std.string.contains "peer-restart" seed.nixos.systemd.services.mesh-llm-mesh-llm-private-inference-api-watchdog.script),
        seed.nixos.systemd.services.mesh-llm-mesh-llm-private-inference.wants == ["network-online.target", "docker-diffusion-gemma.service"],
        seed.nixos.environment.etc."%{svc}/config.toml".text == "version = 1\n\n[[plugin]]\nname = \"openai-endpoint\"\ncommand = \"openai-endpoint\"\nurl = \"http://127.0.0.1:13305/v1\"\n\n[[plugin]]\nname = \"spark\"\ncommand = \"openai-endpoint\"\nurl = \"http://127.0.0.1:18999/v1\"\n",
        !(std.record.has_field "%{svc}/research.json" seed.nixos.environment.etc),
        # Clan's assertions still catch misconfiguration.
        std.array.elem "%{svc}: set exactly one private meshBindAddress or meshBindInterface." (failed (run "box" {})),
        std.array.elem "%{svc}: mesh_nodes must list this machine with its own mode." (failed (run "aspen2" (aspen2_settings & { mesh_nodes = nodes & { aspen2 | force = "seed" } }))),
        std.array.elem "%{svc}: a research forwarder requires the provider's full lowercase peer ID." (failed (run "aspen2" (aspen2_settings & { research_mode | force = "forwarder" }))),
        std.array.elem "%{svc}: joiner mode requires at least one runtime invite token path." (failed (run "aspen2" (aspen2_settings & { mesh_nodes | force = { aspen2 = "joiner" } }))),
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
