# r[impl onix.kiln_implementation.authority]
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.services.kiln-implementer;
  name = cfg.runtimeName;
  root = "/var/lib/${name}";
  file = leaf: "${cfg.configuration}/${leaf}";
  template = leaf: "${cfg.attemptBundle}/${leaf}";
  bindingArgs = [
    "--bundle"
    (toString cfg.attemptBundle)
    "--cohort"
    (toString cfg.cohort)
    "--configuration"
    (toString cfg.configuration)
    "--state-root"
    root
    "--coordinator-uid"
    (toString cfg.coordinatorUid)
  ];
  resolveBinding = phase: ''
    resolved="$(${qualification}/bin/kiln-implementation-qualify binding-path ${lib.escapeShellArgs bindingArgs} --stage ${phase})"
    binding="$(printf '%s' "$resolved" | ${pkgs.jq}/bin/jq -er .path)"
    attempt="$(printf '%s' "$resolved" | ${pkgs.jq}/bin/jq -er .attempt)"
    fence="$(printf '%s' "$resolved" | ${pkgs.jq}/bin/jq -er .fence)"
  '';
  commonArgs = [
    "--database"
    "${root}/kiln/work.sqlite"
    "--enrollment"
    (file "enrollment.json")
  ];
  executable = "${cfg.cohort}/environment/bin/kiln-implementer";
  qualification = import ./qualification-package.nix { inherit pkgs; };
  # The dispatcher passes exactly this variable to Lattice's host-side model
  # broker (Kiln worker.rs); the sandboxed worker never receives it.
  modelCredentialEnv = "KILN_IMPLEMENTATION_MODEL_KEY";
  credentialArgs = lib.optionals (cfg.modelCredential != null) [
    "--model-credential-env"
    modelCredentialEnv
  ];
  credentialPaths = [
    cfg.intakeCredential
    cfg.publisherCredential
  ]
  ++ lib.optional (cfg.modelCredential != null) cfg.modelCredential;
  # Kiln's explicit local-operator authority for admission-bound commands.
  operatorArgs = lib.optionals (cfg.localOperator != null) [
    "--local-operator"
    cfg.localOperator
  ];
  hostOwnerArgs = operatorArgs ++ [
    "--profile"
    (file "host-owner.json")
  ];
  # Kiln's implementation authority (Kiln docs/implementation-runbook.md,
  # "Select implementation authority first"): every command reaching a
  # protected operation — claim, dispatch, candidate submission, verification
  # admission, publication — gets the deployment's selection. Script-based
  # stages end in "$@", so the selection stays visible in ExecStart.
  protected =
    unit:
    lib.recursiveUpdate unit {
      serviceConfig.ExecStart = lib.concatStringsSep " " (
        [ unit.serviceConfig.ExecStart ] ++ map lib.escapeShellArg operatorArgs
      );
    };
  # Registered host-local owner (Kiln config/fair-admission-host-owner.ncl).
  # Reserve/release bind the exact retained claim, re-read from the owner.
  hostOwnerClaimStage =
    command:
    lib.recursiveUpdate (stage command [ ]) {
      serviceConfig.ExecStart = toString (
        pkgs.writeShellScript "${name}-${command}-claimed" ''
          set -eu
          current="$(${qualification}/bin/kiln-implementation-qualify current-claim ${lib.escapeShellArgs bindingArgs})"
          attempt="$(printf '%s' "$current" | ${pkgs.jq}/bin/jq -er .attempt)"
          fence="$(printf '%s' "$current" | ${pkgs.jq}/bin/jq -er .fence)"
          exec ${lib.escapeShellArg executable} ${command} ${
            lib.escapeShellArgs (
              commonArgs
              ++ [
                "--profile"
                (file "host-owner.json")
              ]
            )
          } \
            --attempt "$attempt" --fence "$fence" "$@"
        ''
      );
    };
  policyCheck = lib.escapeShellArgs (
    [
      "${qualification}/bin/kiln-implementation-qualify"
      "policy"
      "--configuration"
      (toString cfg.configuration)
      "--cohort"
      (toString cfg.cohort)
      "--state-root"
      root
    ]
    ++ lib.concatMap (repo: [
      "--repository"
      repo
    ]) cfg.repositories
    ++ lib.concatMap (workClass: [
      "--work-class"
      workClass
    ]) cfg.workClasses
  );
  hardening = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    CapabilityBoundingSet = "";
    UMask = "0007";
    MemoryMax = "${toString cfg.memoryMaxMiB}M";
    CPUQuota = "${toString cfg.cpuQuotaPercent}%";
    TasksMax = cfg.tasksMax;
    TimeoutStartSec = cfg.timeoutSeconds;
    TimeoutStopSec = 30;
    KillMode = "control-group";
    Restart = "no";
    RestrictAddressFamilies = [ "AF_UNIX" ];
    PrivateNetwork = true;
    # Credential source directories are hidden from every stage; systemd's
    # LoadCredential copies only the one file a stage needs.
    InaccessiblePaths = [
      "-/run/secrets"
      "-/root"
      "-/home"
    ]
    ++ map (path: "-${builtins.dirOf path}") credentialPaths;
  };
  stage =
    command: args:
    let
      role =
        if command == "publish" then
          "publisher"
        else if
          builtins.elem command [
            "verify"
            "capture-candidate"
          ]
        then
          "verifier"
        else
          "coordinator";
    in
    {
      description = "Explicit Kiln implementation stage ${command}";
      requires = [ "${name}-policy-check.service" ];
      after = [ "${name}-policy-check.service" ];
      serviceConfig = hardening // {
        Type = "oneshot";
        User = "${name}-${role}";
        Group = "${name}-ledger";
        ReadWritePaths = [ "${root}/kiln" ];
        LogsDirectory = "${name}-${role}";
        LogsDirectoryMode = "0700";
        StandardOutput = "append:/var/log/${name}-${role}/${command}.jsonl";
        StandardError = "append:/var/log/${name}-${role}/${command}.stderr";
        ExecStart = lib.escapeShellArgs (
          [
            executable
            command
          ]
          ++ commonArgs
          ++ args
        );
      };
    };
  boundStage =
    command: phase: arguments:
    lib.recursiveUpdate (stage command [ ]) {
      serviceConfig.ExecStart = toString (
        pkgs.writeShellScript "${name}-${command}-bound" ''
          set -eu
          ${resolveBinding phase}
          exec ${lib.escapeShellArg executable} ${command} ${lib.escapeShellArgs commonArgs} ${arguments} "$@"
        ''
      );
    };
  # Each controller unit runs Kiln as the coordinator (User=) and seals
  # protected state in "!" phases: root in the same sandbox, no account
  # switch. NoNewPrivileges stays on and no phase needs CAP_SETUID/CAP_SETGID;
  # the phases hand off through the root-owned sticky controller spool.
  # A phase is a `--phase` value ("!" prefix: root), or "" for none.
  controllerStage = command: phases: arguments: {
    description = "Retain trusted Kiln ${command} artifacts from the actual current owner";
    requires = [ "${name}-policy-check.service" ];
    after = [ "${name}-policy-check.service" ];
    serviceConfig = hardening // {
      Type = "oneshot";
      User = "${name}-coordinator";
      Group = "${name}-ledger";
      CapabilityBoundingSet = [
        "CAP_CHOWN"
        "CAP_DAC_OVERRIDE"
        "CAP_FOWNER"
      ];
      ReadWritePaths = [
        "${root}/kiln"
        "${root}/controller"
        "${root}/controller-spool"
        "${root}/workspaces"
        "${root}/publication-source"
      ];
      ExecStart = map (
        phase:
        let
          selected = lib.removePrefix "!" phase;
        in
        lib.optionalString (lib.hasPrefix "!" phase) "!"
        + lib.escapeShellArgs (
          [
            "${qualification}/bin/kiln-implementation-qualify"
            command
          ]
          ++ bindingArgs
          ++ arguments
          ++ lib.optionals (selected != "") [
            "--phase"
            selected
          ]
        )
      ) phases;
    };
  };
  remote =
    credential: unit:
    lib.recursiveUpdate unit {
      serviceConfig = {
        PrivateNetwork = false;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        LoadCredential = [ "github:${credential}" ];
      };
    };
  boundAttempt = ''
    ${resolveBinding "dispatch"}
    case "$INVOCATION_ID" in *[!0-9a-f]*|"") exit 2;; esac
    ${qualification}/bin/kiln-implementation-qualify verifier-authority \
      --authority "$binding/verifier-authority.json" \
      --root ${lib.escapeShellArg root} --worker-uid ${toString cfg.executorUid} --cohort ${lib.escapeShellArg (toString cfg.cohort)}
  '';
  verifyCommand = pkgs.writeShellScript "${name}-verify-candidate" ''
    set -eu
    ${boundAttempt}
    exec ${lib.escapeShellArg "${cfg.cohort}/environment/bin/kiln-web-service"} verify-implementation \
      --profile ${lib.escapeShellArg (toString cfg.ciServiceProfile)} ${lib.escapeShellArgs commonArgs} \
      --attempt "$attempt" --fence "$fence" \
      --verification-profile "$binding/verification-profile.json" \
      --authority "$binding/verifier-authority.json" "$@"
  '';
  captureCommand = pkgs.writeShellScript "${name}-capture-candidate" ''
    set -eu
    ${boundAttempt}
    exported=${lib.escapeShellArg "${root}/candidate-export"}/"$attempt-$fence"
    exec ${lib.escapeShellArg executable} capture-candidate ${lib.escapeShellArgs commonArgs} \
      --attempt "$attempt" --fence "$fence" --dispatch-plan "$binding/dispatch-plan.json" \
      --profile "$binding/verification-profile.json" \
      --authority "$binding/verifier-authority.json" \
      --candidate-root "$exported/candidate" --host-receipt "$exported/host-receipt.json" \
      --handoff-output ${lib.escapeShellArg "${root}/verifier/reports"}/"$attempt-$fence.handoff.json" "$@"
  '';
  verifierStage =
    command: script:
    lib.recursiveUpdate (stage command [ ]) {
      serviceConfig = {
        User = "${name}-verifier";
        SupplementaryGroups = lib.optional (command == "capture-candidate") "${name}-capture";
        ReadWritePaths = [
          "${root}/kiln"
          "${root}/verifier"
        ]
        ++ lib.optionals (command == "verify") cfg.canonicalCiStatePaths;
        ExecStart = toString script;
      };
    };
  # Canonical CI service enrollment. Kiln's verification refuses a project the
  # service state has not enrolled (kiln-web-service engine/verification.rs),
  # and enrollment exists only as the service's authenticated Projects intake,
  # POST /api/projects with the operator token (engine/api.rs, docs/operator.md
  # "Install reviewed profiles and authority"). The service state has one owner
  # at a time (engine/storage.rs StateLock: "service state already has an
  # owner"), and verify-implementation opens that same state itself, so
  # `serve` runs only inside the enrollment step, never beside verify.
  ciRuntime = "/run/${name}-ci";
  ciProfile = lib.escapeShellArg (toString cfg.ciServiceProfile);
  # Private TLS 1.3 key/certificate and distinct operator/worker tokens at the
  # profile's paths: 64 hex bytes, no newline, owner-only, created atomically
  # and kept when present (Kiln docs/operator.md token and key rules).
  ciCredentials = pkgs.writeShellScript "${name}-ci-credentials" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
        pkgs.openssl
      ]
    }
    umask 077
    runtime=${lib.escapeShellArg ciRuntime}
    within() {
      value="$(jq -er "$1" ${ciProfile})"
      case "$value" in "$runtime"/*) printf '%s' "$value" ;; *) echo "CI service $1 is outside $runtime" >&2; exit 1 ;; esac
    }
    certificate="$(within .tls.certificate_path)"
    key="$(within .tls.private_key_path)"
    operator="$(within .operator_token_file)"
    worker="$(within .worker_token_file)"
    for token in "$operator" "$worker"; do
      if ! test -s "$token"; then
        temporary="$(mktemp "$runtime/.token.XXXXXX")"
        openssl rand -hex 32 | tr -d '\n' > "$temporary"
        chmod 0600 "$temporary"
        mv -T "$temporary" "$token"
      fi
    done
    if ! test -s "$certificate" || ! test -s "$key"; then
      scratch="$(mktemp -d "$runtime/.tls.XXXXXX")"
      openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 30 \
        -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1 \
        -keyout "$scratch/key.pem" -out "$scratch/certificate.pem" 2> /dev/null
      chmod 0600 "$scratch/key.pem" "$scratch/certificate.pem"
      mv -T "$scratch/key.pem" "$key"
      mv -T "$scratch/certificate.pem" "$certificate"
      rmdir "$scratch"
    fi
  '';
  # Idempotent: enroll each allowlisted project only when the service does not
  # already list it, through the real HTTPS intake (Host/Origin/JSON/bearer as
  # kiln-web-service server.rs requires), then stop the service.
  ciEnroll = pkgs.writeShellScript "${name}-ci-enroll" ''
    set -eu
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.jq
        pkgs.curl
      ]
    }
    service=${lib.escapeShellArg "${cfg.cohort}/environment/bin/kiln-web-service"}
    "$service" check --profile ${ciProfile}
    origin="$(jq -er .origin ${ciProfile})"
    host="''${origin#https://}"
    listen="$(jq -er .listen_address ${ciProfile})"
    certificate="$(jq -er .tls.certificate_path ${ciProfile})"
    headers="$(mktemp)"
    printf 'Authorization: Bearer %s\n' "$(cat "$(jq -er .operator_token_file ${ciProfile})")" > "$headers"
    api() {
      curl --silent --show-error --fail-with-body --max-time 10 --cacert "$certificate" \
        --connect-to "$host:$listen" -H @"$headers" "$@"
    }
    enrolled() { printf '%s' "$projects" | jq -e --arg id "$1" 'any(.enrolled[]; .id == $id)' > /dev/null; }
    "$service" serve --profile ${ciProfile} &
    server=$!
    trap 'kill -TERM "$server" 2> /dev/null || true; wait "$server" || true; rm -f "$headers"' EXIT
    projects=""
    for _ in $(seq 1 60); do
      if projects="$(api "https://$host/api/projects" 2> /dev/null)"; then break; fi
      kill -0 "$server"
      sleep 1
    done
    test -n "$projects"
    for project in $(jq -r '.projects[].id' ${ciProfile}); do
      if enrolled "$project"; then
        echo "$project: already enrolled"
        continue
      fi
      api -X POST -H "Origin: $origin" -H "Content-Type: application/json" \
        --data "$(jq -cn --arg project "$project" '{request_id: ("onix-enroll-" + $project), project_id: $project}')" \
        "https://$host/api/projects" > /dev/null
      echo "$project: enrolled"
    done
    projects="$(api "https://$host/api/projects")"
    for project in $(jq -r '.projects[].id' ${ciProfile}); do enrolled "$project"; done
  '';
  dispatcher = recovery: {
    description = "Bounded current-grant Kiln dispatch through the actual Lattice OMP executor";
    requires = [ "${name}-policy-check.service" ];
    after = [ "${name}-policy-check.service" ];
    # The trusted fixed host dispatcher needs the ledger. Its coding child has
    # only mandatory bwrap source grants, not host state/credential mounts.
    # The executor account itself is NOT enrolled in the ledger group.
    serviceConfig =
      hardening
      // {
        Type = "oneshot";
        User = "${name}-executor";
        Group = "${name}-ledger";
        WorkingDirectory = "${root}/workspaces";
        ReadWritePaths = [
          "${root}/kiln"
          "${root}/workspaces"
          "${root}/lattice"
        ];
        LogsDirectory = "${name}-executor";
        LogsDirectoryMode = "0700";
        StandardOutput = "append:/var/log/${name}-executor/dispatch.jsonl";
        StandardError = "append:/var/log/${name}-executor/dispatch.stderr";
        # Lattice v3: the worker has no network device. This namespace is only
        # the trusted host broker's route to the admitted model endpoint.
        PrivateNetwork = cfg.modelNetworkNamespace == null;
        # Lattice launches the worker as a child of this unit, under bwrap
        # (unshare user/pid/ipc/uts/cgroup/net, fresh /proc). Probed minimum: bwrap
        # needs AF_NETLINK to bring up loopback in its private network namespace,
        # and a fresh procfs mount, which the kernel refuses while
        # ProtectKernelTunables' read-only overmounts under /proc exist. Every
        # other setting stays; see the README's worker-sandbox note.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_NETLINK"
        ]
        ++ lib.optionals (cfg.modelNetworkNamespace != null) [
          "AF_INET"
          "AF_INET6"
        ];
        ProtectKernelTunables = false;
        ExecStartPre = lib.escapeShellArgs (
          [
            "${qualification}/bin/kiln-implementation-qualify"
            "check-attempt"
            "--workspace-parent"
            "${root}/workspaces"
          ]
          ++ bindingArgs
          ++ credentialArgs
        );
        ExecStart = toString (
          pkgs.writeShellScript "${name}-${if recovery then "recover-dispatch" else "dispatch"}-bound" ''
            set -eu
            ${resolveBinding "dispatch"}
            ${lib.optionalString (cfg.modelCredential != null && !recovery) ''
              ${modelCredentialEnv}="$(cat "$CREDENTIALS_DIRECTORY/model")"
              export ${modelCredentialEnv}
            ''}
            exec ${cfg.cohort}/environment/bin/kiln-lattice-dispatch ${lib.escapeShellArgs commonArgs} \
              --worker-request "$binding/attempt.json" --worker-transport-profile ${lib.escapeShellArg (file "worker-transport-profile.json")} \
              --dispatch-plan "$binding/dispatch-plan.json" --admission-observations "$binding/admission-observations.json" \
              ${lib.optionalString recovery "--recover true"} "$@"
          ''
        );
      }
      // lib.optionalAttrs (cfg.modelNetworkNamespace != null) {
        NetworkNamespacePath = cfg.modelNetworkNamespace;
      }
      // lib.optionalAttrs (cfg.modelCredential != null && !recovery) {
        LoadCredential = [ "model:${cfg.modelCredential}" ];
      };
  };
  safePath =
    path:
    lib.hasPrefix "/" path
    && !(lib.hasInfix "/../" path)
    && !(lib.hasSuffix "/.." path)
    && !(lib.hasInfix "/./" path);
in
{
  options.services.kiln-implementer = {
    enable = lib.mkEnableOption "explicit bounded Kiln implementation stages";
    selectedCampaignEnable = lib.mkEnableOption "operator-started selected Cairn campaign driving";
    selectedCampaignProfile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Typed immutable native campaign drive profile";
    };
    selectedCampaignId = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    selectedCampaignDatabase = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Existing canonical campaign database; this module never creates it";
    };
    selectedImplementationDatabase = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Existing canonical implementation database";
    };
    selectedCampaignBoundInputDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Owned campaign binding root, root-owned setgid 02770 in executor data group";
    };
    selectedCampaignCandidateExportDirectory = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Owned candidate-export root, root-owned setgid 02770 in executor data group";
    };
    selectedCampaignWorkspaceRoot = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Owned campaign workspace parent, root-owned 0750 in executor data group";
    };
    selectedCampaignDataGid = mkOption {
      type = types.nullOr (types.ints.between 100 999);
      default = null;
      description = "Explicit numeric executor data group shared by native campaign roles";
    };
    selectedCampaignNetworkNamespace = mkOption {
      type = types.nullOr (types.strMatching "/run/netns/[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}");
      default = null;
      description = "Existing explicitly qualified namespace for campaign delivery effects; no host-network fallback";
    };
    selectedCampaignCredentialPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Existing separately owned publisher credential file; no LoadCredential copy";
    };
    runtimeName = mkOption {
      type = types.strMatching "[a-z][a-z0-9-]{0,19}";
      default = "kiln-implementation";
    };
    cohort = mkOption {
      type = types.nullOr (types.either types.package types.path);
      default = null;
      description = "Exact built cohort; no implicit canary pin adoption";
    };
    configuration = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Immutable typed policy/worker transport bundle, no secrets";
    };
    attemptBundle = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Immutable typed source/check/program templates; claim/lease/request bindings are controller-owned runtime artifacts";
    };
    intakeCredential = mkOption {
      type = types.str;
      description = "Runtime scoped read-only intake token path";
    };
    publisherCredential = mkOption {
      type = types.str;
      description = "Separate runtime PR publisher token path";
    };
    ciServiceProfile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Explicit existing per-repository canonical CI service profile; no shadow Engine";
    };
    canonicalCiStatePaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Existing canonical Engine state roots the verifier is separately authorized to write; no ownership change or restart";
    };
    repositories = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    workClasses = mkOption {
      type = types.listOf (
        types.enum [
          "bug"
          "bounded-feature"
        ]
      );
      default = [ ];
    };
    coordinatorUid = mkOption {
      type = types.ints.between 100 999;
      default = 930;
    };
    executorUid = mkOption {
      type = types.ints.between 100 999;
      default = 931;
    };
    publisherUid = mkOption {
      type = types.ints.between 100 999;
      default = 932;
    };
    verifierUid = mkOption {
      type = types.ints.between 100 999;
      default = 933;
    };
    memoryMaxMiB = mkOption {
      type = types.ints.between 128 32768;
      default = 4096;
    };
    cpuQuotaPercent = mkOption {
      type = types.ints.between 1 800;
      default = 200;
    };
    tasksMax = mkOption {
      type = types.ints.between 1 1024;
      default = 256;
    };
    timeoutSeconds = mkOption {
      type = types.ints.between 1 86400;
      default = 3600;
    };
    maximumPages = mkOption {
      type = types.ints.between 1 20;
      default = 5;
    };
    leaseMilliseconds = mkOption {
      type = types.ints.between 1000 86400000;
      default = 3600000;
    };
    localOperator = mkOption {
      type = types.nullOr (types.strMatching "[A-Za-z0-9][A-Za-z0-9_.-]{0,63}");
      default = null;
      description = "Kiln local-operator authority passed to every stage reaching a protected operation: claim, bind-dispatch, host-owner, dispatch, capture, verify and publication";
    };
    cairnSequence = mkOption {
      type = types.ints.positive;
      default = 1;
    };
    modelNetworkNamespace = mkOption {
      type = types.nullOr (types.strMatching "/run/netns/[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}");
      default = null;
      description = "Existing endpoint-scoped namespace the dispatcher (Lattice's host-side model broker) joins; the worker itself never has a network device";
    };
    modelCredential = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime model API key path, loaded only into the dispatch unit and passed to Lattice's host broker as ${modelCredentialEnv}; never visible to the worker";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cohort != null && cfg.configuration != null && cfg.attemptBundle != null;
        message = "Select built immutable cohort, policy and exact-attempt bundles";
      }
      {
        assertion =
          cfg.ciServiceProfile != null
          && lib.hasPrefix "/nix/store/" (toString cfg.ciServiceProfile)
          && cfg.canonicalCiStatePaths != [ ];
        message = "Select the real canonical CI service profile and explicitly authorized existing Engine state paths";
      }
      {
        assertion = lib.all (
          p: safePath p && p != "/" && !(lib.hasPrefix "/nix/store/" p)
        ) cfg.canonicalCiStatePaths;
        message = "Canonical Engine state roots must be safe non-root mutable paths";
      }
      {
        assertion =
          builtins.length (
            lib.unique [
              cfg.coordinatorUid
              cfg.executorUid
              cfg.publisherUid
              cfg.verifierUid
            ]
          ) == 4;
        message = "Coordinator, executor, verifier and publisher require distinct UIDs";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "Implementation isolation requires Linux";
      }
      {
        assertion = cfg.repositories != [ ] && cfg.workClasses != [ ];
        message = "Explicitly enroll repositories and work classes";
      }
      {
        assertion = builtins.length (lib.unique credentialPaths) == builtins.length credentialPaths;
        message = "Intake, publisher and model credentials must be separate files";
      }
      {
        assertion = lib.all (p: safePath p && !(lib.hasPrefix "/nix/store/" p)) credentialPaths;
        message = "Secrets must be safe runtime paths outside the Nix store";
      }
      {
        assertion = lib.all (p: safePath (toString p) && lib.hasPrefix "/nix/store/" (toString p)) [
          cfg.cohort
          cfg.configuration
          cfg.attemptBundle
        ];
        message = "Cohort/policy/attempt bundles must be immutable store paths";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignProfile != null
            && lib.hasPrefix "/nix/store/" (toString cfg.selectedCampaignProfile)
          );
        message = "Selected campaign requires an immutable typed drive profile";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignId != null
            && cfg.selectedCampaignId != ""
            && builtins.stringLength cfg.selectedCampaignId <= 256
          );
        message = "Select one exact native Cairn campaign identity";
      }
      {
        assertion = !cfg.selectedCampaignEnable || cfg.selectedCampaignDataGid != null;
        message = "Selected campaign roles require an explicit shared data-group id";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignDatabase != null
            && cfg.selectedImplementationDatabase != null
            &&
              lib.all
                (
                  p:
                  safePath p
                  && p != "/"
                  && !(lib.hasPrefix "/nix/store/" p)
                  && !(builtins.elem (builtins.dirOf p) [
                    "/"
                    "/var"
                    "/var/lib"
                    "/run"
                    "/tmp"
                    "/home"
                  ])
                )
                [
                  cfg.selectedCampaignDatabase
                  cfg.selectedImplementationDatabase
                ]
          );
        message = "Selected campaign and implementation databases require existing dedicated canonical state directories for SQLite journals";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignBoundInputDirectory != null
            && cfg.selectedCampaignCandidateExportDirectory != null
            && cfg.selectedCampaignWorkspaceRoot != null
            &&
              lib.all (p: safePath p && lib.hasPrefix "${root}/campaign/" p && !(lib.hasPrefix "/nix/store/" p))
                [
                  cfg.selectedCampaignBoundInputDirectory
                  cfg.selectedCampaignCandidateExportDirectory
                  cfg.selectedCampaignWorkspaceRoot
                ]
            &&
              builtins.length (
                lib.unique [
                  cfg.selectedCampaignBoundInputDirectory
                  cfg.selectedCampaignCandidateExportDirectory
                  cfg.selectedCampaignWorkspaceRoot
                ]
              ) == 3
          );
        message = "Selected campaign roots must be distinct owned paths below its private state root";
      }
      {
        assertion = !cfg.selectedCampaignEnable || (cfg.cohort != null && cfg.enable);
        message = "Selected campaign driving requires the explicit existing Kiln module and exact cohort";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignNetworkNamespace == null
            || cfg.selectedCampaignNetworkNamespace != cfg.modelNetworkNamespace
          );
        message = "Campaign delivery and coding model routes require distinct explicitly qualified namespaces";
      }
      {
        assertion =
          !cfg.selectedCampaignEnable
          || (
            cfg.selectedCampaignCredentialPath == null
            || (
              safePath cfg.selectedCampaignCredentialPath
              && !(lib.hasPrefix "/nix/store/" cfg.selectedCampaignCredentialPath)
              && !(lib.hasPrefix "/run/secrets/" cfg.selectedCampaignCredentialPath)
            )
          );
        message = "Campaign credential is an existing external runtime file, not a store path or broad /run/secrets mount";
      }
    ];
    users.groups = {
      "${name}-ledger" = { };
      "${name}-executor" =
        lib.optionalAttrs cfg.selectedCampaignEnable { gid = cfg.selectedCampaignDataGid; } // { };
      "${name}-capture" = { };
    };
    users.users = {
      "${name}-coordinator" = {
        isSystemUser = true;
        uid = cfg.coordinatorUid;
        group = "${name}-ledger";
      };
      "${name}-publisher" = {
        isSystemUser = true;
        uid = cfg.publisherUid;
        group = "${name}-ledger";
      };
      "${name}-verifier" = {
        isSystemUser = true;
        uid = cfg.verifierUid;
        group = "${name}-ledger";
      };
      "${name}-executor" = {
        isSystemUser = true;
        uid = cfg.executorUid;
        group = "${name}-executor";
      };
    };
    systemd.tmpfiles.rules = [
      # Ledger-group readable, traverse-only for others: kiln-web-service walks
      # every ancestor of its state and repository paths with
      # O_RDONLY|O_DIRECTORY (worker/files.rs `directory`), which needs read.
      "d ${root} 0751 root ${name}-ledger -"
      "d ${root}/kiln 0770 ${name}-coordinator ${name}-ledger -"
      "f ${root}/kiln/work.sqlite 0660 ${name}-coordinator ${name}-ledger -"
      "d ${root}/controller 0755 root root -"
      "d ${root}/controller-spool 1770 root ${name}-ledger -"
      "d ${root}/controller/claims 0755 root root -"
      "d ${root}/controller/bindings 0755 root root -"
      "d ${root}/publication-source 0755 root root -"
      # systemd opens `StandardOutput=append:` before it creates LogsDirectory,
      # so a stage's first start needs its log directory to exist already.
      "d /var/log/${name}-coordinator 0700 ${name}-coordinator ${name}-ledger -"
      "d /var/log/${name}-executor 0700 ${name}-executor ${name}-ledger -"
      "d /var/log/${name}-publisher 0700 ${name}-publisher ${name}-ledger -"
      "d /var/log/${name}-verifier 0700 ${name}-verifier ${name}-ledger -"
      "d ${root}/lattice 0700 ${name}-executor ${name}-executor -"
      "d ${root}/workspaces 0700 ${name}-executor ${name}-executor -"
      "d ${root}/candidate-export 0750 ${name}-executor ${name}-capture -"
      "d ${root}/verifier 0700 ${name}-verifier ${name}-ledger -"
      "d ${root}/verifier/repository 0700 ${name}-verifier ${name}-ledger -"
      "d ${root}/verifier/scratch 0700 ${name}-verifier ${name}-ledger -"
      "d ${root}/verifier/reports 0700 ${name}-verifier ${name}-ledger -"
    ]
    ++ lib.optionals cfg.selectedCampaignEnable [
      "d ${cfg.selectedCampaignBoundInputDirectory} 02770 root ${name}-executor -"
      "d ${cfg.selectedCampaignCandidateExportDirectory} 02770 root ${name}-executor -"
      "d ${cfg.selectedCampaignWorkspaceRoot} 0750 root ${name}-executor -"
    ];
    environment.etc."${name}/deployment.json".text = builtins.toJSON {
      schema = "onix.kiln.implementation-deployment.v1";
      inherit (cfg)
        repositories
        workClasses
        timeoutSeconds
        leaseMilliseconds
        ;
      cohort = toString cfg.cohort;
      configuration = toString cfg.configuration;
      attempt_bundle = toString cfg.attemptBundle;
      controller_program = "${qualification}/bin/kiln-implementation-qualify";
      controller_source = "${./qualification.py}";
      controller_source_sha256 = builtins.hashFile "sha256" ./qualification.py;
      module_source = "${./nixos.nix}";
      module_source_sha256 = builtins.hashFile "sha256" ./nixos.nix;
      canonical_ci_profile = toString cfg.ciServiceProfile;
      canonical_ci_state_paths = cfg.canonicalCiStatePaths;
      principals = {
        coordinator_uid = cfg.coordinatorUid;
        executor_uid = cfg.executorUid;
        publisher_uid = cfg.publisherUid;
        verifier_uid = cfg.verifierUid;
      };
      bounds = {
        memory_max_mib = cfg.memoryMaxMiB;
        cpu_quota_percent = cfg.cpuQuotaPercent;
        tasks_max = cfg.tasksMax;
        maximum_pages = cfg.maximumPages;
      };
      model_network_namespace = cfg.modelNetworkNamespace;
      model_credential = cfg.modelCredential != null;
      publication_mode = "verified-pr";
      landing = "disabled";
      automatic_dispatch = false;
      qualification = "unqualified";
      state = {
        kiln = "${root}/kiln/work.sqlite";
        lattice = "${root}/lattice";
        cairn = "existing-owner";
      };
    };
    systemd.services = {
      # The configuration is immutable per generation: admit it once and keep
      # the unit active, so every stage's Requires= does not re-run it (and
      # hit systemd's start limit during a sequence of stages).
      "${name}-policy-check" = {
        description = "Admit exact configured implementation policy and worker transport";
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = policyCheck;
        };
      };
      "${name}-poll" = remote cfg.intakeCredential (
        stage "poll" [
          "--policy"
          (file "github-policy.json")
          "--max-pages"
          (toString cfg.maximumPages)
          "--secret-file"
          "%d/github"
        ]
      );
      "${name}-claim" = controllerStage "claim-attempt" [ "native" "!seal" ] (
        [
          "--lease-ms"
          (toString cfg.leaseMilliseconds)
        ]
        ++ operatorArgs
      );
      "${name}-prepare-fixture-intake" = controllerStage "prepare-fixture-intake" [ "" ] [ ];
      "${name}-bind-dispatch" =
        controllerStage "materialize-binding" [ "observe" "!stage" "execute" "!seal" ]
          (
            [
              "--stage"
              "dispatch"
              "--worker-uid"
              (toString cfg.executorUid)
              "--workspace-parent"
              "${root}/workspaces"
            ]
            ++ credentialArgs
            ++ operatorArgs
          );
      "${name}-bind-publication" =
        controllerStage "materialize-binding"
          [ "observe" "!seal" ]
          [
            "--stage"
            "publication"
            "--worker-uid"
            (toString cfg.executorUid)
            "--workspace-parent"
            "${root}/workspaces"
          ];
      "${name}-admission-status" = stage "admission-status" [ ];
      # Registered host-local owner: admit after intake, observe before claim
      # and again right before bind-dispatch, reserve the exact claim before
      # bind-dispatch, release only after the attempt is terminal.
      "${name}-host-owner-admit" = stage "host-owner-admit" hostOwnerArgs;
      "${name}-host-owner-observe" = stage "host-owner-observe" hostOwnerArgs;
      "${name}-host-owner-reserve" = protected (hostOwnerClaimStage "host-owner-reserve");
      "${name}-host-owner-release" = protected (hostOwnerClaimStage "host-owner-release");
      "${name}-reserve" =
        boundStage "reserve-plan" "dispatch"
          ''--plan-file "$binding/dispatch-plan.json"'';
      "${name}-dispatch" = protected (dispatcher false);
      "${name}-recover-dispatch" = protected (dispatcher true);
      "${name}-cancel-worker" = {
        description = "Persist cancellation for the exact installed native Lattice attempt";
        serviceConfig = hardening // {
          Type = "oneshot";
          User = "${name}-executor";
          Group = "${name}-ledger";
          ReadWritePaths = [
            "${root}/kiln"
            "${root}/lattice"
          ];
          # Lattice binds its intent to the bytes Kiln sent (the admitted
          # request, possibly plus one budget lineage), so the helper resolves
          # that recorded file through Kiln before cancelling.
          ExecStart = lib.escapeShellArgs (
            [
              "${qualification}/bin/kiln-implementation-qualify"
              "cancel-worker"
              "--state"
              "${root}/lattice/implementation"
            ]
            ++ bindingArgs
          );
        };
      };
      "${name}-export-candidate" = {
        description = "Read native durable candidate result and export source for independent capture";
        requires = [ "${name}-policy-check.service" ];
        after = [ "${name}-policy-check.service" ];
        serviceConfig = hardening // {
          Type = "oneshot";
          User = "${name}-executor";
          Group = "${name}-capture";
          SupplementaryGroups = [ "${name}-ledger" ];
          ReadWritePaths = [
            "${root}/kiln"
            "${root}/lattice"
            "${root}/candidate-export"
          ];
          ExecStart = lib.escapeShellArgs (
            [
              "${qualification}/bin/kiln-implementation-qualify"
              "export-candidate"
              "--workspace-parent"
              "${root}/workspaces"
              "--state"
              "${root}/lattice/implementation"
              "--output-parent"
              "${root}/candidate-export"
            ]
            ++ bindingArgs
            ++ credentialArgs
          );
        };
      };
      "${name}-capture-candidate" = protected (verifierStage "capture-candidate" captureCommand);
      "${name}-ci-credentials" = {
        description = "Private TLS key, certificate and role tokens for the canonical CI service";
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "${name}-verifier";
          Group = "${name}-ledger";
          UMask = "0077";
          RuntimeDirectory = "${name}-ci";
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = toString ciCredentials;
        };
      };
      "${name}-ci-enroll" = {
        description = "Enroll the allowlisted projects through the canonical CI service's Projects intake";
        requires = [
          "${name}-policy-check.service"
          "${name}-ci-credentials.service"
        ];
        after = [
          "${name}-policy-check.service"
          "${name}-ci-credentials.service"
        ];
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "${name}-verifier";
          Group = "${name}-ledger";
          # The service listens on loopback inside this unit's own private
          # network namespace; nothing else can reach it.
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
          ];
          ReadWritePaths = cfg.canonicalCiStatePaths;
          ExecStart = toString ciEnroll;
        };
      };
      "${name}-verify" = lib.recursiveUpdate (protected (verifierStage "verify" verifyCommand)) {
        requires = [
          "${name}-policy-check.service"
          "${name}-ci-enroll.service"
        ];
        after = [
          "${name}-policy-check.service"
          "${name}-ci-enroll.service"
        ];
      };
      "${name}-prepare-publication" = protected (
        boundStage "prepare-publication" "publication" ''--publication-file "$binding/publication.json"''
      );
      "${name}-publish" = remote cfg.publisherCredential (
        protected (
          boundStage "publish" "publication"
            ''--publication-file "$binding/publication.json" --remote-profile "$binding/publication-source-profile.json" --secret-file "$CREDENTIALS_DIRECTORY/github"''
        )
      );
      "${name}-status" = stage "status" [ ];
      "${name}-cairn-intake" = lib.recursiveUpdate (stage "status" [ ]) {
        serviceConfig.ExecStart = lib.escapeShellArgs (
          [ "${cfg.cohort}/environment/bin/kiln-cairn-intake" ]
          ++ commonArgs
          ++ [
            "--snapshot"
            (template "cairn-snapshot.json")
            "--policy"
            (file "cairn-policy.json")
            "--sequence"
            (toString cfg.cairnSequence)
          ]
        );
      };
    }
    // lib.optionalAttrs cfg.selectedCampaignEnable {
      "${name}-drive-selected-campaign@" = {
        description = "One bounded operator-started native selected-Cairn campaign step batch";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          ExecStart = lib.escapeShellArgs [
            "${cfg.cohort}/environment/bin/kiln-web-service"
            "drive-implementation-campaign"
            "--profile"
            (toString cfg.selectedCampaignProfile)
            "--campaign-id"
            cfg.selectedCampaignId
            "--expected-version"
            "%i"
          ];
          Restart = "no";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = false;
          LockPersonality = true;
          # Ownership transfer, private ledger access, cross-UID teardown, and
          # setpriv's UID/GID + bounding-set drop; never mount/admin authority.
          CapabilityBoundingSet = [
            "CAP_CHOWN"
            "CAP_DAC_OVERRIDE"
            "CAP_KILL"
            "CAP_SETGID"
            "CAP_SETPCAP"
            "CAP_SETUID"
          ];
          UMask = "0007";
          MemoryMax = "${toString cfg.memoryMaxMiB}M";
          CPUQuota = "${toString cfg.cpuQuotaPercent}%";
          TasksMax = cfg.tasksMax;
          TimeoutStartSec = cfg.timeoutSeconds;
          TimeoutStopSec = 30;
          KillMode = "control-group";
          RestrictAddressFamilies = [
            "AF_UNIX"
          ]
          ++ lib.optionals (cfg.selectedCampaignNetworkNamespace != null) [
            "AF_INET"
            "AF_INET6"
          ];
          PrivateNetwork = cfg.selectedCampaignNetworkNamespace == null;
          InaccessiblePaths = [
            "-/run/secrets"
            "-/root"
            "-/home"
          ];
          ReadWritePaths = lib.unique (
            [
              (builtins.dirOf cfg.selectedCampaignDatabase)
              (builtins.dirOf cfg.selectedImplementationDatabase)
              cfg.selectedCampaignBoundInputDirectory
              cfg.selectedCampaignCandidateExportDirectory
              cfg.selectedCampaignWorkspaceRoot
              "${root}/lattice"
              "${root}/verifier"
            ]
            ++ cfg.canonicalCiStatePaths
          );
          ReadOnlyPaths = lib.optional (
            cfg.selectedCampaignCredentialPath != null
          ) cfg.selectedCampaignCredentialPath;
          WorkingDirectory = cfg.selectedCampaignBoundInputDirectory;
        }
        // lib.optionalAttrs (cfg.selectedCampaignNetworkNamespace != null) {
          NetworkNamespacePath = cfg.selectedCampaignNetworkNamespace;
        };
        wantedBy = [ ];
      };
    };
  };
}
