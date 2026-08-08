{
  self,
  lib,
  pkgs,
  system,
  ...
}:
let
  desktopName = "britton-desktop";
  desktopCertificateName = "${desktopName}.clan";
  expectedDeployTarget = "root@${desktopCertificateName}";
  rejectedBareDeployTarget = "root@${desktopName}";
  backupTargetAddress = "100.110.43.11";
  fingerprintField = 2;

  sshHostKeys = import ../lib/ssh-host-keys.nix { inherit lib; };
  desktopPublicKey = sshHostKeys.requirePublicKey desktopName;
  desktopPublicKeyPath = sshHostKeys.publicKeyPath desktopName;
  desktopCertificatePath = ../vars/per-machine/britton-desktop/openssh-cert/ssh.id_ed25519-cert.pub/value;
  mismatchedPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEehqswjtdQwNb4o2/hV7Qg1HCZkpbLZDDbReDoPmf/p";
  mismatchedPublicKeyPath = pkgs.writeText "mismatched-britton-desktop-host-key.pub" mismatchedPublicKey;

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  inherit ((wasm.evalNickelFile ../inventory/core/machines.ncl)) machines;
  actualDeployTarget = machines.${desktopName}.deploy.targetHost;

  desktopConfig = self.nixosConfigurations.${desktopName}.config;
  desktopKnownHostKey = desktopConfig.programs.ssh.knownHosts.${desktopName}.publicKey;
  bonsaiKnownHostKey =
    self.nixosConfigurations.bonsai.config.programs.ssh.knownHosts.${desktopName}.publicKey;
  backupKnownHosts =
    self.nixosConfigurations.aspen1.config.environment.etc."ssh/radicle-backup-known-hosts".source;
  expectedBackupKnownHost = "${backupTargetAddress} ${desktopPublicKey}";

  hostKeyConsistency =
    pkgs.runCommand "ssh-host-key-consistency" { nativeBuildInputs = [ pkgs.openssh ]; }
      ''
        set -eu

        fingerprint() {
          ssh-keygen -lf "$1" | cut -d ' ' -f ${toString fingerprintField}
        }

        fingerprints_match() {
          test "$(fingerprint "$1")" = "$(fingerprint "$2")"
        }

        if ! fingerprints_match ${desktopPublicKeyPath} ${desktopCertificatePath}; then
          echo "positive: ${desktopName} public key must match its signed host certificate" >&2
          exit 1
        fi

        if fingerprints_match ${mismatchedPublicKeyPath} ${desktopCertificatePath}; then
          echo "negative: a mismatched public key was accepted for ${desktopName}" >&2
          exit 1
        fi

        ${lib.optionalString (actualDeployTarget != expectedDeployTarget) ''
          echo "positive: ${desktopName} deploy target must use ${desktopCertificateName}" >&2
          exit 1
        ''}

        ${lib.optionalString (actualDeployTarget == rejectedBareDeployTarget) ''
          echo "negative: bare ${desktopName} deploy target bypasses the Clan certificate principal" >&2
          exit 1
        ''}

        ${lib.optionalString (desktopKnownHostKey != desktopPublicKey) ''
          echo "positive: ${desktopName} system known-host key must use the shared public key" >&2
          exit 1
        ''}

        ${lib.optionalString (bonsaiKnownHostKey != desktopPublicKey) ''
          echo "positive: bonsai known-host key must use the shared ${desktopName} public key" >&2
          exit 1
        ''}

        if ! grep -Fqx ${lib.escapeShellArg expectedBackupKnownHost} ${backupKnownHosts}; then
          echo "positive: Radicle backup must use the shared ${desktopName} public key" >&2
          exit 1
        fi

        if grep -Fq ${lib.escapeShellArg mismatchedPublicKey} ${backupKnownHosts}; then
          echo "negative: Radicle backup contains the rejected ${desktopName} public key" >&2
          exit 1
        fi

        touch "$out"
      '';
in
{
  checks =
    lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && system == machines.${desktopName}.system)
      {
        ssh-host-key-consistency = hostKeyConsistency;
      };
}
