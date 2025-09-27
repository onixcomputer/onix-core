{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.microvm.nixosModules.microvm
  ];

  networking.hostName = "app-vm-01";
  system.stateVersion = "24.05";

  nixpkgs.hostPlatform = "x86_64-linux";

  clan.core.vars.generators.app-vm-secrets = {
    files = {
      "api-key" = {
        secret = true;
        mode = "0400";
      };
      "db-password" = {
        secret = true;
        mode = "0400";
      };
      "jwt-secret" = {
        secret = true;
        mode = "0400";
      };
    };

    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];

    script = ''
      openssl rand -base64 32 | tr -d '\n' > "$out/api-key"
      openssl rand -base64 32 | tr -d '\n' > "$out/db-password"
      openssl rand -base64 64 | tr -d '\n' > "$out/jwt-secret"

      chmod 400 "$out"/*
    '';
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 2;
    mem = 1024;

    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-app01";
        mac = "02:00:00:01:02:01";
      }
    ];

    vsock.cid = 20;

    binScripts.microvm-run = lib.mkForce (
      let
        microvmCfg = config.microvm;

        apiKeyPath = config.clan.core.vars.generators.app-vm-secrets.files."api-key".path;
        dbPasswordPath = config.clan.core.vars.generators.app-vm-secrets.files."db-password".path;
        jwtSecretPath = config.clan.core.vars.generators.app-vm-secrets.files."jwt-secret".path;

        kernelPath =
          if pkgs.stdenv.system == "x86_64-linux" then
            "${microvmCfg.kernel.dev}/vmlinux"
          else
            "${microvmCfg.kernel.out}/${pkgs.stdenv.hostPlatform.linux-kernel.target}";

        kernelConsole =
          if pkgs.stdenv.system == "x86_64-linux" then
            "earlyprintk=ttyS0 console=ttyS0"
          else if pkgs.stdenv.system == "aarch64-linux" then
            "console=ttyAMA0"
          else
            "";

        kernelCmdLine = "${kernelConsole} reboot=t panic=-1 ${toString microvmCfg.kernelParams}";

        useVirtiofs = builtins.any ({ proto, ... }: proto == "virtiofs") microvmCfg.shares;

        opsMapped = ops: lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}=${v}") ops);

        memOps = opsMapped {
          size = "${toString microvmCfg.mem}M";
          mergeable = "on";
          shared = if useVirtiofs then "on" else "off";
        };

        vsockOpts =
          if microvmCfg.vsock.cid != null then
            "cid=${toString microvmCfg.vsock.cid},socket=notify.vsock"
          else
            "";

        tapMultiQueue = microvmCfg.vcpu > 1;

        netArgs = map (
          {
            type,
            id,
            mac,
            ...
          }:
          if type == "tap" then
            opsMapped (
              {
                tap = id;
                inherit mac;
              }
              // (if tapMultiQueue then { num_queues = toString (2 * microvmCfg.vcpu); } else { })
            )
          else
            throw "Unsupported interface type ${type}"
        ) microvmCfg.interfaces;

        fsArgs = map (
          {
            proto,
            socket,
            tag,
            ...
          }:
          if proto == "virtiofs" then
            opsMapped { inherit tag socket; }
          else
            throw "cloud-hypervisor supports only virtiofs"
        ) microvmCfg.shares;

      in
      ''
        set -eou pipefail

        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  MicroVM: ${config.networking.hostName}"
        echo "║  Loading Runtime Secrets via Clan Vars"
        echo "╚══════════════════════════════════════════════════════════╝"

        if [ -f "${apiKeyPath}" ]; then
          API_KEY=$(cat "${apiKeyPath}" | tr -d '\n')
          echo "✓ Loaded API_KEY"
        else
          echo "❌ ERROR: API key not found at ${apiKeyPath}"
          echo "Run: clan vars generate ${config.networking.hostName}"
          exit 1
        fi

        if [ -f "${dbPasswordPath}" ]; then
          DB_PASSWORD=$(cat "${dbPasswordPath}" | tr -d '\n')
          echo "✓ Loaded DB_PASSWORD"
        else
          echo "❌ ERROR: DB password not found"
          exit 1
        fi

        if [ -f "${jwtSecretPath}" ]; then
          JWT_SECRET=$(cat "${jwtSecretPath}" | tr -d '\n')
          echo "✓ Loaded JWT_SECRET"
        else
          echo "❌ ERROR: JWT secret not found"
          exit 1
        fi

        RUNTIME_OEM_STRINGS="io.systemd.credential:API_KEY=$API_KEY"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:DB_PASSWORD=$DB_PASSWORD"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:JWT_SECRET=$JWT_SECRET"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:ENVIRONMENT=production"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:HOSTNAME=${config.networking.hostName}"

        ${lib.optionalString (microvmCfg.vsock.cid != null) ''
          RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:vmm.notify_socket=vsock-stream:2:8888"
        ''}

        PLATFORM_OPS="oem_strings=[$RUNTIME_OEM_STRINGS]"

        echo "✓ Runtime secrets loaded and OEM strings prepared"
        echo "══════════════════════════════════════════════════════════"

        ${microvmCfg.preStart}

        ${lib.optionalString (microvmCfg.socket != null) ''
          rm -f '${microvmCfg.socket}'
        ''}

        ${lib.optionalString (microvmCfg.vsock.cid != null) ''
          rm -f notify.vsock notify.vsock_8888

          if [ -n "''${NOTIFY_SOCKET:-}" ]; then
            ${pkgs.socat}/bin/socat -T2 UNIX-LISTEN:notify.vsock_8888,fork UNIX-SENDTO:$NOTIFY_SOCKET &
          fi
        ''}

        exec ${lib.optionalString microvmCfg.prettyProcnames ''-a "microvm@${config.networking.hostName}"''} \
          ${pkgs.cloud-hypervisor}/bin/cloud-hypervisor \
          --cpus boot=${toString microvmCfg.vcpu} \
          --watchdog \
          --kernel ${kernelPath} \
          --initramfs ${microvmCfg.initrdPath} \
          --cmdline "${kernelCmdLine}" \
          --seccomp true \
          --memory ${memOps} \
          --platform "$PLATFORM_OPS" \
          --console null \
          --serial tty \
          ${lib.optionalString (vsockOpts != "") "--vsock ${vsockOpts}"} \
          ${
            lib.optionalString (netArgs != [ ]) (lib.concatMapStringsSep " " (arg: "--net ${arg}") netArgs)
          } \
          ${lib.optionalString (fsArgs != [ ]) (lib.concatMapStringsSep " " (arg: "--fs ${arg}") fsArgs)} \
          ${lib.optionalString (microvmCfg.socket != null) "--api-socket ${microvmCfg.socket}"}
      ''
    );
  };

  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWRuKC+rVQ9exqHdlu7YZHxCjT5VvNZ9JlMyML9pqj brittonr@britton-desktop"
  ];

  systemd.services.demo-credentials-app = {
    description = "Demo Application Using OEM Credentials";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      LoadCredential = [
        "api-key:API_KEY"
        "db-password:DB_PASSWORD"
        "jwt-secret:JWT_SECRET"
        "environment:ENVIRONMENT"
        "hostname:HOSTNAME"
      ];
    };

    script = ''
      echo "╔═══════════════════════════════════════════════════════════════╗"
      echo "║            Application Credentials Loaded                    ║"
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""
      echo "✓ Credentials available:"
      ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|HOSTNAME" || true
      echo ""
      echo "Configuration:"
      echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment 2>/dev/null || echo 'N/A')"
      echo "  HOSTNAME    = $(cat $CREDENTIALS_DIRECTORY/hostname 2>/dev/null || echo 'N/A')"
      echo ""
      echo "Secrets (length check):"
      echo "  API_KEY     = $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') bytes"
      echo "  DB_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/db-password 2>/dev/null || echo '0') bytes"
      echo "  JWT_SECRET  = $(wc -c < $CREDENTIALS_DIRECTORY/jwt-secret 2>/dev/null || echo '0') bytes"
      echo ""
      echo "✓ All credentials successfully loaded from OEM strings"
      echo "══════════════════════════════════════════════════════════════════"
    '';
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    jq
  ];
}
