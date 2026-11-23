# Live-pilot guest: the opt-in kiln-implementer stages with real credentials
# supplied at run time from a read-only host directory, and one admitted model
# route to the host's underclass gateway. Nothing starts a stage by itself.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kilnPilot;
  root = "/var/lib/kiln-implementation";
  credentials = "/run/kiln-pilot-credentials";
  netns = "kiln-implementation-model";
  socket = "/run/kiln-pilot-model/gateway.sock";
  relayUid = 936;
  bridgePort = lib.toInt (
    lib.last (
      lib.splitString ":" (lib.head (lib.splitString "/" (lib.removePrefix "http://" cfg.model.endpoint)))
    )
  );
in
{
  imports = [ ../nixos.nix ];
  options.kilnPilot = {
    cohort = lib.mkOption { type = lib.types.package; };
    inputs = lib.mkOption { type = lib.types.package; };
    model = lib.mkOption { type = lib.types.attrs; };
    caseName = lib.mkOption { type = lib.types.str; };
    repositoryKey = lib.mkOption { type = lib.types.str; };
    base = lib.mkOption {
      type = lib.types.strMatching "[0-9a-f]{40}";
      description = "Exact enrolled baseline commit";
    };
    credentialShare = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Share $KILN_PILOT_CREDENTIALS read-only into the guest; the boot check runs without it";
    };
  };
  config = {
    system.stateVersion = "26.05";
    networking = {
      hostName = "kiln-pilot-${cfg.caseName}";
      # Egress inside the guest: only the relay reaches the gateway; the Kiln
      # stage accounts get GitHub HTTPS (intake/publisher) or nothing.
      nftables = {
        enable = true;
        tables.kiln-pilot-egress = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority 0; policy accept;
              oifname "lo" accept
              ct state established,related accept
              meta skuid ${toString relayUid} ip daddr ${cfg.model.upstream.address} tcp dport ${toString cfg.model.upstream.port} accept
              ip daddr ${cfg.model.upstream.address} tcp dport ${toString cfg.model.upstream.port} drop
              meta skuid { 930, 932 } tcp dport 443 accept
              meta skuid { 930, 931, 932, 933, ${toString relayUid} } drop
            }
          '';
        };
      };
      firewall.enable = true;
    };
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      diskSize = 16384;
      graphics = false;
      # Host directory with intake, publisher and model files (dir 0700,
      # files 0600, owned by the invoking user); never in the Nix store.
      sharedDirectories = lib.mkIf cfg.credentialShare {
        kiln-pilot-credentials = {
          source = "$KILN_PILOT_CREDENTIALS";
          target = credentials;
        };
      };
    };
    fileSystems = lib.mkIf cfg.credentialShare {
      ${credentials}.options = [
        "nosuid"
        "nodev"
        "noexec"
      ];
    };

    services = {
      kiln-implementer = {
        enable = true;
        inherit (cfg) cohort;
        configuration = cfg.inputs.configuration;
        attemptBundle = cfg.inputs.attemptBundle;
        ciServiceProfile = cfg.inputs.ciServiceProfile;
        canonicalCiStatePaths = [ "${root}/canonical-ci" ];
        repositories = [ cfg.repositoryKey ];
        workClasses = [ (if cfg.caseName == "bug" then "bug" else "bounded-feature") ];
        # The owner accepted one token value for this pilot; the two files stay
        # separate paths and are loaded only by their own stage units.
        intakeCredential = "${credentials}/intake";
        publisherCredential = "${credentials}/publisher";
        modelCredential = if cfg.model.credential then "${credentials}/model" else null;
        modelNetworkNamespace = "/run/netns/${netns}";
        leaseMilliseconds = 3600000;
        # Kiln local-operator authority for every protected stage (claim through publish).
        localOperator = "brittonr";
        timeoutSeconds = 3600;
      };
      # Operator control: root over SSH with public-key authentication only.
      # The authorized key is the share's `ssh.pub`, copied at boot; the private
      # key stays on the host outside the share and the store. QEMU forwards
      # only host 127.0.0.1:2222 to guest port 22.
      openssh = {
        enable = true;
        authorizedKeysInHomedir = false;
        authorizedKeysFiles = [ "/run/kiln-pilot-ssh/%u" ];
        settings = {
          PermitRootLogin = "prohibit-password";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          AllowUsers = [ "root" ];
          AllowTcpForwarding = "no";
          AllowAgentForwarding = false;
          AllowStreamLocalForwarding = "no";
          X11Forwarding = false;
          PermitTunnel = "no";
        };
      };
      getty.autologinUser = "root";
    };

    users.users.kiln-pilot-relay = {
      isSystemUser = true;
      uid = relayUid;
      group = "kiln-pilot-relay";
    };
    users.groups.kiln-pilot-relay = { };

    # The canonical Engine state the verifier is authorized to own.
    systemd = {
      tmpfiles.rules = [
        "d ${root}/canonical-ci 0700 kiln-implementation-verifier kiln-implementation-ledger -"
      ];

      services = {
        # The dispatcher (Lattice's host-side broker) joins this namespace. It
        # holds only loopback; its one way out is the bridge below.
        kiln-pilot-model-netns = {
          description = "Kiln pilot model namespace (loopback only)";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.iproute2}/bin/ip netns add ${netns}
            ${pkgs.iproute2}/bin/ip -n ${netns} link set lo up
          '';
          preStop = "${pkgs.iproute2}/bin/ip netns delete ${netns}";
        };
        # Host-side relay with a fixed destination: the gateway, nothing else.
        kiln-pilot-model-relay = {
          description = "Kiln pilot relay to the host underclass gateway";
          serviceConfig = {
            User = "kiln-pilot-relay";
            Group = "kiln-pilot-relay";
            RuntimeDirectory = "kiln-pilot-model";
            RuntimeDirectoryMode = "0700";
            ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:${socket},fork,mode=0600,unlink-early TCP4:${cfg.model.upstream.address}:${toString cfg.model.upstream.port}";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
            ];
            IPAddressDeny = "any";
            IPAddressAllow = [ cfg.model.upstream.address ];
          };
        };
        # In-namespace loopback listener for the broker's literal-loopback endpoint.
        kiln-pilot-model-bridge = {
          description = "Kiln pilot loopback bridge inside the model namespace";
          requires = [
            "kiln-pilot-model-netns.service"
            "kiln-pilot-model-relay.service"
          ];
          after = [
            "kiln-pilot-model-netns.service"
            "kiln-pilot-model-relay.service"
          ];
          serviceConfig = {
            User = "kiln-pilot-relay";
            Group = "kiln-pilot-relay";
            NetworkNamespacePath = "/run/netns/${netns}";
            ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString bridgePort},bind=127.0.0.1,fork,reuseaddr UNIX-CONNECT:${socket}";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
            ];
          };
        };
        kiln-implementation-dispatch = {
          requires = [ "kiln-pilot-model-bridge.service" ];
          after = [ "kiln-pilot-model-bridge.service" ];
        };
        kiln-implementation-recover-dispatch = {
          requires = [ "kiln-pilot-model-netns.service" ];
          after = [ "kiln-pilot-model-netns.service" ];
        };
        # The CI service opens the enrolled repository the acquisition stage
        # clones; enrollment (and so verify) orders after it.
        kiln-implementation-ci-enroll.after = [ "kiln-pilot-acquire-verifier-source.service" ];
        # Trusted verifier acquisition of the exact enrolled repository; read-only
        # GitHub access with the intake token, run once by the operator.
        kiln-pilot-acquire-verifier-source = {
          description = "Acquire the enrolled repository into the protected verifier store";
          requires = [ "kiln-implementation-policy-check.service" ];
          after = [
            "kiln-implementation-policy-check.service"
            "network-online.target"
          ];
          path = [
            pkgs.git
            pkgs.coreutils
          ];
          environment.GIT_ASKPASS = toString (
            pkgs.writeShellScript "kiln-pilot-askpass" ''
              case "$1" in
                Username*) printf '%s\n' x-access-token ;;
                *) cat "$CREDENTIALS_DIRECTORY/intake" ;;
              esac
            ''
          );
          serviceConfig = {
            Type = "oneshot";
            LoadCredential = [ "intake:${credentials}/intake" ];
            InaccessiblePaths = [ "-${credentials}" ];
          };
          script = ''
            set -eu
            repository=${root}/verifier/repository
            if ! test -f "$repository/HEAD"; then
              git -c credential.helper= -c core.askPass="$GIT_ASKPASS" clone --bare --no-tags \
                https://github.com/${cfg.repositoryKey}.git "$repository.new"
              rm -rf "$repository"
              mv "$repository.new" "$repository"
            fi
            git --git-dir="$repository" cat-file -e ${cfg.base}^{commit}
            chown -R kiln-implementation-verifier:kiln-implementation-ledger "$repository"
            chmod 0700 "$repository"
          '';
        };
        kiln-pilot-ssh-authorized-key = {
          description = "Install the operator's SSH public key from the credentials share";
          wantedBy = [ "sshd.service" ];
          before = [ "sshd.service" ];
          after = [ "local-fs.target" ];
          path = [
            pkgs.openssh
            pkgs.coreutils
            pkgs.gnugrep
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -eu
            install -d -m 0755 -o root -g root /run/kiln-pilot-ssh
            rm -f /run/kiln-pilot-ssh/root
            source=${credentials}/ssh.pub
            if ! test -f "$source"; then
              echo "no $source: root SSH login stays disabled" >&2
              exit 0
            fi
            # A private key in the share would be visible to this guest: refuse.
            if grep -rlq -- "PRIVATE KEY" ${credentials}; then
              echo "the credentials share contains a private key; refusing SSH" >&2
              exit 1
            fi
            test "$(grep -c . "$source")" = 1
            ssh-keygen -l -f "$source" > /dev/null
            install -m 0600 -o root -g root "$source" /run/kiln-pilot-ssh/root
          '';
        };
      };
    };
    virtualisation.forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];

    environment.systemPackages = [
      pkgs.jq
      pkgs.git
      pkgs.b3sum
      pkgs.curl
      pkgs.iproute2
      pkgs.nftables
      pkgs.util-linux
      pkgs.gnutar
      pkgs.gzip
    ];
    environment.etc."kiln-implementation/pilot-manifest.json".source =
      "${cfg.inputs}/pilot-manifest.json";
  };
}
