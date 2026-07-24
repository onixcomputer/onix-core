# r[verify onix.radicle_node.package]
# r[verify onix.radicle_node.configuration]
# r[verify onix.radicle_node.hosting]
# r[verify onix.radicle_node.exposure]
# r[verify onix.radicle_node.validation]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  privateStateDirectoryMode = "0700";
  reviewedNodeVersion = "1.9.1";
  reviewedHttpdVersion = "0.25.0";
  minimumRejectedNodeVersion = "1.9.0";
  expectedHost = "aspen1";
  unexpectedHost = "aspen2";
  deploymentTarget = "root@aspen1.local";
  expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  nodeAddress = "100.100.103.95";
  nodePort = 8776;
  nodeInterface = "tailscale0";
  httpAddress = "127.0.0.1";
  httpPort = 8080;
  httpsPort = 443;
  identityGeneratorName = "radicle-node-radicle-forge-bootstrap";
  privateKeyFileName = "node-private-key";
  publicKeyFileName = "node-public-key";
  generatedPrivateKeyMode = "400";
  generatedPublicKeyMode = "444";
  optionalPassphraseCredential = "dev.radicle.node.passphrase";
  pinnedRepository = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";

  nodePackage = self.packages.${system}.radicle-node;
  httpdPackage = self.packages.${system}.radicle-httpd;
  validateSettings = import ../modules/radicle-node/validate-settings.nix { inherit lib; };

  positiveSettings = {
    inherit deploymentTarget;
    inherit expectedHost;
    inherit expectedNodeFingerprint;
    alias = "aspen1-radicle";
    failureDomain = "aspen-primary-site";
    nodeListenAddress = nodeAddress;
    nodeListenPort = nodePort;
    nodeFirewallInterface = nodeInterface;
    externalAddress = "${nodeAddress}:${toString nodePort}";
    httpdEnabled = true;
    httpListenAddress = httpAddress;
    httpListenPort = httpPort;
    httpsServerName = null;
    minimumSignedRefsFeature = "parent";
    pinnedRepositories = [ pinnedRepository ];
  };

  positiveValidationErrors = validateSettings {
    settings = positiveSettings;
    packageVersion = nodePackage.version;
    actualHost = expectedHost;
  };

  negativeCases = [
    {
      name = "old-package";
      settings = positiveSettings;
      packageVersion = minimumRejectedNodeVersion;
      actualHost = expectedHost;
      expected = "version ${reviewedNodeVersion} or later";
    }
    {
      name = "wrong-selected-host";
      settings = positiveSettings // {
        expectedHost = unexpectedHost;
      };
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "expectedHost must remain ${expectedHost}";
    }
    {
      name = "wrong-actual-host";
      settings = positiveSettings;
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "evaluated only on the selected host";
    }
    {
      name = "wrong-deployment-target";
      settings = positiveSettings // {
        deploymentTarget = "root@${nodeAddress}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "deploymentTarget must remain ${deploymentTarget}";
    }
    {
      name = "rotated-node-identity";
      settings = positiveSettings // {
        expectedNodeFingerprint = "SHA256:unexpected";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must preserve the recovered Aspen1 node identity";
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
      name = "missing-failure-domain";
      settings = positiveSettings // {
        failureDomain = "";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "failureDomain must not be empty";
    }
    {
      name = "wildcard-node-listener";
      settings = positiveSettings // {
        nodeListenAddress = "0.0.0.0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not be a wildcard address";
    }
    {
      name = "loopback-node-listener";
      settings = positiveSettings // {
        nodeListenAddress = httpAddress;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not be loopback";
    }
    {
      name = "loopback-firewall-interface";
      settings = positiveSettings // {
        nodeFirewallInterface = "lo";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must name one non-loopback interface";
    }
    {
      name = "url-shaped-external-address";
      settings = positiveSettings // {
        externalAddress = "https://seed.example";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "host:nodeListenPort Radicle address without a URL scheme";
    }
    {
      name = "external-port-mismatch";
      settings = positiveSettings // {
        externalAddress = "${nodeAddress}:${toString httpPort}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "host:nodeListenPort Radicle address without a URL scheme";
    }
    {
      name = "port-collision";
      settings = positiveSettings // {
        httpListenPort = nodePort;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "nodeListenPort and httpListenPort must be distinct";
    }
    {
      name = "wildcard-http-listener";
      settings = positiveSettings // {
        httpListenAddress = "[::]";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpListenAddress must remain loopback-only";
    }
    {
      name = "https-without-httpd";
      settings = positiveSettings // {
        httpdEnabled = false;
        httpsServerName = "code.onix.example";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsServerName requires the read-only HTTP gateway";
    }
    {
      name = "https-port-collision";
      settings = positiveSettings // {
        nodeListenPort = httpsPort;
        externalAddress = "${nodeAddress}:${toString httpsPort}";
        httpsServerName = "code.onix.example";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "HTTPS, native peer, and HTTP gateway ports must be distinct";
    }
    {
      name = "mdns-https-name";
      settings = positiveSettings // {
        httpsServerName = "aspen1.local";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "public DNS name";
    }
    {
      name = "weak-signed-refs";
      settings = positiveSettings // {
        minimumSignedRefsFeature = "root";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "minimumSignedRefsFeature must remain parent";
    }
    {
      name = "invalid-rid";
      settings = positiveSettings // {
        pinnedRepositories = [ "github:OnixResearch/bounded-exec" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "only rad: repository IDs";
    }
    {
      name = "duplicate-rid";
      settings = positiveSettings // {
        pinnedRepositories = [
          pinnedRepository
          pinnedRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not contain duplicate repository IDs";
    }
  ];

  negativeFailures = builtins.filter (
    case:
    let
      errors = validateSettings {
        inherit (case) settings packageVersion actualHost;
      };
    in
    !(lib.any (error: lib.hasInfix case.expected error) errors)
  ) negativeCases;

  fixtureConfig = self.nixosConfigurations.${expectedHost}.config;
  aspen2Config = self.nixosConfigurations.aspen2.config;
  aspen3Config = self.nixosConfigurations.aspen3.config;
  radicleServiceAbsent = config: !(builtins.hasAttr "radicle-node" config.systemd.services);
  identityGeneratorAbsent =
    config: !(builtins.hasAttr identityGeneratorName config.clan.core.vars.generators);

  failedAssertions = builtins.filter (assertion: !assertion.assertion) fixtureConfig.assertions;
  nodeService = fixtureConfig.systemd.services.radicle-node;
  httpdService = fixtureConfig.systemd.services.radicle-httpd;
  nodeCommand = nodeService.serviceConfig.ExecStart;
  httpdCommand = httpdService.serviceConfig.ExecStart;
  identityGenerator = fixtureConfig.clan.core.vars.generators.${identityGeneratorName};
  privateKeyFile = identityGenerator.files.${privateKeyFileName};
  publicKeyFile = identityGenerator.files.${publicKeyFileName};
  privateKeyPath = privateKeyFile.path;
  publicKeyPath = publicKeyFile.path;
  loadedPrivateKeyCredential = "dev.radicle.node.secret:${privateKeyPath}";
  expectedPublicKeyBind = "${publicKeyPath}:/var/lib/radicle/keys/radicle.pub";
  nodeImportedCredentials = lib.toList (nodeService.serviceConfig.ImportCredential or [ ]);
  nodeLoadedCredentials = lib.toList (nodeService.serviceConfig.LoadCredential or [ ]);
  httpdImportedCredentials = lib.toList (httpdService.serviceConfig.ImportCredential or [ ]);
  httpdLoadedCredentials = lib.toList (httpdService.serviceConfig.LoadCredential or [ ]);
  unexpectedNodeImports = lib.subtractLists [ optionalPassphraseCredential ] nodeImportedCredentials;
  unexpectedNodeLoads = lib.subtractLists [ loadedPrivateKeyCredential ] nodeLoadedCredentials;
  nodeBindPaths = lib.toList (nodeService.serviceConfig.BindReadOnlyPaths or [ ]);
  httpdBindPaths = lib.toList (httpdService.serviceConfig.BindReadOnlyPaths or [ ]);
  unexpectedSecretBindPaths = builtins.filter (
    path: lib.hasInfix "/run/secrets" path && path != expectedPublicKeyBind
  ) (nodeBindPaths ++ httpdBindPaths);
  globalFirewallPorts = fixtureConfig.networking.firewall.allowedTCPPorts;
  interfaceFirewallPorts =
    fixtureConfig.networking.firewall.interfaces.${nodeInterface}.allowedTCPPorts;

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  schemaValidation = wasm.evalNickelFile ../inventory/services/fixtures/radicle-node-validation.ncl;
  schemaExpectedNegativeFields = [
    "expectedHost"
    "deploymentTarget"
    "expectedNodeFingerprint"
    "alias"
    "failureDomain"
    "nodeListenAddress"
    "nodeListenPort"
    "nodeFirewallInterface"
    "externalAddress"
    "httpdEnabled"
    "httpListenAddress"
    "httpListenPort"
    "httpsServerName"
    "minimumSignedRefsFeature"
    "pinnedRepositories"
  ];
  missingSchemaNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) schemaValidation.negative)
  ) schemaExpectedNegativeFields;
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    radicle-node-policy =
      pkgs.runCommand "radicle-node-policy"
        {
          nativeBuildInputs = [
            pkgs.coreutils
            pkgs.openssh
          ];
        }
        ''
          test -x ${nodePackage}/bin/rad
          test -x ${nodePackage}/bin/radicle-node
          test -x ${httpdPackage}/bin/radicle-httpd
          test -e ${fixtureConfig.services.radicle.configFile}

          configured_fingerprint="$(ssh-keygen -lf ${publicKeyPath})"
          case "$configured_fingerprint" in
            *" ${expectedNodeFingerprint} "*) ;;
            *)
              echo "configured Radicle public key does not preserve the recovered Aspen1 identity" >&2
              exit 1
              ;;
          esac

          ${lib.optionalString (nodePackage.version != reviewedNodeVersion) ''
            echo "radicle-node version changed without updating the reviewed package identity" >&2
            exit 1
          ''}
          ${lib.optionalString (httpdPackage.version != reviewedHttpdVersion) ''
            echo "radicle-httpd version changed without updating the reviewed package identity" >&2
            exit 1
          ''}
          ${lib.optionalString (positiveValidationErrors != [ ]) ''
            echo "valid Radicle settings were rejected:" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" positiveValidationErrors)} >&2
            exit 1
          ''}
          ${lib.optionalString (negativeFailures != [ ]) ''
            echo "Radicle negative fixtures missed expected diagnostics:" >&2
            printf '%s\n' ${
              lib.escapeShellArg (lib.concatStringsSep "\n" (map (case: case.name) negativeFailures))
            } >&2
            exit 1
          ''}
          ${lib.optionalString (schemaValidation.positive != [ ]) ''
            echo "valid Nickel Radicle settings produced type errors" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" schemaValidation.positive)} >&2
            exit 1
          ''}
          ${lib.optionalString (missingSchemaNegativeFields != [ ]) ''
            echo "invalid Nickel Radicle settings missed expected fields" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSchemaNegativeFields)} >&2
            exit 1
          ''}
          ${lib.optionalString (failedAssertions != [ ]) ''
            echo "valid Radicle NixOS fixture has failed assertions:" >&2
            printf '%s\n' ${
              lib.escapeShellArg (lib.concatStringsSep "\n" (map (assertion: assertion.message) failedAssertions))
            } >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix "--listen ${nodeAddress}:${toString nodePort}" nodeCommand)) ''
            echo "Radicle node does not bind the selected explicit address" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix "--listen=${httpAddress}:${toString httpPort}" httpdCommand))
            ''
              echo "Radicle HTTP daemon is not loopback-only" >&2
              exit 1
            ''
          }
          ${lib.optionalString (!(builtins.elem optionalPassphraseCredential nodeImportedCredentials)) ''
            echo "Radicle node lost the optional passphrase credential boundary" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedNodeImports != [ ]) ''
            echo "Radicle node imports credentials outside its identity boundary" >&2
            exit 1
          ''}
          ${lib.optionalString (!(builtins.elem loadedPrivateKeyCredential nodeLoadedCredentials)) ''
            echo "Radicle node does not load the generated private key" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedNodeLoads != [ ]) ''
            echo "Radicle node loads credentials outside its generated identity" >&2
            exit 1
          ''}
          ${lib.optionalString (httpdImportedCredentials != [ ] || httpdLoadedCredentials != [ ]) ''
            echo "Radicle HTTP daemon receives credentials" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedSecretBindPaths != [ ]) ''
            echo "Radicle services bind a secret path other than the generated public key" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              !(
                builtins.elem expectedPublicKeyBind nodeBindPaths
                && builtins.elem expectedPublicKeyBind httpdBindPaths
              )
            )
            ''
              echo "Radicle services do not share the generated public identity" >&2
              exit 1
            ''
          }
          ${lib.optionalString (fixtureConfig.services.radicle.publicKey != publicKeyPath) ''
            echo "Radicle service does not consume the generated public identity" >&2
            exit 1
          ''}
          ${lib.optionalString (!(radicleServiceAbsent aspen2Config && radicleServiceAbsent aspen3Config)) ''
            echo "Radicle bootstrap service escaped Aspen1" >&2
            exit 1
          ''}
          ${lib.optionalString
            (!(identityGeneratorAbsent aspen2Config && identityGeneratorAbsent aspen3Config))
            ''
              echo "Radicle identity material escaped Aspen1" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(privateKeyFile.secret && privateKeyFile.deploy && !publicKeyFile.secret && publicKeyFile.deploy))
            ''
              echo "Radicle identity generator has unsafe secret/public deployment metadata" >&2
              exit 1
            ''
          }

          generator_out="$TMPDIR/generated-radicle-identity"
          mkdir -p "$generator_out"
          (
            export out="$generator_out"
            ${identityGenerator.script}
          )
          test "$(stat -c '%a' "$generator_out/${privateKeyFileName}")" = ${generatedPrivateKeyMode}
          test "$(stat -c '%a' "$generator_out/${publicKeyFileName}")" = ${generatedPublicKeyMode}
          ssh-keygen -y -f "$generator_out/${privateKeyFileName}" > "$TMPDIR/derived-public-key"
          cmp "$generator_out/${publicKeyFileName}" "$TMPDIR/derived-public-key"
          ${lib.optionalString (builtins.elem nodePort globalFirewallPorts) ''
            echo "Radicle peer port is globally exposed" >&2
            exit 1
          ''}
          ${lib.optionalString (!(builtins.elem nodePort interfaceFirewallPorts)) ''
            echo "Radicle peer port is absent from the selected interface" >&2
            exit 1
          ''}
          ${lib.optionalString (builtins.elem httpPort globalFirewallPorts) ''
            echo "Radicle HTTP daemon port is globally exposed" >&2
            exit 1
          ''}
          ${lib.optionalString (fixtureConfig.services.radicle.settings.node.seedingPolicy.default != "block")
            ''
              echo "Radicle node does not fail closed for unknown repositories" >&2
              exit 1
            ''
          }
          ${lib.optionalString (fixtureConfig.services.radicle.settings.node.relay != "always") ''
            echo "Radicle bootstrap node is not configured as a relay" >&2
            exit 1
          ''}
          ${lib.optionalString (fixtureConfig.services.radicle.settings.web.pinned.repositories != [ ]) ''
            echo "Radicle HTTP explorer pinned metadata drifted" >&2
            exit 1
          ''}
          ${lib.optionalString
            (nodeService.serviceConfig.User != "radicle" || httpdService.serviceConfig.User != "radicle")
            ''
              echo "Radicle services do not use the dedicated unprivileged account" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(nodeService.serviceConfig.PrivateDevices && httpdService.serviceConfig.PrivateDevices))
            ''
              echo "Radicle services can access host devices" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              !(
                nodeService.serviceConfig.MemoryDenyWriteExecute
                && httpdService.serviceConfig.MemoryDenyWriteExecute
              )
            )
            ''
              echo "Radicle services permit writable executable memory" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(nodeService.serviceConfig.NoNewPrivileges && httpdService.serviceConfig.NoNewPrivileges))
            ''
              echo "Radicle services can gain privileges" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              nodeService.serviceConfig.ProtectSystem != "strict"
              || httpdService.serviceConfig.ProtectSystem != "strict"
            )
            ''
              echo "Radicle services do not protect the host filesystem" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              nodeService.serviceConfig.StateDirectoryMode != privateStateDirectoryMode
              || httpdService.serviceConfig.StateDirectoryMode != privateStateDirectoryMode
            )
            ''
              echo "Radicle state is not private to the service account" >&2
              exit 1
            ''
          }

          touch "$out"
        '';
  };
}
