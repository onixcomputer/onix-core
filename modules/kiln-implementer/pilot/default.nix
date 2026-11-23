# Live verified-PR pilot for OnixResearch/implementer-sandbox, run only inside
# a local NixOS VM on the operator's workstation (never a host deployment).
# One guest per issue: Kiln's GitHub intake applies one repository-wide policy
# to every polled issue, so each issue's contract is its own configuration.
{
  pkgs,
  lib,
  self,
  pinned,
}:
let
  inherit (pinned) cohort;
  system = pkgs.stdenv.hostPlatform.system;
  repository = {
    owner = "OnixResearch";
    name = "implementer-sandbox";
    id = 1467234739;
    # Kiln's durable repository key is ASCII lowercase (EventPolicy).
    key = "onixresearch/implementer-sandbox";
    base = "f1adb86f6320f2bbb6c02ae077905a6bb8c22955";
  };
  # The exact reviewed baseline tree; acceptance tests are pinned from it.
  source = builtins.fetchGit {
    url = "ssh://git@github.com/OnixResearch/implementer-sandbox.git";
    rev = repository.base;
  };
  cases = {
    bug = {
      issue = 1;
      title = "word_count counts empty words and ignores tabs and newlines";
      test = "word_count_whitespace";
      reproducer = true;
    };
    feature = {
      issue = 2;
      title = "Add char_frequency for non-whitespace characters";
      test = "char_frequency";
      reproducer = false;
    };
  };
  model = {
    # Host underclass gateway on 127.0.0.1:8080, reached from the guest at
    # QEMU user networking's 10.0.2.2 through the relay in vm.nix.
    id = "opencode-go/deepseek-v4.1-flash";
    endpoint = "http://127.0.0.1:18080/v1/chat/completions";
    upstream = {
      address = "10.0.2.2";
      port = 8080;
    };
    credential = true;
  };
  # Offline composition (`pilot-flow`): the bug case on a deterministic root
  # commit of the same reviewed tree, so capture and verification need no
  # GitHub, against Kiln's authless scripted model fixture served on the
  # guest's own loopback behind the same relay and bridge. Only the base
  # commit, the model route and the model key differ from the live guest.
  flowBase = "2f2762b78540ed6b39c1c67032ab4e049729b557";
  flowRepository = repository // {
    base = flowBase;
  };
  flowModel = model // {
    id = "scripted-v1";
    upstream = {
      address = "127.0.0.1";
      port = 18700;
    };
    credential = false;
  };
  flowGit =
    pkgs.runCommand "kiln-implementation-pilot-flow-repository" { nativeBuildInputs = [ pkgs.git ]; }
      ''
        export HOME="$TMPDIR" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
        export GIT_AUTHOR_NAME=kiln-pilot-flow GIT_AUTHOR_EMAIL=pilot-flow@kiln.invalid GIT_AUTHOR_DATE="@0 +0000"
        export GIT_COMMITTER_NAME=kiln-pilot-flow GIT_COMMITTER_EMAIL=pilot-flow@kiln.invalid GIT_COMMITTER_DATE="@0 +0000"
        git init -q -b main work
        cp -r ${source}/. work/
        chmod -R u+w work
        git -C work add -A -f .
        git -C work commit -q -m "pilot-flow base"
        test "$(git -C work rev-parse HEAD)" = ${flowBase}
        git clone -q --bare --no-local work "$out"
      '';
  # One native `write` of the reviewed fix (Kiln's scripted model fixture,
  # tests/kiln-implementation-fixtures/model_server.py), then a final turn.
  flowScenario =
    let
      original = builtins.readFile "${source}/src/lib.rs";
      fixed =
        builtins.replaceStrings [ "text.split(' ').count()" ] [ "text.split_whitespace().count()" ]
          original;
    in
    assert fixed != original;
    pkgs.writeText "kiln-pilot-flow-scenario.json" (
      builtins.toJSON {
        schema = "kiln.scripted-model-scenario.v1";
        id = "kiln-pilot-flow-bug";
        model = "kiln-scripted/${flowModel.id}";
        task_marker = "Resolve GitHub issue #${toString cases.bug.issue} in this Rust crate";
        target_path = "src/lib.rs";
        content = fixed;
        completion_text = "done";
        tool_call_id = "pilot_flow_write_1";
      }
    );
  # Verification runs the frozen toolchain offline on the captured candidate.
  cargoCheck = pkgs.writeShellScript "kiln-pilot-cargo-check" ''
    set -eu
    artifact="$1"
    shift
    export PATH=${
      lib.makeBinPath [
        pkgs.cargo
        pkgs.rustc
        pkgs.rustfmt
        pkgs.clippy
        pkgs.stdenv.cc
        pkgs.coreutils
      ]
    }
    scratch="$(mktemp -d)"
    export CARGO_HOME="$scratch/home" CARGO_TARGET_DIR="$scratch/target" CARGO_NET_OFFLINE=true
    cargo "$@"
    printf '{"check":"%s","exit":0}\n' "$artifact" > "$artifact"
  '';
  # Lattice 7fb6dc47 sandbox.rs `command()` for the sealed request at
  # /run/kiln-pilot-worker-probe/request, with mounts tested in this unit's
  # namespace as Lattice tests them; only the program differs.
  workerSandboxProbe = pkgs.writeShellScript "kiln-pilot-worker-sandbox-probe" ''
    set -eu
    jq=${pkgs.jq}/bin/jq
    request="$(cat /run/kiln-pilot-worker-probe/request)"
    sandbox="$($jq -er .sandbox_program "$request")"
    root="$($jq -er .workspace_root "$request")"
    args=(--unshare-user --disable-userns --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup
      --die-with-parent --cap-drop ALL --clearenv --setenv PATH /usr/bin:/bin --setenv HOME /tmp/omp-home --unshare-net)
    for base in /nix/store /usr /bin /lib /lib64; do
      if [ -e "$base" ]; then args+=(--ro-bind "$base" "$base"); fi
    done
    if [ -e /run/current-system/sw/bin ]; then args+=(--ro-bind /run/current-system/sw/bin /usr/bin); fi
    args+=(--proc /proc --dev /dev --tmpfs /tmp --dir /tmp/omp-home --tmpfs /workspace --chdir /workspace)
    mapfile -t writes < <($jq -r '.write_paths[]' "$request")
    while IFS= read -r read; do
      covered=0
      for write in "''${writes[@]}"; do
        case "$read" in "$write"|"$write"/*) covered=1 ;; esac
      done
      if [ "$covered" = 0 ] && [ -e "$root/$read" ]; then args+=(--ro-bind "$root/$read" "/workspace/$read"); fi
    done < <($jq -r '.read_paths[]' "$request")
    for write in "''${writes[@]}"; do args+=(--bind "$root/$write" "/workspace/$write"); done
    args+=(--remount-ro /workspace --remount-ro / --)
    case "$1" in
      true) exec "$sandbox" "''${args[@]}" /usr/bin/true ;;
      omp-version) exec "$sandbox" "''${args[@]}" "$($jq -er .program "$request")" --version ;;
    esac
    exit 2
  '';
  inputsOf =
    {
      label,
      name,
      case,
      model,
      repository,
    }:
    let
      built =
        pkgs.runCommand "kiln-implementation-pilot-${label}"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.b3sum
              pkgs.nickel
            ];
            passthru = {
              inherit
                cohort
                case
                model
                repository
                ;
              configuration = "${built}/configuration";
              attemptBundle = "${built}/attempt";
              ciServiceProfile = "${built}/ci-service-profile.json";
            };
          }
          ''
            python3 ${./build_pilot.py} \
              --cohort ${cohort} --source ${source} --profile ${./profile.ncl} \
              --cargo-check ${cargoCheck} \
              --host-owner-contract ${self.inputs.kiln-implementation}/config/fair-admission-host-owner.ncl \
              --spec ${
                pkgs.writeText "kiln-pilot-${label}.json" (
                  builtins.toJSON {
                    inherit name case model;
                    # Kiln's publication remote: exactly https://github.com/{owner}/{name}.git
                    # from the durable lowercase key (build_pilot.py checks the result).
                    repository = repository // {
                      remote_url = "https://github.com/${repository.key}.git";
                    };
                  }
                )
              } \
              --output "$out" --scratch "$TMPDIR/construction"
          '';
    in
    built;
  inputs = lib.mapAttrs (
    name: case:
    inputsOf {
      label = name;
      inherit
        name
        case
        model
        repository
        ;
    }
  ) cases;
  flowInputs = inputsOf {
    label = "flow";
    name = "bug";
    case = cases.bug;
    model = flowModel;
    repository = flowRepository;
  };
  # Kiln's own parsers on each generated configuration (parse-check.sh). The
  # guests depend on it, so a configuration Kiln would reject never boots.
  parseCheck =
    label: built:
    pkgs.runCommand "kiln-implementation-pilot-parse-${label}"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        ${pkgs.bash}/bin/bash ${./parse-check.sh} ${cohort}/environment/bin/kiln-implementer \
          ${built}/configuration "$TMPDIR/parse" > "$out"
        cat "$out"
      '';
  parseChecks = lib.mapAttrs parseCheck inputs;
  # The real kiln-implementer serves Kiln's GitHub DNS helper entry
  # (resolver-check.sh); without it no GitHub API call can be made.
  resolverCheck = pkgs.runCommand "kiln-implementation-pilot-resolver" { } ''
    ${pkgs.bash}/bin/bash ${./resolver-check.sh} ${cohort}/environment/bin/kiln-implementer "$TMPDIR/resolver" > "$out"
    cat "$out"
  '';
  settingsWith =
    {
      name,
      built,
      model,
      base,
      parse,
    }:
    {
      kilnPilot = {
        inherit cohort model base;
        inputs = built;
        caseName = name;
        repositoryKey = repository.key;
      };
      system.extraDependencies = [
        parse
        resolverCheck
      ];
    };
  settings =
    name:
    settingsWith {
      inherit name model;
      inherit (repository) base;
      built = inputs.${name};
      parse = parseChecks.${name};
    };
  flowSettings = settingsWith {
    name = "bug";
    built = flowInputs;
    model = flowModel;
    base = flowBase;
    parse = parseCheck "flow" flowInputs;
  };
  # Two independent guests of the offline composition: one runs the attempt
  # through verification, the other is cancelled mid-flight.
  flowNode = { lib, pkgs, ... }: {
    imports = [
      ./vm.nix
      flowSettings
    ];
    kilnPilot.credentialShare = false;
    virtualisation.memorySize = lib.mkForce 4096;
    # Two guests in one test: no host SSH forward (both would bind 2222).
    virtualisation.forwardPorts = lib.mkForce [ ];
    environment.systemPackages = [ pkgs.python3 ];
    environment.etc = {
      "kiln-pilot-flow/model_server.py".source =
        ../../../tests/kiln-implementation-fixtures/model_server.py;
      "kiln-pilot-flow/scenario.json".source = flowScenario;
    };
    # The trusted verifier store holds the exact enrolled base commit; offline
    # it comes from the deterministic local repository, not GitHub, so the
    # intake token is not loaded.
    systemd.services.kiln-pilot-acquire-verifier-source.serviceConfig.LoadCredential = lib.mkForce [ ];
    systemd.services.kiln-pilot-acquire-verifier-source.script = lib.mkForce ''
      set -eu
      repository=/var/lib/kiln-implementation/verifier/repository
      if ! test -f "$repository/HEAD"; then
        git clone -q --bare --no-local ${flowGit} "$repository.new"
        rm -rf "$repository"
        mv "$repository.new" "$repository"
      fi
      git --git-dir="$repository" cat-file -e ${flowBase}^{commit}
      chown -R kiln-implementation-verifier:kiln-implementation-ledger "$repository"
      chmod 0700 "$repository"
    '';
  };
  guest =
    name:
    (import "${self.inputs.nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        ./vm.nix
        "${self.inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
        (settings name)
      ];
    }).config;
in
{
  pilot-inputs = inputs;
  pilot-parse = parseChecks;
  pilot-resolver = resolverCheck;
  pilot-vm = lib.mapAttrs (name: _: (guest name).system.build.vm) cases;
  # The same guest module booted without the credential share.
  pilot-boot = pkgs.testers.runNixOSTest {
    name = "kiln-implementation-pilot-boot";
    # python3 only to write the scripted delivery into Kiln's queue schema.
    nodes.pilot = { config, pkgs, ... }: {
      imports = [
        ./vm.nix
        (settings "bug")
      ];
      kilnPilot.credentialShare = false;
      environment.systemPackages = [ pkgs.python3 ];
      # Lattice's exact worker sandbox (7fb6dc47 src/candidate_worker/sandbox.rs)
      # under the dispatch unit's own settings, inherited rather than copied, so
      # the probe tracks the unit. %i: `true` (no-op) or `omp-version`. Only the
      # broker's later plain binds (socket, model config) are left out; the
      # model broker, relay and transport never start.
      systemd.services."kiln-pilot-worker-sandbox-probe@" = {
        description = "Lattice worker sandbox under the dispatch unit's settings (%i)";
        requires = [ "kiln-pilot-model-netns.service" ];
        after = [ "kiln-pilot-model-netns.service" ];
        serviceConfig =
          builtins.removeAttrs config.systemd.services.kiln-implementation-dispatch.serviceConfig [
            "ExecStartPre"
            "ExecStart"
            "LoadCredential"
          ]
          // {
            ExecStart = "${workerSandboxProbe} %i";
            # Like the dispatcher's own logs; the journal can lose the unit
            # attribution of output from a process this short-lived.
            StandardOutput = "truncate:/var/log/kiln-implementation-executor/sandbox-probe-%i.out";
            StandardError = "truncate:/var/log/kiln-implementation-executor/sandbox-probe-%i.err";
          };
      };
    };
    testScript = builtins.readFile ./offline-intake.py + builtins.readFile ./boot-test.py;
  };
  # Offline composition after dispatch: a lineage-bearing dispatch through
  # export, capture and verification, and a mid-flight operator cancel.
  pilot-flow = pkgs.testers.runNixOSTest {
    name = "kiln-implementation-pilot-flow";
    nodes = {
      produce = flowNode;
      cancel = flowNode;
    };
    testScript = builtins.readFile ./offline-intake.py + builtins.readFile ./flow-test.py;
  };
}
