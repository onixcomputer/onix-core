# r[verify onix.radicle_replica.configuration]
# r[verify onix.radicle_replica.validation]
# r[verify onix.radicle_replica.authority]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  reviewedNodeVersion = "1.9.1";
  rustEdition = "2021";
  rejectedNodeVersion = "1.9.0";
  expectedHost = "britton-desktop";
  unexpectedHost = "aspen1";
  deploymentTarget = "root@100.110.43.11";
  nodeAddress = "100.110.43.11";
  nodePort = 8776;
  wrongNodePort = 8777;
  nodeInterface = "tailscale0";
  stateDirectory = "/var/lib/radicle";
  stateDataset = "datapool/radicle-seed";
  stateQuotaGiB = 64;
  oversizedStateQuotaGiB = 65;
  expectedNodeFingerprint = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  bootstrapNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  pilotRepository = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  inheritedRepository = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
  privateCredentialName = "dev.radicle.node.secret";
  loopbackAddress = "127.0.0.1";
  disabledHttpPort = 8080;
  disabledHttpsOriginPort = 8081;

  nodePackage = self.packages.${system}.radicle-node;
  httpdPackage = self.packages.${system}.radicle-httpd;
  policyReconciler = import ../modules/radicle-node/policy-reconciler.nix { inherit pkgs; };
  validateSettings = import ../modules/radicle-seed-replica/validate-settings.nix { inherit lib; };
  mkNixosConfig = import ../modules/radicle-node/mk-nixos-config.nix { inherit lib; };

  positiveSettings = {
    inherit
      expectedHost
      deploymentTarget
      expectedNodeFingerprint
      stateDirectory
      stateDataset
      stateQuotaGiB
      ;
    alias = "britton-desktop-radicle";
    failureDomain = "britton-desktop-workstation";
    monitoringRequired = true;
    nodeListenAddress = nodeAddress;
    nodeListenPort = nodePort;
    nodeFirewallInterface = nodeInterface;
    externalAddress = "${nodeAddress}:${toString nodePort}";
    seedRepositories = [ pilotRepository ];
    minimumSignedRefsFeature = "parent";
  };

  validate =
    settings: packageVersion: actualHost:
    validateSettings { inherit settings packageVersion actualHost; };

  positiveValidationErrors = validate positiveSettings nodePackage.version expectedHost;
  negativeCases = [
    {
      name = "old-package";
      settings = positiveSettings;
      packageVersion = rejectedNodeVersion;
      actualHost = expectedHost;
      expected = reviewedNodeVersion;
    }
    {
      name = "wrong-host";
      settings = positiveSettings // {
        expectedHost = unexpectedHost;
      };
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "only on britton-desktop";
    }
    {
      name = "wrong-target";
      settings = positiveSettings // {
        deploymentTarget = "root@britton-desktop.local";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = deploymentTarget;
    }
    {
      name = "primary-failure-domain";
      settings = positiveSettings // {
        failureDomain = "aspen-primary-site";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "reviewed desktop failure domain";
    }
    {
      name = "missing-alias";
      settings = positiveSettings // {
        alias = "";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "alias must not be empty";
    }
    {
      name = "monitoring-disabled";
      settings = positiveSettings // {
        monitoringRequired = false;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "monitoring must remain required";
    }
    {
      name = "wildcard-listener";
      settings = positiveSettings // {
        nodeListenAddress = "0.0.0.0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = nodeAddress;
    }
    {
      name = "wrong-port";
      settings = positiveSettings // {
        nodeListenPort = wrongNodePort;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = toString nodePort;
    }
    {
      name = "wrong-interface";
      settings = positiveSettings // {
        nodeFirewallInterface = "eth0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = nodeInterface;
    }
    {
      name = "wrong-advertised-address";
      settings = positiveSettings // {
        externalAddress = "${loopbackAddress}:${toString nodePort}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "reviewed listener";
    }
    {
      name = "malformed-rid";
      settings = positiveSettings // {
        seedRepositories = [ "not-a-rid" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "canonical public rad:z IDs";
    }
    {
      name = "duplicate-rid";
      settings = positiveSettings // {
        seedRepositories = [
          pilotRepository
          pilotRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not contain duplicates";
    }
    {
      name = "undeclared-rid";
      settings = positiveSettings // {
        seedRepositories = [ inheritedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "exactly the governed Bounded Exec pilot RID";
    }
    {
      name = "wrong-state-directory";
      settings = positiveSettings // {
        stateDirectory = "/var/lib/radicle-shared";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = stateDirectory;
    }
    {
      name = "wrong-dataset";
      settings = positiveSettings // {
        stateDataset = "datapool/radicle-backup";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = stateDataset;
    }
    {
      name = "oversized-quota";
      settings = positiveSettings // {
        stateQuotaGiB = oversizedStateQuotaGiB;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "no greater than ${toString stateQuotaGiB} GiB";
    }
    {
      name = "weak-signed-refs";
      settings = positiveSettings // {
        minimumSignedRefsFeature = "leaf";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must remain parent";
    }
    {
      name = "malformed-fingerprint";
      settings = positiveSettings // {
        expectedNodeFingerprint = "not-a-fingerprint";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "OpenSSH SHA256 fingerprint";
    }
    {
      name = "bootstrap-key-reuse";
      settings = positiveSettings // {
        expectedNodeFingerprint = bootstrapNodeFingerprint;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not reuse the Aspen1 node identity";
    }
  ];
  negativeCasesValid = builtins.all (
    case:
    let
      errors = validate case.settings case.packageVersion case.actualHost;
    in
    errors != [ ] && builtins.any (error: lib.hasInfix case.expected error) errors
  ) negativeCases;

  loweredConfig = mkNixosConfig {
    settings = {
      inherit (positiveSettings)
        alias
        externalAddress
        nodeListenAddress
        nodeListenPort
        nodeFirewallInterface
        seedRepositories
        ;
      httpdEnabled = false;
      httpListenAddress = loopbackAddress;
      httpListenPort = disabledHttpPort;
      httpsEnabled = false;
      httpsServerName = null;
      httpsTransport = "cloudflare-tunnel";
      httpsOriginListenAddress = loopbackAddress;
      httpsOriginListenPort = disabledHttpsOriginPort;
      httpsGitRepositories = [ ];
      pinnedRepositories = [ ];
    };
    inherit nodePackage httpdPackage policyReconciler;
    privateKeyPath = "/run/credentials/radicle-node.service/${privateCredentialName}";
    publicKeyPath = "/var/lib/radicle/keys/radicle.pub";
    configFile = "/var/lib/radicle/config.json";
  };
  nativeOnlyObservations = {
    httpdDisabled = loweredConfig.services.radicle.httpd.enable == false;
    nativeListenerAddressExact = loweredConfig.services.radicle.node.listenAddress == nodeAddress;
    nativeListenerPortExact = loweredConfig.services.radicle.node.listenPort == nodePort;
    defaultBlock = loweredConfig.services.radicle.settings.node.seedingPolicy.default == "block";
    firewallInterfaceExact =
      loweredConfig.networking.firewall.interfaces.${nodeInterface}.allowedTCPPorts == [ nodePort ];
    homeProtected = loweredConfig.systemd.services.radicle-node.serviceConfig.ProtectHome;
    privilegeEscalationDenied =
      loweredConfig.systemd.services.radicle-node.serviceConfig.NoNewPrivileges;
    reconcilerNetworkDenied =
      loweredConfig.systemd.services.radicle-policy-reconcile.serviceConfig.RestrictAddressFamilies
      == [ "AF_UNIX" ];
  };
  nativeOnlyPolicyValid = builtins.all lib.id (builtins.attrValues nativeOnlyObservations);

  plugins = self.packages.${system}.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  schemaValidation = wasm.evalNickelFile ../inventory/services/fixtures/radicle-seed-replica-validation.ncl;
  schemaExpectedNegativeFields = builtins.attrNames positiveSettings;
  missingSchemaNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) schemaValidation.negative)
  ) schemaExpectedNegativeFields;
  schemaValidationValid = schemaValidation.positive == [ ] && missingSchemaNegativeFields == [ ];

  identityVerifierTests =
    pkgs.runCommand "radicle-replica-identity-verifier-tests"
      {
        nativeBuildInputs = [
          pkgs.rustc
          pkgs.stdenv.cc
        ];
      }
      ''
        rustc --edition ${rustEdition} -D warnings --test \
          ${../modules/radicle-seed-replica/identity-verifier.rs} \
          -o identity-verifier-tests
        ./identity-verifier-tests
        touch "$out"
      '';
in
{
  checks = {
    radicle-seed-replica =
      assert lib.assertMsg (
        positiveValidationErrors == [ ]
      ) "positive replica settings failed: ${builtins.toJSON positiveValidationErrors}";
      assert lib.assertMsg (
        builtins.length negativeCases > 0 && negativeCasesValid
      ) "one or more unsafe replica settings did not fail with the expected diagnostic";
      assert lib.assertMsg nativeOnlyPolicyValid
        "native-only replica lowering failed: ${builtins.toJSON nativeOnlyObservations}";
      assert lib.assertMsg schemaValidationValid
        "replica Nickel contract missed fields: ${builtins.toJSON missingSchemaNegativeFields}";
      pkgs.runCommand "radicle-seed-replica-check" { } ''
        test -e ${identityVerifierTests}
        printf '%s\n' \
          'positive_validation=passed' \
          'negative_validation=passed' \
          'native_only_policy=passed' \
          'nickel_contract=passed' \
          'identity_verifier_tests=passed' \
          > "$out"
      '';
  };
}
