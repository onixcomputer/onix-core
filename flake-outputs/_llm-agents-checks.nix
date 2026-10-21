# Focused checks for the scoped llm-agents installs.
#
# The shared `llm-agents` instance gives every llm-client host the standard
# CLI set. The `omp-agents` instance widens that set on two workstations
# only, so these checks pin both halves of that contract.
#
# Positive: oh-my-pi's `omp` is present in the evaluated
# `environment.systemPackages` of `britton-desktop` and `aspen3`, and the
# exact package the configuration selects builds and passes its own smoke
# test.
#
# Negative: `omp` stays absent from an llm-client machine outside the
# selection, and a bogus agent name stays absent from the selected machines.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  selectedMachines = [
    "britton-desktop"
    "aspen3"
  ];
  unselectedMachine = "aspen1";
  agentName = "omp";
  bogusAgentName = "omp-bogus";
  smokeTestMarker = "smoke-test: ok";

  nameOf = package: package.pname or package.name or "unnamed";
  machinePackages = machine: self.nixosConfigurations.${machine}.config.environment.systemPackages;
  machineHas = machine: name: lib.any (package: nameOf package == name) (machinePackages machine);

  reportLine =
    machine: name: "${machine}.${name}=${if machineHas machine name then "present" else "absent"}";
  reportText = lib.concatStringsSep "\n" (
    lib.concatMap (machine: [
      (reportLine machine agentName)
      (reportLine machine bogusAgentName)
    ]) selectedMachines
    ++ [ (reportLine unselectedMachine agentName) ]
  );

  requirePresent = entry: "require_present ${lib.escapeShellArg entry}";
  requireAbsent = entry: "require_absent ${lib.escapeShellArg entry}";

  # Take the agent from the evaluated configuration, so the build check
  # cannot drift onto a differently pinned package set.
  installedAgent = lib.findFirst (package: nameOf package == agentName) null (
    machinePackages (lib.head selectedMachines)
  );

  packageListCheck = pkgs.runCommand "llm-agents-omp-package-list" { } ''
    cat > report.txt <<'REPORT'
    ${reportText}
    REPORT
    fail=0
    require_present() {
      grep -qx "$1=present" report.txt || {
        echo "expected $1 to be present in the evaluated package list" >&2
        fail=1
      }
    }
    require_absent() {
      grep -qx "$1=absent" report.txt || {
        echo "expected $1 to be absent from the evaluated package list" >&2
        fail=1
      }
    }
    ${lib.concatStringsSep "\n" (
      map (machine: requirePresent "${machine}.${agentName}") selectedMachines
    )}
    ${lib.concatStringsSep "\n" (
      map (machine: requireAbsent "${machine}.${bogusAgentName}") selectedMachines
    )}
    ${requireAbsent "${unselectedMachine}.${agentName}"}
    [ "$fail" -eq 0 ] || exit 1
    mkdir -p $out
    cp report.txt $out/report.txt
  '';

  # The packaged agent runs its own smoke test, matching the check the
  # llm-agents package performs upstream. A missing or broken install fails
  # here rather than at first use.
  smokeCheck = pkgs.runCommand "llm-agents-omp-smoke" { } ''
    export HOME=$TMPDIR
    if ! ${installedAgent}/bin/${agentName} --smoke-test | grep -q ${lib.escapeShellArg smokeTestMarker}; then
      echo "the configured ${agentName} package failed its smoke test" >&2
      exit 1
    fi
    mkdir -p $out
    printf '%s\n' ${lib.escapeShellArg smokeTestMarker} > $out/smoke-test.txt
  '';
in
{
  checks =
    lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      llm-agents-omp-package-list = packageListCheck;
    }
    // lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && installedAgent != null) {
      llm-agents-omp-smoke = smokeCheck;
    };
}
