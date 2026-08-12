{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  isLinuxHost = pkgs.stdenv.hostPlatform.isLinux;
  canary = self.lib.inputs.devenv-machines;
  reviewedCanaryRevision = "6e61f6a12f730b81228f70ee2487320fdbb1e2fc";
  canaryRevision = canary.sourceInfo.rev or null;
  normalDevenvRevision = self.lib.inputs.devenv.sourceInfo.rev or null;
  canaryCli = canary.packages.${system}.devenv;
  dgxInventorySource = builtins.path {
    path = ../inventory/dgx;
    name = "dgx-inventory";
  };

  inventoryCore = import ../lib/dgx-machine-inventory.nix { inherit lib; };
  productionInventory = builtins.fromJSON (
    builtins.readFile ../inventory/dgx/generated/machines.json
  );
  generatedClanMachineNames = builtins.fromJSON (
    builtins.readFile ../inventory/dgx/generated/clan-machine-names.json
  );
  fixtureRoot = ../tests/dgx-devenv;
  fixtureInventory = builtins.fromJSON (builtins.readFile (fixtureRoot + "/inventory.json"));
  fixtureMachine = fixtureInventory.machines.fixture-dgx;
  fixturePathExists = relativePath: builtins.pathExists (fixtureRoot + "/${relativePath}");
  unexpectedFakeDevenvExitCode = 96;
  fakeDevenv = pkgs.writeShellScriptBin "devenv" ''
    printf '%s\n' "$@" > "''${DGX_TEST_INVOCATION:?test invocation path is unset}"
    case "$*" in
      "machines info")
        printf '%s\n' 'No machines defined in devenv.nix.'
        ;;
      "build machines.fixture-dgx")
        ;;
      *)
        exit ${toString unexpectedFakeDevenvExitCode}
        ;;
    esac
  '';
  fixtureDgxMachineCommand = pkgs.callPackage ../pkgs/dgx-machine {
    devenv = fakeDevenv;
    machineInventory = fixtureRoot + "/inventory.json";
  };
  expectedFixtureSshOpts = [
    "-o"
    "StrictHostKeyChecking=yes"
    "-o"
    "UserKnownHostsFile=${toString (fixtureRoot + "/${fixtureMachine.knownHostsFile}")}"
    "-o"
    "IdentitiesOnly=yes"
  ];
  productionValidation = inventoryCore.validateInventory {
    inventory = productionInventory;
    clanMachineNames = self.lib.machines.names;
    pathExists = relativePath: builtins.pathExists (../. + "/${relativePath}");
    requireFiles = true;
  };
  fixtureValidation = inventoryCore.validateInventory {
    inventory = fixtureInventory;
    pathExists = fixturePathExists;
    requireFiles = true;
  };
  duplicateOwnershipValidation = inventoryCore.validateInventory {
    inventory = fixtureInventory;
    clanMachineNames = [ "fixture-dgx" ];
    pathExists = fixturePathExists;
    requireFiles = true;
  };
  unsafeDiskValidation = inventoryCore.validateInventory {
    inventory = {
      machines.fixture-dgx = fixtureMachine // {
        diskById = "/dev/nvme0n1";
      };
    };
    pathExists = fixturePathExists;
    requireFiles = true;
  };
  missingFileValidation = inventoryCore.validateInventory {
    inventory = fixtureInventory;
    pathExists = _relativePath: false;
    requireFiles = true;
  };
  missingBackendValidation = inventoryCore.validateInventory {
    inventory = {
      machines.fixture-dgx = fixtureMachine // {
        meshBackend = {
          externallyManaged = false;
        };
      };
    };
    pathExists = fixturePathExists;
    requireFiles = true;
  };
  duplicateSecretValidation = inventoryCore.validateInventory {
    inventory = {
      machines.fixture-dgx = fixtureMachine // {
        runtimeSecrets = fixtureMachine.runtimeSecrets // {
          meshJoinToken = fixtureMachine.runtimeSecrets.tailscaleAuthKey;
        };
      };
    };
    pathExists = fixturePathExists;
    requireFiles = true;
  };
  malformedRecordValidation = inventoryCore.validateInventory {
    inventory.machines.fixture-dgx = "not-a-record";
  };

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  tailscaleSchema = wasm.evalNickelFile ../modules/tailscale/schema.ncl;
  irohSchema = wasm.evalNickelFile ../modules/iroh-ssh/schema.ncl;
  tailscaleSettings = {
    enableHostAliases = true;
    enableSSH = true;
    exitNode = false;
    extraUpFlags = [ ];
  };
  tailscaleAuthKeyPath = "/run/credentials/tailscale-auth-key";
  tailscaleFixtureConfig = {
    networking.interfaces = { };
    clan.core.vars.generators."tailscale-dgx-fixture".files.auth_key.path = tailscaleAuthKeyPath;
  };
  tailscaleServiceDefinition = (import ../modules/tailscale { schema = tailscaleSchema; }) {
    inherit lib;
  };
  tailscalePerInstance = tailscaleServiceDefinition.roles.peer.perInstance {
    instanceName = "dgx-fixture";
    extendSettings = _defaults: tailscaleSettings;
  };
  tailscaleClanConfig = tailscalePerInstance.nixosModule {
    inherit lib pkgs;
    config = tailscaleFixtureConfig;
  };
  tailscaleClanCoreConfig =
    assert tailscaleClanConfig.config._type == "merge";
    builtins.head tailscaleClanConfig.config.contents;
  tailscaleCoreConfig = import ../modules/tailscale/mk-nixos-config.nix {
    inherit lib pkgs;
    config = tailscaleFixtureConfig;
    settings = tailscaleSettings;
    authKeyFile = tailscaleAuthKeyPath;
  };
  tailscaleCoreParity =
    tailscaleClanCoreConfig.services.tailscale == tailscaleCoreConfig.services.tailscale
    && tailscaleClanCoreConfig.networking.firewall == tailscaleCoreConfig.networking.firewall;

  irohSshPort = 22;
  irohPrivateKeyPath = "/run/credentials/iroh-private-key";
  irohPublicKeyPath = "/run/credentials/iroh-public-key";
  irohFixtureConfig = {
    services.openssh.enable = true;
    clan.core.vars.generators."iroh-ssh-dgx-fixture".files = {
      irohssh_ed25519.path = irohPrivateKeyPath;
      "irohssh_ed25519.pub".path = irohPublicKeyPath;
    };
  };
  irohServiceDefinition = (import ../modules/iroh-ssh { schema = irohSchema; }) { inherit lib; };
  irohPerInstance = irohServiceDefinition.roles.peer.perInstance {
    instanceName = "dgx-fixture";
    extendSettings = _defaults: { sshPort = irohSshPort; };
  };
  irohClanConfig = irohPerInstance.nixosModule {
    inherit lib pkgs;
    config = irohFixtureConfig;
  };
  irohClanCoreConfig =
    assert irohClanConfig._type == "merge";
    builtins.head irohClanConfig.contents;
  irohCoreConfig = import ../modules/iroh-ssh/mk-nixos-config.nix {
    inherit lib pkgs;
    config = irohFixtureConfig;
    settings.sshPort = irohSshPort;
    privateKeyPath = irohPrivateKeyPath;
    publicKeyPath = irohPublicKeyPath;
  };
  irohCoreParity =
    irohClanCoreConfig.systemd.services."iroh-ssh" == irohCoreConfig.systemd.services."iroh-ssh"
    && irohClanCoreConfig.users.users."iroh-ssh" == irohCoreConfig.users.users."iroh-ssh";

  canaryInputs = self.lib.inputs // {
    onix-core = self;
    devenv = canary;
    inherit self;
  };
  fixtureMachinesWithFacter = import ../devenv/dgx-machines.nix {
    inherit lib;
    inputs = canaryInputs;
    projectRoot = fixtureRoot;
    inventory = fixtureInventory;
    clanMachineNames = [ ];
  };
  fixtureMachines = import ../devenv/dgx-machines.nix {
    inherit lib;
    inputs = canaryInputs;
    projectRoot = fixtureRoot;
    inventory = fixtureInventory;
    clanMachineNames = [ ];
    enableFacter = false;
  };
  canaryConfig = canary.lib.mkConfig {
    inherit pkgs;
    inputs = canaryInputs;
    modules = [
      {
        devenv.root = toString fixtureRoot;
        machines = fixtureMachines;
      }
    ];
  };
  evaluatedFixtureMachine = canaryConfig.machines.fixture-dgx;
  evaluatedFixtureNixos = evaluatedFixtureMachine._nixosEval.config;
  fixtureDiskoScript = evaluatedFixtureMachine.build.diskoScript;
  fixtureNixosToplevel = evaluatedFixtureMachine.build.nixos;
  fixtureServiceName = "mesh-llm-dgx-spark";
  expectedBrittonUid = 1555;
  frameworkKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework";
  excludedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX7hNDY0L9JSSIP+NVTbDluJgJ9c/l9nzbuwCNkVxgr britton@cproof.ai";
  fixtureAssertionsPass = lib.all (item: item.assertion) evaluatedFixtureNixos.assertions;
  expectedRuntimeSecretFiles = {
    tailscaleAuthKey = "/var/lib/onix-dgx-secrets/tailscale-auth-key";
    meshJoinToken = "/var/lib/onix-dgx-secrets/mesh-join-token";
    irohPrivateKey = "/var/lib/onix-dgx-secrets/iroh-private-key";
    irohPublicKey = "/var/lib/onix-dgx-secrets/iroh-public-key";
  };
  fixtureSecretBootstrapFiles = fixtureMachines.fixture-dgx.install.secrets;
  fixtureSecretBootstrapNames = lib.sort lib.lessThan (
    map (target: fixtureSecretBootstrapFiles.${target}.secret) (
      builtins.attrNames fixtureSecretBootstrapFiles
    )
  );
  expectedSecretBootstrapNames = lib.sort lib.lessThan (
    builtins.attrValues fixtureMachine.runtimeSecrets
  );
  fixtureSecretBootstrapMetadataIsPrivate = lib.all (
    target:
    fixtureSecretBootstrapFiles.${target}.owner == "0:0"
    && fixtureSecretBootstrapFiles.${target}.mode == "0400"
  ) (builtins.attrNames fixtureSecretBootstrapFiles);

  adapterAssertions = [
    {
      name = "experimental canary remains separate from the normal Devenv shell";
      condition = normalDevenvRevision != null && normalDevenvRevision != canaryRevision;
    }
    {
      name = "production inventory is valid and intentionally empty";
      condition = productionValidation.valid && productionValidation.names == [ ];
    }
    {
      name = "generated Clan ownership names are fresh";
      condition = generatedClanMachineNames == self.lib.machines.names;
    }
    {
      name = "synthetic inventory is valid";
      condition = fixtureValidation.valid;
    }
    {
      name = "duplicate ownership fails closed";
      condition =
        !duplicateOwnershipValidation.valid
        && duplicateOwnershipValidation.duplicateOwners == [ "fixture-dgx" ];
    }
    {
      name = "unstable disk paths fail closed";
      condition = !unsafeDiskValidation.valid;
    }
    {
      name = "missing files fail closed";
      condition = !missingFileValidation.valid;
    }
    {
      name = "unowned loopback backends fail closed";
      condition = !missingBackendValidation.valid;
    }
    {
      name = "duplicate runtime secret names fail closed";
      condition = !duplicateSecretValidation.valid;
    }
    {
      name = "malformed machine records fail closed";
      condition = !malformedRecordValidation.valid;
    }
    {
      name = "canary metadata exposes one NixOS machine";
      condition =
        canaryConfig.machinesMeta.fixture-dgx.system == "aarch64-linux"
        && canaryConfig.machinesMeta.fixture-dgx.target.host == "root@fixture-dgx"
        && canaryConfig.machinesMeta.fixture-dgx.target.sshOpts == expectedFixtureSshOpts
        && canaryConfig.machinesMeta.fixture-dgx.hasNixos;
    }
    {
      name = "adapter lowers the machine-specific facter report";
      condition = fixtureMachinesWithFacter.fixture-dgx.hardware.facter == fixtureMachine.facterReport;
    }
    {
      name = "canary exposes NixOS and Disko build outputs";
      condition = lib.isDerivation fixtureNixosToplevel && lib.isDerivation fixtureDiskoScript;
    }
    {
      name = "Disko uses the exact typed stable disk";
      condition = evaluatedFixtureNixos.disko.devices.disk.main.device == fixtureMachine.diskById;
    }
    {
      name = "Clan service shells preserve shared core behavior";
      condition = tailscaleCoreParity && irohCoreParity;
    }
    {
      name = "DGX services use the shared plain cores";
      condition =
        evaluatedFixtureNixos.services.tailscale.enable
        && builtins.hasAttr "iroh-ssh" evaluatedFixtureNixos.systemd.services
        && builtins.hasAttr fixtureServiceName evaluatedFixtureNixos.systemd.services
        &&
          builtins.elem "tailscaled.service"
            evaluatedFixtureNixos.systemd.services.${fixtureServiceName}.after
        &&
          builtins.elem fixtureMachine.meshBackend.unit
            evaluatedFixtureNixos.systemd.services.${fixtureServiceName}.after;
    }
    {
      name = "DGX runtime credentials use private SecretSpec bootstrap files";
      condition =
        fixtureMachines.fixture-dgx.install.secretspec.execution == "local"
        && fixtureSecretBootstrapNames == expectedSecretBootstrapNames
        &&
          builtins.attrNames fixtureSecretBootstrapFiles
          == lib.sort lib.lessThan (builtins.attrValues expectedRuntimeSecretFiles)
        && fixtureSecretBootstrapMetadataIsPrivate
        && evaluatedFixtureNixos.onix.dgxMachine.runtimeSecretFiles == expectedRuntimeSecretFiles
        &&
          evaluatedFixtureNixos.systemd.services.${fixtureServiceName}.serviceConfig.LoadCredential
          == [ "join-token:${expectedRuntimeSecretFiles.meshJoinToken}" ];
    }
    {
      name = "DGX access is Framework-key-only";
      condition =
        fixtureMachine.accessPolicy == "framework-only"
        && evaluatedFixtureNixos.users.users.brittonr.uid == expectedBrittonUid
        && evaluatedFixtureNixos.users.users.brittonr.openssh.authorizedKeys.keys == [ frameworkKey ]
        && evaluatedFixtureNixos.users.users.root.openssh.authorizedKeys.keys == [ frameworkKey ]
        && !(builtins.elem excludedKey evaluatedFixtureNixos.users.users.brittonr.openssh.authorizedKeys.keys);
    }
    {
      name = "all synthetic NixOS assertions pass";
      condition = fixtureAssertionsPass;
    }
  ];
  failedAdapterAssertions = lib.filter (item: !item.condition) adapterAssertions;
  sshKeygenFingerprintField = 2;
  mkHostKeyFingerprintCheck = label: knownHostsFile: expectedFingerprint: ''
    actual_fingerprint="$(ssh-keygen -lf ${knownHostsFile} -E sha256 | awk -v fingerprint_field=${toString sshKeygenFingerprintField} '{print $fingerprint_field}')"
    if [ "$actual_fingerprint" != ${lib.escapeShellArg expectedFingerprint} ]; then
      echo "${label}: SSH host-key fingerprint does not match the typed inventory" >&2
      exit 1
    fi
  '';
  productionHostKeyFingerprintChecks = lib.concatMapStrings (
    name:
    let
      machine = productionValidation.machines.${name};
    in
    mkHostKeyFingerprintCheck name (../. + "/${machine.knownHostsFile}") machine.sshHostFingerprint
  ) productionValidation.names;
in
{
  checks = lib.optionalAttrs isLinuxHost {
    dgx-devenv-interface =
      pkgs.runCommand "dgx-devenv-interface"
        {
          nativeBuildInputs = [
            canaryCli
            pkgs.coreutils
            pkgs.gnugrep
          ];
        }
        ''
          test ${lib.escapeShellArg (toString canaryRevision)} = ${lib.escapeShellArg reviewedCanaryRevision}
          test -f ${canary}/src/modules/machines.nix
          test -f ${canary}/devenv/src/devenv/machines.rs
          grep -F 'machinesMeta' ${canary}/src/modules/machines.nix
          grep -F 'build.diskoScript' ${canary}/src/modules/machines.nix
          grep -F 'install.secretspec.execution' ${canary}/src/modules/machines.nix
          grep -F 'secretspec:' ${../devenv.yaml}
          grep -F '  enable: true' ${../devenv.yaml}
          grep -F 'MachinesCommand::Info' ${canary}/devenv/src/main.rs
          grep -F 'MachinesCommand::Deploy' ${canary}/devenv/src/main.rs
          grep -F 'MachinesCommand::Install' ${canary}/devenv/src/main.rs
          ${canaryCli}/bin/devenv machines --help > "$TMPDIR/help"
          grep -F 'info' "$TMPDIR/help"
          grep -F 'deploy' "$TMPDIR/help"
          grep -F 'install' "$TMPDIR/help"
          touch $out
        '';

    dgx-machine-inventory =
      pkgs.runCommand "dgx-machine-inventory"
        {
          nativeBuildInputs = [
            pkgs.coreutils
            pkgs.diffutils
            pkgs.gawk
            pkgs.nickel
            pkgs.openssh
          ];
        }
        ''
          nickel export --format json ${dgxInventorySource}/machines.ncl > "$TMPDIR/production.json"
          cmp ${dgxInventorySource}/generated/machines.json "$TMPDIR/production.json"
          nickel export --format json ${dgxInventorySource}/fixtures/valid.ncl > "$TMPDIR/fixture.json"
          cmp ${fixtureRoot}/inventory.json "$TMPDIR/fixture.json"

          for fixture in ${dgxInventorySource}/fixtures/invalid-*.ncl; do
            if nickel export "$fixture" > /dev/null 2> "$TMPDIR/invalid.log"; then
              echo "expected Nickel fixture to fail: $fixture" >&2
              exit 1
            fi
          done

          ${mkHostKeyFingerprintCheck "fixture-dgx" "${fixtureRoot}/.machines/fixture-dgx/known_hosts"
            fixtureMachine.sshHostFingerprint
          }
          ${productionHostKeyFingerprintChecks}

          ${lib.optionalString (failedAdapterAssertions != [ ]) ''
            echo "DGX Devenv adapter checks failed:" >&2
            printf '%s\n' ${lib.escapeShellArgs (map (item: item.name) failedAdapterAssertions)} >&2
            exit 1
          ''}

          touch $out
        '';

    dgx-devenv-disko = pkgs.runCommand "dgx-devenv-disko" { } ''
      test -x ${fixtureDiskoScript}
      grep -F ${lib.escapeShellArg fixtureMachine.diskById} ${fixtureDiskoScript}
      touch $out
    '';

    dgx-machine-command =
      pkgs.runCommand "dgx-machine-command"
        {
          nativeBuildInputs = [
            fixtureDgxMachineCommand
            pkgs.coreutils
            pkgs.diffutils
            pkgs.gnugrep
          ];
        }
        ''
          fake_bin="$TMPDIR/fake-bin"
          ssh_marker="$TMPDIR/ssh-invoked"
          invocation="$TMPDIR/devenv-invocation"
          fake_ssh_exit_code=97
          mkdir -p "$fake_bin"

          cat > "$fake_bin/ssh" <<EOF
          #!${pkgs.runtimeShell}
          touch "$ssh_marker"
          exit $fake_ssh_exit_code
          EOF
          chmod +x "$fake_bin/ssh"

          export DGX_TEST_INVOCATION="$invocation"
          export PATH="$fake_bin:$PATH"

          ${lib.getExe fixtureDgxMachineCommand} info > "$TMPDIR/info.out"
          grep -F 'No machines defined in devenv.nix.' "$TMPDIR/info.out"
          printf '%s\n' machines info > "$TMPDIR/expected-info-invocation"
          cmp "$TMPDIR/expected-info-invocation" "$invocation"
          test ! -e "$ssh_marker"

          ${lib.getExe fixtureDgxMachineCommand} build fixture-dgx
          printf '%s\n' build machines.fixture-dgx > "$TMPDIR/expected-build-invocation"
          cmp "$TMPDIR/expected-build-invocation" "$invocation"
          test ! -e "$ssh_marker"

          rm -f "$invocation"
          for command in install deploy; do
            if ${lib.getExe fixtureDgxMachineCommand} "$command" > /dev/null 2> "$TMPDIR/rejected.err"; then
              echo "expected destructive command rejection: $command" >&2
              exit 1
            fi
            grep -F 'separate authorized Cairn change' "$TMPDIR/rejected.err"
            test ! -e "$invocation"
          done

          if ${lib.getExe fixtureDgxMachineCommand} build undeclared > /dev/null 2> "$TMPDIR/undeclared.err"; then
            echo "expected undeclared machine rejection" >&2
            exit 1
          fi
          grep -F 'undeclared DGX machine' "$TMPDIR/undeclared.err"
          test ! -e "$invocation"

          if ${lib.getExe fixtureDgxMachineCommand} status > /dev/null 2> "$TMPDIR/unknown.err"; then
            echo "expected unknown command rejection" >&2
            exit 1
          fi
          grep -F 'unsupported DGX command' "$TMPDIR/unknown.err"
          test ! -e "$invocation"
          test ! -e "$ssh_marker"
          touch $out
        '';
  };
}
