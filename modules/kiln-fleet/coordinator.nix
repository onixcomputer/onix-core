# The Kiln fleet coordinator (docs/kiln-fleet.md): `kiln-fleet run`, Kiln's
# claim authority and herdr dispatcher, on britton-desktop.
#
# Kiln runs as its own `kiln-fleet` account, apart from the agents' account,
# so dispatched agents cannot write its ledger, its verifier repositories or
# its scratch space; that separation is what Kiln's candidate capture checks.
# Kiln borrows the agents' account only to drive their herdr sessions,
# through one sudo rule for one fixed command. It fetches agent commits over
# ssh with its own key, which agent hosts accept only for git-upload-pack
# inside their Kiln worktrees, and it posts to the swarm as its own `kiln`
# account.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  swarm = import ../swarm-news/lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  swarmClient = config.onix.swarmNews;
  generators = config.clan.core.vars.generators;
  json = pkgs.formats.json { };
  toml = pkgs.formats.toml { };

  kilnPackages = inputs.kiln-fleet.packages.${pkgs.stdenv.hostPlatform.system};
  kilnFleet = kilnPackages.kiln-fleet;
  kilnCairn = kilnPackages.cairn;
  kilnCairnIntake = kilnPackages.kiln-cairn-intake;
  kilnImplementer = kilnPackages.kiln;
  agentAccount = config.users.users.${fleet.user};
  agentRuntimeDir = "/run/user/${toString agentAccount.uid}";
  stateDir = "/var/lib/${fleet.serviceUser}";
  stockSopsPlaceholder = "Welcome to SOPS! Edit this file as you please!";

  # herdr as the agents' account, with the environment their sessions use.
  # Kiln runs it from its own state directory, which that account cannot
  # enter, so start from the account's home.
  herdrAsAgents = pkgs.writeShellScript "kiln-fleet-herdr-as-${fleet.user}" ''
    cd ${agentAccount.home}
    export HOME=${agentAccount.home}
    export XDG_RUNTIME_DIR=${agentRuntimeDir}
    export SSH_AUTH_SOCK=${agentRuntimeDir}/yubikey-agent/yubikey-agent.sock
    export SHELL=/run/current-system/sw/bin/fish
    export PATH=/etc/profiles/per-user/${fleet.user}/bin:/run/current-system/sw/bin
    exec ${lib.getExe pkgs.herdr} "$@"
  '';
  herdrWrapper = pkgs.writeShellScript "kiln-fleet-herdr" ''
    exec /run/wrappers/bin/sudo -n -u ${fleet.user} ${herdrAsAgents} "$@"
  '';

  # git for capture: fetches agent commits with Kiln's own key.
  kilnGit = pkgs.writeShellScript "kiln-fleet-git" ''
    export GIT_SSH_COMMAND="${lib.getExe pkgs.openssh} -i ${generators.kiln-fleet-ssh.files.id_ed25519.path} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${stateDir}/known_hosts"
    exec ${lib.getExe pkgs.git} "$@"
  '';

  # Read-only Cairn snapshot helper run as the agents' account over a static
  # allowlist of declared repository checkouts. Outputs JSON on stdout only.
  cairnReadyCases = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: spec:
      let
        policyArg =
          if (spec.cairnPolicy or null) != null then
            ''if [ -f ${lib.escapeShellArg "${spec.checkout}/${spec.cairnPolicy}"} ]; then policy_args=(--policy ${lib.escapeShellArg "${spec.checkout}/${spec.cairnPolicy}"}); fi''
          else
            "";
      in
      ''
        ${lib.escapeShellArg name})
          repo_root=${lib.escapeShellArg spec.checkout}
          ${policyArg}
          ;;
      ''
    ) fleet.observedRepositories
  );
  cairnReadyAsAgents = pkgs.writeShellScript "kiln-fleet-cairn-ready-as-${fleet.user}" ''
    set -euo pipefail
    repo="''${1:-}"
    repo_root=""
    policy_args=()
    case "$repo" in
    ${cairnReadyCases}
      *)
        echo "kiln-fleet-cairn-ready: repository not allowlisted: $repo" >&2
        exit 64
        ;;
    esac
    if [ ! -d "$repo_root/.cairn/changes" ]; then
      exit 3
    fi
    exec ${kilnCairn}/bin/cairn implementation-ready --root "$repo_root" "''${policy_args[@]}"
  '';

  allEnrolledRepositories = lib.unique (
    lib.attrNames fleet.repositories ++ lib.attrNames fleet.observedRepositories
  );

  enrollment = json.generate "kiln-fleet-enrollment.json" {
    repositories = lib.unique (map lib.toLower allEnrolledRepositories);
    actors = fleet.enrolledActors;
  };

  slugFor = name: lib.replaceStrings [ "/" ] [ "__" ] name;

  cairnPolicyFor =
    name: spec:
    json.generate "kiln-cairn-policy-${slugFor name}.json" {
      repository = lib.toLower name;
      project = spec.project;
      actor = "operator";
      requested_outcome = "Observe and track Cairn changes for ${name}";
      acceptance = [
        {
          id = "cairn-verified";
          statement = "Verified against exact candidate and repository gates";
        }
      ];
      permitted_paths = [ ];
      permitted_effects = [ "write_source" ];
      verification_profile = builtins.hashString "sha256" "kiln-fleet-cairn-intake:${name}";
      budget = {
        attempts = 2;
        minutes_per_attempt = 60;
      };
      terminal_policy = "verified_pull_request";
      priority = 1;
    };

  githubIssuePolicyFor =
    name: spec:
    let
      parts = lib.splitString "/" name;
    in
    json.generate "kiln-github-policy-${slugFor name}.json" {
      repository = {
        owner = builtins.elemAt parts 0;
        repository = builtins.elemAt parts 1;
        repository_id = spec.githubId;
      };
      project = spec.project;
      requested_outcome = "Observe and track GitHub issues for ${name}";
      acceptance = [
        {
          id = "github-issue-verified";
          statement = "Verified against exact candidate and repository gates";
        }
      ];
      dependencies = [ ];
      permitted_paths = [ ];
      permitted_effects = [ "write_source" ];
      verification_profile = builtins.hashString "sha256" "kiln-fleet-github-poll:${name}";
      budget = {
        attempts = 2;
        minutes_per_attempt = 60;
      };
      terminal_policy = "verified_pull_request";
      priority = 1;
    };

  inventory = json.generate "kiln-fleet-inventory.json" {
    schema = "kiln.fleet-inventory.v1";
    executable = "${herdrWrapper}";
    session = fleet.herdrSession;
    environment = {
      home = stateDir;
      path = "/run/current-system/sw/bin";
    };
    machines = map (machine: {
      label = machine;
      herdr_machine = if machine == fleet.coordinator then null else fleet.herdrMachines.${machine};
      ssh_target = fleet.sshTargets.${machine};
      worktree_root = fleet.worktreeRoot machine;
      repositories = lib.filterAttrs (_: path: path != null) (
        lib.mapAttrs (_: repository: repository.checkouts.${machine} or null) fleet.repositories
      );
      agents = fleet.agents.${machine};
    }) fleet.agentHosts;
  };

  # Kiln's own swarm account; the server enrolls it from vars like a member.
  swarmFrom = "kiln on ${fleet.coordinator} <kiln@swarm.local>";
  swarmConfigFile =
    toml.generate "kiln-fleet-swarm.toml" {
      username = "kiln";
      from = swarmFrom;
      server = swarm.serverName;
      relays = false;
      password_file = generators.${swarm.passwordGenerator "kiln"}.files.password.path;
    }
    // lib.optionalAttrs (swarm.serverEndpointId != null) { server_id = swarm.serverEndpointId; };

  # Verifier authority per repository: a Kiln-owned bare repository and
  # scratch directory, the pinned git, and the agents' UID as the worker that
  # must not own either.
  authorityFor =
    name:
    let
      slug = lib.replaceStrings [ "/" ] [ "__" ] name;
    in
    pkgs.runCommand "kiln-fleet-authority-${slug}.json" { nativeBuildInputs = [ pkgs.b3sum ]; } ''
      git_blake3=$(b3sum --no-names ${lib.getExe pkgs.git})
      cat > "$out" <<EOF
      {
        "repository": "${name}",
        "repository_root": "${stateDir}/repositories/${slug}.git",
        "scratch_root": "${stateDir}/scratch/${slug}",
        "git": { "path": "${lib.getExe pkgs.git}", "blake3": "$git_blake3" },
        "worker_uid": ${toString agentAccount.uid}
      }
      EOF
    '';

  fleetConfig = json.generate "kiln-fleet.json" {
    schema = "kiln.fleet.v1";
    machine = fleet.coordinator;
    console_url = fleet.consoleUrl;
    listen = [
      "127.0.0.1:${toString fleet.port}"
      "${fleet.coordinatorAddress}:${toString fleet.port}"
    ];
    inherit (fleet) peers;
    operators = [ fleet.coordinator ];
    tailscale = lib.getExe pkgs.tailscale;
    implementer = {
      database = "${stateDir}/implementation.sqlite";
      enrollment = "${enrollment}";
    };
    inventory = "${inventory}";
    swarm = {
      enabled = true;
      executable = lib.getExe swarmClient.irohNewsPackage;
      state_dir = "${stateDir}/swarm";
      config_file = "${swarmConfigFile}";
      group = "bots.claims";
      from = swarmFrom;
      read_limit = 500;
      no_relays = true;
      # Kiln clears the client's environment, and iroh-news refuses to run
      # without HOME.
      environment.HOME = stateDir;
    };
    decision_group = "bots.general";
    capture = {
      git = "${kilnGit}";
      tar = lib.getExe pkgs.gnutar;
      export_root = "${stateDir}/exports";
      verification_profiles = "${stateDir}/verification-profiles";
      repositories = lib.mapAttrs (name: _: { authority = "${authorityFor name}"; }) fleet.repositories;
      verify_argv = null;
      publish_argv = null;
    };
    dispatch = {
      enabled = true;
      kinds = [ "omp" ];
    };
  };

  repositorySlugs = map (lib.replaceStrings [ "/" ] [ "__" ]) (lib.attrNames fleet.repositories);

  # Operator command: admit a Cairn `implementation-ready` snapshot into the
  # fleet's ledger, as the account that owns it.
  admit = pkgs.writeShellApplication {
    name = "kiln-fleet-admit";
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "kiln-fleet-admit: run as root; it admits as ${fleet.serviceUser}" >&2
        exit 2
      fi
      exec ${pkgs.util-linux}/bin/runuser -u ${fleet.serviceUser} -- \
        ${kilnPackages.kiln-cairn-intake}/bin/kiln-cairn-intake \
        --database ${stateDir}/implementation.sqlite --enrollment ${enrollment} "$@"
    '';
  };
in
{
  assertions = [
    {
      assertion = swarmClient.enable;
      message = "kiln-fleet: the coordinator mirrors to the swarm and must be a swarm-news member";
    }
    {
      assertion = swarm.serviceAccounts.kiln.machine == fleet.coordinator;
      message = "kiln-fleet: the swarm `kiln` account must live on the coordinator ${fleet.coordinator}";
    }
  ];

  users.users.${fleet.serviceUser} = {
    isSystemUser = true;
    group = fleet.serviceUser;
    home = stateDir;
    description = "Kiln fleet orchestration";
  };
  users.groups.${fleet.serviceUser} = { };
  environment.systemPackages = [ admit ];

  security.sudo.extraRules = [
    {
      users = [ fleet.serviceUser ];
      runAs = fleet.user;
      commands = [
        {
          command = "${herdrAsAgents}";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${cairnReadyAsAgents}";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  clan.core.vars.generators = {
    # Kiln's ssh key for fetching agent commits from agent hosts.
    kiln-fleet-ssh = {
      files.id_ed25519 = {
        owner = fleet.serviceUser;
        mode = "0400";
      };
      files."id_ed25519.pub".secret = false;
      runtimeInputs = [ pkgs.openssh ];
      script = ''
        ssh-keygen -q -t ed25519 -N "" -C "kiln-fleet@${fleet.coordinator}" -f "$out/id_ed25519"
      '';
    };
    # Optional read-only GitHub PAT for polling open issues of enrolled
    # repositories into /var/lib/kiln-fleet/implementation.sqlite.
    kiln-fleet-github-token = {
      files.token = {
        owner = fleet.serviceUser;
        mode = "0400";
      };
      prompts.token = {
        description = "Read-only GitHub PAT (Issues/Metadata read) for kiln-fleet issue polling";
        type = "hidden";
        persist = true;
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        tr -d '\r\n' < "$prompts/token" > "$out/token"
      '';
    };
    ${swarm.serviceIdentityGenerator "kiln"} = swarm.mkKeyGenerator {
      inherit pkgs;
      irohNews = swarmClient.irohNewsPackage;
      owner = fleet.serviceUser;
    };
    ${swarm.passwordGenerator "kiln"} = swarm.mkPasswordGenerator pkgs // {
      files.password = {
        owner = fleet.serviceUser;
        mode = "0400";
      };
    };
  };

  # The API answers on the tailnet; peers are named by `tailscale whois`.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ fleet.port ];

  systemd.services.kiln-fleet = {
    description = "Kiln fleet orchestration: claim authority and herdr dispatcher";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
      "herdr-kiln.service"
    ];
    wants = [
      "network-online.target"
      "herdr-kiln.service"
    ];
    # Tailscale may finish assigning coordinatorAddress several seconds after
    # boot; never give up permanently on transient bind races.
    unitConfig.StartLimitIntervalSec = 0;
    path = [
      pkgs.coreutils
      pkgs.iproute2
    ];
    serviceConfig = {
      User = fleet.serviceUser;
      Group = fleet.serviceUser;
      StateDirectory = fleet.serviceUser;
      StateDirectoryMode = "0711";
      UMask = "0077";
      ExecStartPre = pkgs.writeShellScript "kiln-fleet-prepare" ''
        set -eu
        cd ${stateDir}
        mkdir -p exports verification-profiles repositories swarm ${
          lib.concatMapStringsSep " " (slug: "scratch/${slug}") repositorySlugs
        }
        for slug in ${lib.concatStringsSep " " repositorySlugs}; do
          [ -d "repositories/$slug.git" ] || ${lib.getExe pkgs.git} init -q --bare "repositories/$slug.git"
        done
        ln -sfn ${
          generators.${swarm.serviceIdentityGenerator "kiln"}.files.secret-key.path
        } swarm/secret_key
        ${lib.getExe kilnFleet} check-config --config ${fleetConfig}
        # Wait up to 30s for Tailscale to assign the tailnet bind address.
        for _ in $(seq 1 30); do
          ${pkgs.iproute2}/bin/ip -4 addr show | ${pkgs.gnugrep}/bin/grep -Fq '${fleet.coordinatorAddress}/' && break
          sleep 1
        done
      '';
      ExecStart = "${lib.getExe kilnFleet} run --config ${fleetConfig}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Periodic Cairn implementation-ready intake for enrolled observed
  # repositories into the shared /var/lib/kiln-fleet/implementation.sqlite.
  systemd.services.kiln-fleet-cairn-intake = {
    description = "Kiln Fleet Cairn snapshot intake for enrolled repositories";
    after = [ "kiln-fleet.service" ];
    wants = [ "kiln-fleet.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = fleet.serviceUser;
      Group = fleet.serviceUser;
      RuntimeDirectory = "kiln-fleet-cairn-intake";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      ExecStart = pkgs.writeShellScript "kiln-fleet-cairn-intake-run" ''
        set -uo pipefail
        seq_base="$(${pkgs.coreutils}/bin/date +%s)"
        idx=0
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: spec:
            let
              slug = slugFor name;
              policyFile = cairnPolicyFor name spec;
            in
            ''
              idx=$((idx + 1))
              snap="$RUNTIME_DIRECTORY/${slug}.json"
              if /run/wrappers/bin/sudo -n -u ${fleet.user} ${cairnReadyAsAgents} ${lib.escapeShellArg name} > "$snap" 2>"$RUNTIME_DIRECTORY/${slug}.err"; then
                if ! ${kilnCairnIntake}/bin/kiln-cairn-intake \
                  --database ${stateDir}/implementation.sqlite \
                  --enrollment ${enrollment} \
                  --policy ${policyFile} \
                  --snapshot "$snap" \
                  --sequence "$((seq_base * 100 + idx))"; then
                  echo "kiln-fleet-cairn-intake: intake skipped/failed for ${name}" >&2
                fi
              else
                rc=$?
                if [ "$rc" -ne 3 ]; then
                  echo "kiln-fleet-cairn-intake: snapshot failed for ${name} (rc=$rc): $(${pkgs.coreutils}/bin/head -c 240 "$RUNTIME_DIRECTORY/${slug}.err")" >&2
                fi
              fi
              rm -f "$snap" "$RUNTIME_DIRECTORY/${slug}.err"
            ''
          ) fleet.observedRepositories
        )}
      '';
    };
  };

  systemd.timers.kiln-fleet-cairn-intake = {
    description = "Periodically admit Cairn snapshots into Kiln Fleet";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
  };

  # Periodic GitHub issue polling for enrolled repositories with a githubId
  # into /var/lib/kiln-fleet/implementation.sqlite. Skips cleanly if the Clan
  # prompt token has not been provisioned yet.
  systemd.services.kiln-fleet-github-poll = {
    description = "Kiln Fleet GitHub issue polling for enrolled repositories";
    after = [
      "network-online.target"
      "kiln-fleet.service"
    ];
    wants = [
      "network-online.target"
      "kiln-fleet.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = fleet.serviceUser;
      Group = fleet.serviceUser;
      UMask = "0077";
      LoadCredential = "github-token:${generators.kiln-fleet-github-token.files.token.path}";
      ExecStartPre = pkgs.writeShellScript "kiln-fleet-github-policy-check" ''
        set -euo pipefail
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: spec:
            lib.optionalString ((spec.githubId or null) != null) ''
              ${kilnImplementer}/bin/kiln-implementer policy-check --enrollment ${enrollment} --policy ${githubIssuePolicyFor name spec} >/dev/null
            ''
          ) fleet.observedRepositories
        )}
      '';
      ExecStart = pkgs.writeShellScript "kiln-fleet-github-poll-run" ''
        set -uo pipefail
        token_file="$CREDENTIALS_DIRECTORY/github-token"
        if [ ! -s "$token_file" ]; then
          echo "kiln-fleet-github-poll: token credential empty; skipping" >&2
          exit 0
        fi
        token_val="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$token_file")"
        if [ -z "$token_val" ] || [ "$token_val" = ${lib.escapeShellArg stockSopsPlaceholder} ]; then
          echo "kiln-fleet-github-poll: Clan var kiln-fleet-github-token unset; skipping" >&2
          exit 0
        fi
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            name: spec:
            lib.optionalString ((spec.githubId or null) != null) ''
              if ! ${kilnImplementer}/bin/kiln-implementer poll \
                --database ${stateDir}/implementation.sqlite \
                --enrollment ${enrollment} \
                --policy ${githubIssuePolicyFor name spec} \
                --secret-file "$token_file" \
                --max-pages 10 \
                --timeout-ms 30000; then
                echo "kiln-fleet-github-poll: poll failed for ${name}" >&2
              fi
            ''
          ) fleet.observedRepositories
        )}
      '';
    };
  };

  systemd.timers.kiln-fleet-github-poll = {
    description = "Periodically poll GitHub issues into Kiln Fleet";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "5min";
      Persistent = true;
    };
  };
}
