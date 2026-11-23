{
  self,
  pkgs,
  lib,
  ...
}:
let
  evaluate =
    settings:
    (import "${self.inputs.nixpkgs}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/kiln-implementer/nixos.nix
        {
          system.stateVersion = "26.05";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/null";
            fsType = "ext4";
          };
          services.kiln-implementer = settings;
        }
      ];
    }).config;
  # Empty package paths are evaluation fixtures, never fake-worker execution.
  baseline = {
    enable = true;
    cohort = pkgs.emptyDirectory;
    configuration = pkgs.emptyDirectory;
    attemptBundle = pkgs.emptyDirectory;
    intakeCredential = "/run/secrets/test-intake";
    publisherCredential = "/run/secrets/test-publisher";
    repositories = [ "owner/repository" ];
    workClasses = [ "bug" ];
    ciServiceProfile = "${pkgs.emptyDirectory}/canonical-ci-profile.ncl";
    canonicalCiStatePaths = [ "/var/lib/existing-canonical-ci" ];
  };
  campaignBaseline = baseline // {
    selectedCampaignEnable = true;
    selectedCampaignProfile = pkgs.emptyDirectory;
    selectedCampaignId = "selected-cairn-example";
    selectedCampaignDatabase = "/var/lib/canonical-cairn/campaign.sqlite";
    selectedImplementationDatabase = "/var/lib/canonical-kiln/work.sqlite";
    selectedCampaignBoundInputDirectory = "/var/lib/kiln-implementation/campaign/bound";
    selectedCampaignCandidateExportDirectory = "/var/lib/kiln-implementation/campaign/export";
    selectedCampaignWorkspaceRoot = "/var/lib/kiln-implementation/campaign/workspaces";
    selectedCampaignDataGid = 931;
    selectedCampaignCredentialPath = "/var/lib/publisher-runtime/github.token";
  };
  campaign = evaluate campaignBaseline;
  campaignUnit = campaign.systemd.services."${stem}-drive-selected-campaign@".serviceConfig;
  campaignDefault = enabled.systemd.services ? "${stem}-drive-selected-campaign@";
  enabled = evaluate baseline;
  disabled = evaluate { enable = false; };
  assertionsPass = config: builtins.all (item: item.assertion) config.assertions;
  assertionsFail = config: builtins.any (item: !item.assertion) config.assertions;
  units = enabled.systemd.services;
  stem = "kiln-implementation";
  publisher = units."${stem}-publish".serviceConfig;
  dispatcher = units."${stem}-dispatch".serviceConfig;
  namespaced =
    (evaluate (baseline // { modelNetworkNamespace = "/run/netns/qualified-model"; }))
    .systemd.services."${stem}-dispatch".serviceConfig;
  # A model key reaches only the first-run dispatcher (Lattice's host broker).
  credentialed =
    (evaluate (
      baseline
      // {
        modelNetworkNamespace = "/run/netns/qualified-model";
        modelCredential = "/run/secrets/test-model";
      }
    )).systemd.services;
  modelCredentialScoped =
    credentialed."${stem}-dispatch".serviceConfig.LoadCredential == [ "model:/run/secrets/test-model" ]
    && lib.hasInfix "--model-credential-env" (
      builtins.toJSON credentialed."${stem}-dispatch".serviceConfig.ExecStartPre
    )
    && lib.hasInfix "--model-credential-env" (
      builtins.toJSON credentialed."${stem}-bind-dispatch".serviceConfig.ExecStart
    )
    && !(credentialed."${stem}-recover-dispatch".serviceConfig ? LoadCredential)
    && !(credentialed."${stem}-verify".serviceConfig ? LoadCredential)
    && !(credentialed."${stem}-capture-candidate".serviceConfig ? LoadCredential)
    &&
      credentialed."${stem}-publish".serviceConfig.LoadCredential
      == [ "github:/run/secrets/test-publisher" ]
    && builtins.elem "-/run/secrets" credentialed."${stem}-dispatch".serviceConfig.InaccessiblePaths
    && builtins.elem "-/run/secrets" credentialed."${stem}-verify".serviceConfig.InaccessiblePaths;
  # Kiln implementation authority (docs/implementation-runbook.md): every unit
  # reaching a protected operation carries the deployment's local-operator
  # selection in its own ExecStart; none carries it when none is selected.
  protectedUnits = [
    "claim"
    "bind-dispatch"
    "host-owner-admit"
    "host-owner-observe"
    "host-owner-reserve"
    "host-owner-release"
    "dispatch"
    "recover-dispatch"
    "capture-candidate"
    "verify"
    "prepare-publication"
    "publish"
  ];
  operated = (evaluate (baseline // { localOperator = "check-operator"; })).systemd.services;
  operatorScoped =
    lib.all (
      unit:
      lib.hasInfix "--local-operator check-operator" (
        builtins.toJSON operated."${stem}-${unit}".serviceConfig.ExecStart
      )
    ) protectedUnits
    && lib.all (
      unit:
      !(lib.hasInfix "--local-operator" (builtins.toJSON units."${stem}-${unit}".serviceConfig.ExecStart))
    ) protectedUnits;
  guestRejects =
    lib.all
      (
        settings:
        !(builtins.tryEval (
          (import ../modules/kiln-implementer/guest.nix) (
            {
              nixpkgs = self.inputs.nixpkgs;
              cohort = null;
              vmm = null;
            }
            // settings
          )
        )).success
      )
      [
        { system = "aarch64-linux"; }
        { cpus = 0; }
        { memoryMiB = 128; }
        { memoryBacking = "shared"; }
        { mergeable = true; }
      ];
  valid =
    assertionsPass enabled
    && operatorScoped
    && !(disabled.systemd.services ? "${stem}-publish")
    && units."${stem}-publish".wantedBy == [ ]
    && units."${stem}-dispatch".wantedBy == [ ]
    && publisher.User != dispatcher.User
    && publisher.LoadCredential == [ "github:/run/secrets/test-publisher" ]
    && !(dispatcher ? LoadCredential)
    && dispatcher.PrivateNetwork
    && dispatcher.Restart == "no"
    && publisher.Restart == "no"
    && dispatcher.User == "${stem}-executor"
    && dispatcher.Group == "${stem}-ledger"
    && enabled.users.users."${stem}-executor".group == "${stem}-executor"
    && !(builtins.elem "${stem}-ledger" enabled.users.users."${stem}-executor".extraGroups)
    && namespaced.NetworkNamespacePath == "/run/netns/qualified-model"
    && !namespaced.PrivateNetwork
    && modelCredentialScoped
    &&
      dispatcher.ReadWritePaths == [
        "/var/lib/${stem}/kiln"
        "/var/lib/${stem}/workspaces"
        "/var/lib/${stem}/lattice"
      ]
    && lib.hasInfix "check-attempt" (builtins.toJSON dispatcher.ExecStartPre)
    && lib.hasInfix "materialize-binding" (
      builtins.toJSON units."${stem}-bind-dispatch".serviceConfig.ExecStart
    )
    # Controller units run Kiln as the coordinator and seal in "!" root
    # phases; none keeps an account-switching capability.
    &&
      lib.all
        (
          unit:
          let
            config = units."${stem}-${unit}".serviceConfig;
          in
          config.User == "${stem}-coordinator"
          && config.NoNewPrivileges
          &&
            config.CapabilityBoundingSet == [
              "CAP_CHOWN"
              "CAP_DAC_OVERRIDE"
              "CAP_FOWNER"
            ]
        )
        [
          "claim"
          "prepare-fixture-intake"
          "bind-dispatch"
          "bind-publication"
        ]
    &&
      map (line: builtins.substring 0 1 line) units."${stem}-bind-dispatch".serviceConfig.ExecStart == [
        "/"
        "!"
        "/"
        "!"
      ]
    &&
      map (line: builtins.substring 0 1 line) units."${stem}-claim".serviceConfig.ExecStart == [
        "/"
        "!"
      ]
    # Only the units that launch Lattice's bwrap worker get AF_NETLINK and lose
    # ProtectKernelTunables; every other stage keeps both.
    &&
      lib.all
        (
          unit:
          let
            config = units."${stem}-${unit}".serviceConfig;
          in
          builtins.elem "AF_NETLINK" config.RestrictAddressFamilies
          && !config.ProtectKernelTunables
          && config.NoNewPrivileges
          && config.PrivateDevices
          && config.ProtectControlGroups
          && config.CapabilityBoundingSet == ""
        )
        [
          "dispatch"
          "recover-dispatch"
        ]
    &&
      lib.all
        (
          unit:
          let
            config = unit.serviceConfig;
          in
          !(builtins.elem "AF_NETLINK" (config.RestrictAddressFamilies or [ ]))
          && (config.ProtectKernelTunables or true)
        )
        (
          lib.attrValues (
            lib.filterAttrs (
              unit: _:
              lib.hasPrefix "${stem}-" unit
              && !(builtins.elem unit [
                "${stem}-dispatch"
                "${stem}-recover-dispatch"
              ])
            ) units
          )
        )
    && lib.hasInfix "publish-bound" (builtins.toJSON publisher.ExecStart)
    && lib.hasInfix "dispatch-bound" (builtins.toJSON dispatcher.ExecStart)
    && lib.hasInfix "recover-dispatch-bound" (
      builtins.toJSON units."${stem}-recover-dispatch".serviceConfig.ExecStart
    )
    && !(units ? "${stem}-worker")
    && !(units ? "${stem}-lattice")
    && !(units ? "${stem}-land")
    &&
      lib.all
        (
          stage: units ? "${stem}-host-owner-${stage}" && units."${stem}-host-owner-${stage}".wantedBy == [ ]
        )
        [
          "admit"
          "observe"
          "reserve"
          "release"
        ]
    && !(units ? "${stem}-admission@")
    && units."${stem}-verify".serviceConfig.User != dispatcher.User
    && units."${stem}-capture-candidate".serviceConfig.User == "${stem}-verifier"
    &&
      units."${stem}-verify".serviceConfig.ReadWritePaths == [
        "/var/lib/${stem}/kiln"
        "/var/lib/${stem}/verifier"
        "/var/lib/existing-canonical-ci"
      ]
    # Verification needs the project enrolled in the canonical CI service
    # state; enrollment runs as the verifier, loopback-only, after its
    # private TLS key and tokens exist.
    && lib.all (field: builtins.elem "${stem}-ci-enroll.service" units."${stem}-verify".${field}) [
      "requires"
      "after"
    ]
    &&
      lib.all (field: builtins.elem "${stem}-ci-credentials.service" units."${stem}-ci-enroll".${field})
        [
          "requires"
          "after"
        ]
    &&
      lib.all
        (
          unit:
          let
            config = units."${stem}-${unit}".serviceConfig;
          in
          config.User == "${stem}-verifier"
          && config.PrivateNetwork
          && config.NoNewPrivileges
          && config.CapabilityBoundingSet == ""
        )
        [
          "ci-credentials"
          "ci-enroll"
        ]
    && units."${stem}-ci-credentials".serviceConfig.RuntimeDirectoryMode == "0700"
    && units."${stem}-ci-enroll".serviceConfig.ReadWritePaths == [ "/var/lib/existing-canonical-ci" ]
    && lib.hasInfix "policy-check" (builtins.toJSON units."${stem}-dispatch".requires)
    && assertionsPass campaign
    && !campaignDefault
    && campaignUnit.User == "root"
    && campaignUnit.Restart == "no"
    && campaign.systemd.services."${stem}-drive-selected-campaign@".wantedBy == [ ]
    && campaignUnit.PrivateNetwork
    && !(campaignUnit ? LoadCredential)
    &&
      campaignUnit.CapabilityBoundingSet == [
        "CAP_CHOWN"
        "CAP_DAC_OVERRIDE"
        "CAP_KILL"
        "CAP_SETGID"
        "CAP_SETPCAP"
        "CAP_SETUID"
      ]
    &&
      campaignUnit.ReadWritePaths == lib.unique (
        [
          (builtins.dirOf campaignBaseline.selectedCampaignDatabase)
          (builtins.dirOf campaignBaseline.selectedImplementationDatabase)
          campaignBaseline.selectedCampaignBoundInputDirectory
          campaignBaseline.selectedCampaignCandidateExportDirectory
          campaignBaseline.selectedCampaignWorkspaceRoot
          "/var/lib/${stem}/lattice"
          "/var/lib/${stem}/verifier"
        ]
        ++ campaignBaseline.canonicalCiStatePaths
      )
    && campaignUnit.ReadOnlyPaths == [ campaignBaseline.selectedCampaignCredentialPath ]
    && lib.hasInfix "drive-implementation-campaign" (builtins.toJSON campaignUnit.ExecStart)
    && lib.hasInfix "--expected-version" (builtins.toJSON campaignUnit.ExecStart)
    && campaign.users.groups."${stem}-executor".gid == campaignBaseline.selectedCampaignDataGid;
  invalid =
    assertionsFail (evaluate (baseline // { repositories = [ ]; }))
    && assertionsFail (evaluate (baseline // { workClasses = [ ]; }))
    && assertionsFail (evaluate (baseline // { publisherCredential = baseline.intakeCredential; }))
    && assertionsFail (evaluate (baseline // { executorUid = 930; }))
    && assertionsFail (evaluate (baseline // { modelCredential = baseline.publisherCredential; }))
    && assertionsFail (evaluate (baseline // { modelCredential = "/nix/store/leaked-model-key"; }))
    && assertionsFail (evaluate (baseline // { canonicalCiStatePaths = [ ]; }))
    && assertionsFail (evaluate (baseline // { ciServiceProfile = null; }))
    && assertionsFail (evaluate (baseline // { configuration = "/var/lib/mutable-policy"; }))
    && assertionsFail (evaluate (baseline // { cohort = "/var/lib/mutable-programs"; }))
    && assertionsFail (evaluate (baseline // { intakeCredential = "/nix/store/leaked-token"; }))
    && assertionsFail (evaluate (campaignBaseline // { selectedCampaignProfile = null; }))
    && assertionsFail (evaluate (campaignBaseline // { selectedCampaignDataGid = null; }))
    && assertionsFail (
      evaluate (campaignBaseline // { selectedCampaignBoundInputDirectory = "/var/lib/outside/bound"; })
    )
    && assertionsFail (
      evaluate (campaignBaseline // { selectedCampaignDatabase = "/var/lib/shared.sqlite"; })
    )
    && assertionsFail (
      evaluate (campaignBaseline // { selectedCampaignCredentialPath = "/run/secrets/unscoped"; })
    );
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    kiln-implementation-module =
      assert lib.assertMsg (
        valid && invalid && guestRejects
      ) "Implementation authority/default/invalid module or guest refusal cases failed";
      pkgs.runCommand "kiln-implementation-module-evaluation" { } ''
        mkdir "$out"
        printf '%s\n' 'evaluation only, not runtime qualification' > "$out/scope"
      '';
    kiln-implementation-campaign-contract =
      pkgs.runCommand "kiln-implementation-campaign-contract"
        {
          nativeBuildInputs = [
            pkgs.nickel
            pkgs.jq
          ];
        }
        ''
          nickel export --format json ${../modules/kiln-implementer}/fixtures/positive-verification-routes.ncl > "$TMPDIR/valid.json"
          jq -e '.verification_routes.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa == {"ci_service_profile": "/etc/ci/service.json", "verification_profile": "/etc/ci/verification.json"}' "$TMPDIR/valid.json" >/dev/null
          if nickel export --format json ${../modules/kiln-implementer}/fixtures/negative-verification-routes.ncl > "$TMPDIR/invalid.json" 2> "$TMPDIR/invalid.err"; then
            echo "malformed campaign verification route unexpectedly passed" >&2
            exit 1
          fi
          touch "$out"
        '';
    kiln-implementation-device-free =
      pkgs.runCommand "kiln-implementation-device-free"
        {
          nativeBuildInputs = [
            (pkgs.python3.withPackages (python: [ python.pytest ]))
            pkgs.git
          ];
        }
        ''
          mkdir -p source/tests source/modules/kiln-implementer
          cp ${../tests/test_kiln_implementation_deployment.py} source/tests/test_kiln_implementation_deployment.py
          cp ${../tests/kiln-implementation-github-fixture.py} source/tests/kiln-implementation-github-fixture.py
          cp ${../modules/kiln-implementer/qualification.py} source/modules/kiln-implementer/qualification.py
          python3 -m pytest -v -p no:cacheprovider source/tests/test_kiln_implementation_deployment.py
          mkdir "$out"
          printf '%s\n' 'device-free fixtures, not live worker/KVM evidence' > "$out/scope"
        '';
  };
}
