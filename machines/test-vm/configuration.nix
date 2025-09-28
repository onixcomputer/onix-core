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

  networking.hostName = "test-vm";
  system.stateVersion = "24.05";

  nixpkgs.hostPlatform = "x86_64-linux";

  clan.core.vars.generators.test-vm-secrets = {
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
        id = "vm-test";
        mac = "02:00:00:01:01:01";
      }
    ];

    vsock.cid = 3;

    binScripts.microvm-run = lib.mkForce (
      let
        microvmCfg = config.microvm;

        apiKeyPath = config.clan.core.vars.generators.test-vm-secrets.files."api-key".path;
        dbPasswordPath = config.clan.core.vars.generators.test-vm-secrets.files."db-password".path;
        jwtSecretPath = config.clan.core.vars.generators.test-vm-secrets.files."jwt-secret".path;

        kernelPath = "${microvmCfg.kernel.dev}/vmlinux";
        kernelCmdLine = "earlyprintk=ttyS0 console=ttyS0 reboot=t panic=-1 ${toString microvmCfg.kernelParams}";

        memOps = "size=${toString microvmCfg.mem}M,mergeable=on,shared=on";
        vsockOpts = "cid=${toString microvmCfg.vsock.cid},socket=notify.vsock";
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
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:ENVIRONMENT=test"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:HOSTNAME=${config.networking.hostName}"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:vmm.notify_socket=vsock-stream:2:8888"

        PLATFORM_OPS="oem_strings=[$RUNTIME_OEM_STRINGS]"

        echo "✓ Runtime secrets loaded and OEM strings prepared"
        echo "══════════════════════════════════════════════════════════"

        ${microvmCfg.preStart}

        rm -f notify.vsock notify.vsock_8888

        if [ -n "''${NOTIFY_SOCKET:-}" ]; then
          ${pkgs.socat}/bin/socat -T2 UNIX-LISTEN:notify.vsock_8888,fork UNIX-SENDTO:$NOTIFY_SOCKET &
        fi

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
          --vsock ${vsockOpts} \
          --fs socket=test-vm-virtiofs-ro-store.sock,tag=ro-store \
          --api-socket test-vm.sock \
          --net mac=02:00:00:01:01:01,num_queues=4,tap=vm-test
      ''
    );
  };

  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [
    22
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = lib.mkForce true;
    };
  };

  users.users.root.initialPassword = "test";
  services.getty.autologinUser = "root";

  systemd.services.demo-oem-credentials = {
    description = "Demo service showing OEM string credentials with runtime secrets";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      LoadCredential = [
        "environment:ENVIRONMENT"
        "hostname:HOSTNAME"
        "api-key:API_KEY"
        "db-password:DB_PASSWORD"
        "jwt-secret:JWT_SECRET"
      ];
    };

    script = ''
      echo "╔═══════════════════════════════════════════════════════════════╗"
      echo "║  OEM String Credentials with Runtime Secrets (test-vm)      ║"
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""
      echo "✓ systemd credentials available:"
      ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|HOSTNAME" || echo "  (none found)"
      echo ""
      echo "Static Configuration:"
      echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment 2>/dev/null || echo 'N/A')"
      echo "  HOSTNAME    = $(cat $CREDENTIALS_DIRECTORY/hostname 2>/dev/null || echo 'N/A')"
      echo ""
      echo "Runtime Secrets (length check):"
      echo "  API_KEY     = $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') bytes"
      echo "  DB_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/db-password 2>/dev/null || echo '0') bytes"
      echo "  JWT_SECRET  = $(wc -c < $CREDENTIALS_DIRECTORY/jwt-secret 2>/dev/null || echo '0') bytes"
      echo ""
      if [ $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') -gt 10 ]; then
        echo "✓ Runtime secrets successfully loaded from HOST clan vars via OEM strings!"
      else
        echo "⚠️  Runtime secrets not loaded"
      fi
      echo ""
      echo "✓ OEM string credentials (static + runtime) successfully loaded via SMBIOS Type 11"
      echo "══════════════════════════════════════════════════════════════════"
    '';
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
  ];
}
