# Live verified-PR pilot for OnixResearch/implementer-sandbox, run only inside
# a local NixOS VM on the operator's workstation (never a host deployment).
# One guest per issue: Kiln's GitHub intake applies one repository-wide policy
# to every polled issue, so each issue's contract is its own configuration.
{ pkgs, lib, self, pinned }:
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
    upstream = { address = "10.0.2.2"; port = 8080; };
  };
  # Verification runs the frozen toolchain offline on the captured candidate.
  cargoCheck = pkgs.writeShellScript "kiln-pilot-cargo-check" ''
    set -eu
    artifact="$1"
    shift
    export PATH=${lib.makeBinPath [ pkgs.cargo pkgs.rustc pkgs.rustfmt pkgs.clippy pkgs.stdenv.cc pkgs.coreutils ]}
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
  inputsFor = name: case: pkgs.runCommand "kiln-implementation-pilot-${name}" {
    nativeBuildInputs = [ pkgs.python3 pkgs.b3sum pkgs.nickel ];
    passthru = {
      inherit cohort case model repository;
      configuration = "${inputsFor name case}/configuration";
      attemptBundle = "${inputsFor name case}/attempt";
      ciServiceProfile = "${inputsFor name case}/ci-service-profile.json";
    };
  } ''
    python3 ${./build_pilot.py} \
      --cohort ${cohort} --source ${source} --profile ${./profile.ncl} \
      --cargo-check ${cargoCheck} \
      --host-owner-contract ${self.inputs.kiln-implementation}/config/fair-admission-host-owner.ncl \
      --spec ${pkgs.writeText "kiln-pilot-${name}.json" (builtins.toJSON {
        inherit name case model;
        repository = repository // { remote_url = "https://github.com/${repository.owner}/${repository.name}.git"; };
      })} \
      --output "$out" --scratch "$TMPDIR/construction"
  '';
  inputs = lib.mapAttrs inputsFor cases;
  # Kiln's own parsers on each generated configuration (parse-check.sh). The
  # guests depend on it, so a configuration Kiln would reject never boots.
  parseCheck = name: pkgs.runCommand "kiln-implementation-pilot-parse-${name}" {
    nativeBuildInputs = [ pkgs.jq ];
  } ''
    ${pkgs.bash}/bin/bash ${./parse-check.sh} ${cohort}/environment/bin/kiln-implementer \
      ${inputs.${name}}/configuration "$TMPDIR/parse" > "$out"
    cat "$out"
  '';
  parseChecks = lib.mapAttrs (name: _: parseCheck name) cases;
  # The real kiln-implementer serves Kiln's GitHub DNS helper entry
  # (resolver-check.sh); without it no GitHub API call can be made.
  resolverCheck = pkgs.runCommand "kiln-implementation-pilot-resolver" { } ''
    ${pkgs.bash}/bin/bash ${./resolver-check.sh} ${cohort}/environment/bin/kiln-implementer "$TMPDIR/resolver" > "$out"
    cat "$out"
  '';
  settings = name: {
    kilnPilot = {
      inherit cohort model;
      inputs = inputs.${name};
      caseName = name;
      repositoryKey = repository.key;
      inherit (repository) base;
    };
    system.extraDependencies = [ parseChecks.${name} resolverCheck ];
  };
  guest = name: (import "${self.inputs.nixpkgs}/nixos/lib/eval-config.nix" {
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
      imports = [ ./vm.nix (settings "bug") ];
      kilnPilot.credentialShare = false;
      environment.systemPackages = [ pkgs.python3 ];
      # Lattice's exact worker sandbox (7fb6dc47 src/candidate_worker/sandbox.rs)
      # under the dispatch unit's own settings, inherited rather than copied, so
      # the probe tracks the unit. %i: `true` (no-op) or `omp-version`. Only the
      # broker's later plain binds (socket, model config) are left out; the
      # model broker, relay and transport never start.
      systemd.services."kiln-pilot-worker-sandbox-probe@" = {
        description = "Lattice worker sandbox under the dispatch unit's settings (%i)";
        requires = [ "kiln-pilot-model-netns.service" ]; after = [ "kiln-pilot-model-netns.service" ];
        serviceConfig = builtins.removeAttrs config.systemd.services.kiln-implementation-dispatch.serviceConfig
          [ "ExecStartPre" "ExecStart" "LoadCredential" ] // {
          ExecStart = "${workerSandboxProbe} %i";
          # Like the dispatcher's own logs; the journal can lose the unit
          # attribution of output from a process this short-lived.
          StandardOutput = "truncate:/var/log/kiln-implementation-executor/sandbox-probe-%i.out";
          StandardError = "truncate:/var/log/kiln-implementation-executor/sandbox-probe-%i.err";
        };
      };
    };
    testScript = builtins.readFile ./boot-test.py;
  };
}
