{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.drift-rustfs;
  wasm = import ../../lib/wasm.nix {
    plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  };
  settings = wasm.evalNickelFile ./config.ncl;
  credentials = config.clan.core.vars.generators.${settings.generator}.files.env-file.path;
  administrator = config.clan.core.vars.generators.${settings.adminGenerator}.files.env-file.path;
  policyName = settings.generator;
  policy = pkgs.writeText "${policyName}.json" (
    builtins.toJSON (import ./policy.nix { inherit lib; } settings)
  );
  package = inputs.drift.packages.${pkgs.stdenv.hostPlatform.system}.default;
  youtubeExtractor = pkgs.yt-dlp.overridePythonAttrs (_: {
    inherit (settings.ytDlp) version;
    src = builtins.fetchTree {
      type = "github";
      owner = "yt-dlp";
      repo = "yt-dlp";
      rev = settings.ytDlp.revision;
      inherit (settings.ytDlp) narHash;
    };
  });
  authority = lib.removePrefix "http://" settings.endpoint;
  mc = lib.getExe pkgs.minio-client;
  wrapper =
    name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ youtubeExtractor ];
      text = ''
        set -a
        # The secret exists only on the deployed host.
        # shellcheck source=/dev/null
        source ${lib.escapeShellArg credentials}
        set +a
        exec ${package}/bin/${name} "$@"
      '';
    };
  provision = pkgs.writeShellScript "drift-rustfs-provision" ''
    set -eu
    umask ${settings.serviceUmask}
    MC_CONFIG_DIR="$(${pkgs.coreutils}/bin/mktemp -d)"
    export MC_CONFIG_DIR
    trap '${pkgs.coreutils}/bin/rm -rf "$MC_CONFIG_DIR"' EXIT
    export MC_HOST_storage="http://$RUSTFS_ACCESS_KEY:$RUSTFS_SECRET_KEY@${authority}"
    ${mc} mb --ignore-existing "storage/${settings.bucket}"
    printf '%s\n%s\n' "$DRIFT_S3_ACCESS_KEY_ID" "$DRIFT_S3_SECRET_ACCESS_KEY" |
      ${mc} admin user add storage
    ${mc} admin policy create storage ${lib.escapeShellArg policyName} ${policy}
    ${mc} admin policy attach storage ${lib.escapeShellArg policyName} --user "$DRIFT_S3_ACCESS_KEY_ID"
  '';
in
{
  options.services.drift-rustfs = {
    enable = lib.mkEnableOption "private Drift storage on RustFS";
    clientConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr settings.user config.users.users;
        message = "Drift credentials require an existing local user";
      }
      {
        assertion = (builtins.fromTOML (builtins.readFile "${inputs.drift}/Cargo.toml")).features ? s3;
        message = "Publish the Drift S3 migration and update the pinned Drift input before deployment";
      }
    ];
    services.drift-rustfs.clientConfig = {
      sync_enabled = true;
      user_id = settings.account;
      device_id = config.networking.hostName;
      s3 = {
        inherit (settings)
          endpoint
          bucket
          prefix
          region
          ;
        access_key_env = "DRIFT_S3_ACCESS_KEY_ID";
        secret_key_env = "DRIFT_S3_SECRET_ACCESS_KEY";
        # This endpoint is private and Tailscale encrypts traffic in transit.
        allow_http = true;
      };
    };
    clan.core.vars.generators.${settings.generator} = {
      share = true;
      files.env-file = {
        secret = true;
        deploy = true;
        owner = settings.user;
        group = "users";
        mode = settings.secretMode;
      };
      runtimeInputs = [ pkgs.openssl ];
      script = ''
        secret="$(${pkgs.openssl}/bin/openssl rand -hex ${toString settings.secretByteCount})"
        printf 'DRIFT_S3_ACCESS_KEY_ID=%s\nDRIFT_S3_SECRET_ACCESS_KEY=%s\n' \
          ${lib.escapeShellArg settings.accessKeyId} "$secret" > "$out/env-file"
      '';
    };
    system.build.driftStorageCheck = import ./verify.nix {
      inherit
        pkgs
        lib
        settings
        credentials
        ;
    };
    environment.systemPackages = map (name: lib.hiPrio (wrapper name)) [
      "drift"
      "drift-sync"
    ];
    systemd.services.drift-rustfs-provision = {
      description = "Provision private Drift storage on RustFS";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "rustfs.service"
      ];
      requires = [ "rustfs.service" ];
      path = [ pkgs.getent ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = provision;
        EnvironmentFile = [
          administrator
          credentials
        ];
        TimeoutStartSec = settings.provisionTimeoutSeconds;
        UMask = settings.serviceUmask;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        NoNewPrivileges = true;
      };
    };
  };
}
