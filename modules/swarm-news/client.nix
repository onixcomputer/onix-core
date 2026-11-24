# The `swarm-news` command and the coordination skill. Works on NixOS and
# nix-darwin. Tagged NixOS members get their key and password from member.nix;
# other machines leave both null, let iroh-news create a key in the state
# directory, and are approved from the admin machine.
#
# It also brings each agent to the swarm: an always-on rule, a brief of the
# open claims at session start, and the `swarm-news` MCP server. Each goes
# where that agent reads it beside the user's own configuration.
{
  config,
  inputs,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.onix.swarmNews;
  swarm = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  irohNews = inputs.renews.packages.${pkgs.stdenv.hostPlatform.system}.iroh-news;

  clientConfig = (pkgs.formats.toml { }).generate "swarm-news.toml" (
    {
      inherit (cfg) username;
      from = "${cfg.username} <${cfg.username}@swarm.local>";
      # iroh-news keeps a new key and its password in SecretSpec when a
      # provider is configured. Slime uses the default project, `iroh-news`.
      secretspec_project = "swarm-news";
      # The server answers only on the tailnet, with no n0 relays. The
      # `_iroh-news` TXT record of swarm.blr.dev holds its ticket, and the
      # pinned server_id makes iroh-news refuse a record naming any other
      # endpoint.
      server = swarm.serverName;
      relays = false;
    }
    // lib.optionalAttrs (swarm.serverEndpointId != null) {
      server_id = swarm.serverEndpointId;
    }
    // lib.optionalAttrs (cfg.passwordFile != null) { password_file = cfg.passwordFile; }
  );

  swarmNews = pkgs.writeShellApplication {
    name = "swarm-news";
    runtimeInputs = [
      irohNews
      pkgs.coreutils
    ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/swarm-news"
      mkdir -p "$state"
      chmod 0700 "$state"
      ${lib.optionalString (cfg.secretKeyFile != null) ''
        # Without a readable key, iroh-news would replace the link with a new,
        # unregistered key.
        key=${lib.escapeShellArg cfg.secretKeyFile}
        if [ ! -r "$key" ]; then
          echo "swarm-news: cannot read $key; deploy this machine's ${swarm.identityGenerator} vars" >&2
          exit 1
        fi
        ln -sfn "$key" "$state/secret_key"
      ''}
      # A slime setup in the environment must not redirect swarm posts.
      unset IROH_NEWS_SERVER IROH_NEWS_USERNAME IROH_NEWS_PASSWORD IROH_NEWS_PASSWORD_FILE \
        IROH_NEWS_FROM IROH_NEWS_STATE IROH_NEWS_DISCOVERY
      # Every agent on a machine shares the account address, and Kiln decides
      # whether an open claim is the claimant's own by comparing that address.
      # `SWARM_SESSION` gives a post a per-session address under the same
      # account, using a 12-hex SHA-256 tag so long labels (e.g.
      # `antigravity on britton-desktop, session <id>`) never collide by prefix.
      if [ -n "''${SWARM_SESSION:-}" ]; then
        slug=$(printf '%s' "$SWARM_SESSION" | sha256sum | cut -c1-12)
        export IROH_NEWS_FROM="$SWARM_SESSION <${cfg.username}+$slug@swarm.local>"
      fi
      exec iroh-news --config ${clientConfig} --state-dir "$state" "$@"
    '';
  };

  # Commands the agents' files name; stable across generations.
  bin = "/run/current-system/sw/bin";

  brief = pkgs.writeShellApplication {
    name = "swarm-news-brief";
    runtimeInputs = [
      swarmNews
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = builtins.readFile ./brief.sh;
  };

  # Claim and release hygiene over the recent stream; see audit.sh.
  audit = pkgs.writeShellApplication {
    name = "swarm-news-audit";
    runtimeInputs = [
      swarmNews
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./audit.sh;
  };

  agentSetup = pkgs.writeShellApplication {
    name = "swarm-news-agent-setup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./agent-setup.sh;
  };

  rule = builtins.readFile ./RULE.md;
  ruleSummary = "Coordinate with Britton's other coding agents through the swarm before shared or long-running work.";

  ompExtension = pkgs.runCommand "omp-swarm-brief" { } ''
    mkdir -p "$out"
    substitute ${./omp-swarm-brief.ts} "$out/index.ts" --replace-fail @brief@ ${bin}/swarm-news-brief
  '';

  # Claude Code and Codex add the brief's plain stdout to the session's
  # context. Without a matcher it runs for every session source: startup,
  # resume, clear, compact and fork.
  sessionStartHooks = [
    {
      hooks = [
        {
          type = "command";
          command = "${bin}/swarm-news-brief";
          timeout = 20;
        }
      ];
    }
  ];

  # Every MCP server the agents get: swarm-news plus those other modules add
  # (Kiln's fleet API).
  mcpServers = {
    swarm-news = {
      command = "${bin}/swarm-news";
      args = [
        "mcp"
        "--no-shared-cursor"
      ];
    };
  }
  // cfg.agentMcpServers;
  mcpServersFile = pkgs.writeText "agent-mcp-servers.json" (builtins.toJSON mcpServers);

  # Codex's system layer sits under ~/.codex/config.toml; tables such as
  # mcp_servers merge with the user's.
  codexConfig = (pkgs.formats.toml { }).generate "codex-config.toml" {
    developer_instructions = rule;
    mcp_servers = mcpServers;
  };

  skillPaths = [
    # OMP and Codex
    ".agents/skills/swarm/SKILL.md"
    # Claude Code
    ".claude/skills/swarm/SKILL.md"
    # Antigravity, CLI, and IDE
    ".gemini/config/skills/swarm/SKILL.md"
  ];
in
{
  options.onix.swarmNews = {
    enable = lib.mkEnableOption "the swarm-news client and coordination skill";

    username = lib.mkOption {
      type = lib.types.strMatching "[a-z0-9-]+";
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "NNTP account on the swarm server; one per machine.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = swarm.user;
      description = "Account whose agents use the swarm and receive the skill.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Clan-vars iroh endpoint key linked into the state directory. Null lets
        iroh-news create a key there, which must then be approved from the
        admin machine with `swarm-news admin approve-join`.
      '';
    };

    passwordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "NNTP password file for a declared account. Approved endpoints need none.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = swarmNews;
      description = "The `swarm-news` wrapper.";
    };

    clientConfigFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = clientConfig;
      description = "This machine's iroh-news client config for the swarm; Kiln's mirror reuses it with its own From address.";
    };

    irohNewsPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = irohNews;
      description = "The iroh-news build the swarm client runs.";
    };

    agentMcpServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              description = "Absolute command that starts the stdio MCP server.";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments after the command.";
            };
          };
        }
      );
      default = { };
      description = "Further stdio MCP servers registered with every agent beside `swarm-news`.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      assertions = [
        {
          assertion = swarm.serverEndpointId != null;
          message = "swarm-news: ${swarm.serverMachine} has no server endpoint id; run `clan vars generate ${swarm.serverMachine} --generator ${swarm.serverGenerator}`";
        }
      ];

      environment.systemPackages = [
        swarmNews
        brief
        audit
      ];

      # Codex runs /etc/codex hooks as managed, without asking the user to
      # trust them. Claude Code merges hooks from its managed-settings.d
      # drop-ins with every other settings level; on macOS that directory is
      # under /Library, which nix-darwin's /etc cannot reach.
      environment.etc = {
        "codex/config.toml".source = codexConfig;
        "codex/hooks.json".text = builtins.toJSON {
          hooks.SessionStart = sessionStartHooks;
        };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        "claude-code/managed-settings.d/50-swarm-news.json".text = builtins.toJSON {
          hooks.SessionStart = sessionStartHooks;
        };
      };
    }
    // lib.optionalAttrs (options ? home-manager) {
      home-manager.users.${cfg.user} =
        { lib, ... }:
        {
          home.file =
            lib.genAttrs skillPaths (_: {
              source = ./SKILL.md;
            })
            // {
              ".omp/agent/rules/swarm.md".text = ''
                ---
                description: ${ruleSummary}
                alwaysApply: true
                agents: [main]
                ---

                ${rule}'';
              ".omp/agent/extensions/swarm-brief".source = ompExtension;
              ".claude/rules/swarm.md".text = rule;
              ".gemini/config/rules/swarm.md".text = ''
                ---
                trigger: always_on
                description: ${ruleSummary}
                ---

                ${rule}'';
            };

          # MCP entries and the Antigravity hook live in files the agents also
          # write, so they are merged in rather than linked.
          home.activation.swarmNewsAgents = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run ${lib.getExe agentSetup} ${mcpServersFile} ${bin}/swarm-news-brief || true
          '';
        };
    }
  );
}
