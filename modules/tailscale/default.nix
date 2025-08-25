{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    ;
in
{
  _class = "clan.service";
  manifest.name = "tailscale";
  # Define available roles
  roles = {
    # Standard node that joins the tailnet
    peer = {
      interface = {
        options = {
          enableSSH = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable SSH server through Tailscale";
          };
          autoconnect = mkOption {
            type = bool;
            default = true;
            description = "Whether to auto-connect to the tailnet";
          };
          authKeyFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to the auth key file to use for automatic authentication";
          };
          exitNode = mkOption {
            type = bool;
            default = false;
            description = "Whether to advertise this machine as an exit node";
          };
          extraFlags = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional flags to pass to the Tailscale daemon";
          };
          enableHostAliases = mkOption {
            type = bool;
            default = true;
            description = "Whether to automatically create /etc/hosts aliases for shared Tailscale devices";
          };
        };
      };
      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings { };
              # Create generator name based on instance name
              generatorName = "tailscale-${instanceName}";
              # Override authKeyFile to use the instance-specific generator
              settings = localSettings // {
                authKeyFile = lib.mkDefault config.clan.core.vars.generators."${generatorName}".files.auth_key.path;
              };
            in
            {
              # Create vars generator for Tailscale auth keys (per instance)
              clan.core.vars.generators."${generatorName}" = {
                share = true;
                files.auth_key = { };
                runtimeInputs = [ pkgs.coreutils ];
                prompts.auth_key = {
                  description = "Tailscale auth key for instance '${instanceName}'";
                  type = "hidden";
                  persist = true;
                };
                script = ''
                  cat "$prompts"/auth_key > "$out"/auth_key
                '';
              };

              services.tailscale = {
                enable = true;
                useRoutingFeatures = "both";
                inherit (settings) authKeyFile;
                extraUpFlags =
                  (lib.optional settings.autoconnect "--ssh=${if settings.enableSSH then "true" else "false"}")
                  ++ (lib.optional settings.exitNode "--advertise-exit-node")
                  ++ settings.extraFlags;
              };

              # Override the tailscaled-autoconnect service to not block boot
              systemd.services.tailscaled-autoconnect = lib.mkIf settings.autoconnect {
                # Don't block boot - remove from multi-user.target
                wantedBy = lib.mkForce [ ];
              };

              # Dynamic host alias synchronization service
              systemd.services.tailscale-hosts-sync = lib.mkIf settings.enableHostAliases {
                description = "Sync Tailscale shared device hostnames to /etc/hosts";
                after = [ "tailscaled.service" ];
                requires = [ "tailscaled.service" ];
                wantedBy = [ "multi-user.target" ];

                # Restart when tailscaled restarts
                bindsTo = [ "tailscaled.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${pkgs.writeShellScript "tailscale-hosts-sync" ''
                    set -euo pipefail

                    # Wait for Tailscale to be ready (max 30 seconds)
                    timeout=30
                    while ! ${pkgs.tailscale}/bin/tailscale status --json >/dev/null 2>&1; do
                      sleep 1
                      timeout=$((timeout - 1))
                      if [ $timeout -eq 0 ]; then
                        echo "Tailscale not ready after 30 seconds, exiting"
                        exit 0
                      fi
                    done

                    # Get our own tailnet suffix for identifying shared devices
                    MY_SUFFIX=$(${pkgs.tailscale}/bin/tailscale status --json | \
                      ${pkgs.jq}/bin/jq -r '.Self.DNSName' | \
                      ${pkgs.gnused}/bin/sed 's/^[^.]*\.//' | \
                      ${pkgs.gnused}/bin/sed 's/\.$//')

                    if [ -z "$MY_SUFFIX" ]; then
                      echo "Could not determine local tailnet suffix, skipping alias generation"
                      exit 0
                    fi

                    # Create temporary file for new hosts entries
                    TEMP_FILE=$(${pkgs.coreutils}/bin/mktemp)
                    trap "${pkgs.coreutils}/bin/rm -f $TEMP_FILE" EXIT

                    # Track seen names to handle duplicates
                    declare -A seen_names

                    # Collect all devices into arrays for processing
                    declare -a local_devices=()
                    declare -a shared_devices=()

                    # Parse Tailscale peers and categorize them
                    while IFS=$'\t' read -r ip short suffix; do
                      if [ "$suffix" = "$MY_SUFFIX" ]; then
                        local_devices+=("$ip $short")
                      else
                        shared_devices+=("$ip $short")
                      fi
                    done < <(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r '
                      .Peer[] |
                      select(.DNSName) |
                      select(.DNSName | test("\\.ts\\.net")) |
                      "\(.TailscaleIPs[0])\t\(.DNSName | split(".")[0])\t\(.DNSName | gsub("^[^.]*\\."; "") | gsub("\\.$"; ""))"
                    ')

                    # Process local devices first (they get priority for short names)
                    for entry in "''${local_devices[@]}"; do
                      read -r ip name <<< "$entry"
                      echo "$ip $name" >> "$TEMP_FILE"
                      seen_names[$name]="local"
                    done

                    # Process shared devices (suffix if name conflicts)
                    for entry in "''${shared_devices[@]}"; do
                      read -r ip name <<< "$entry"
                      if [ "''${seen_names[$name]:-}" != "" ]; then
                        # Name collision, add suffix
                        echo "$ip $name-shared" >> "$TEMP_FILE"
                      else
                        echo "$ip $name" >> "$TEMP_FILE"
                        seen_names[$name]="shared"
                      fi
                    done

                    # Update /etc/hosts atomically
                    # First, create a copy of current /etc/hosts without our section
                    ${pkgs.gnused}/bin/sed '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/d' /etc/hosts > /etc/hosts.new

                    # Add our new section if we have any entries
                    if [ -s "$TEMP_FILE" ]; then
                      echo "# TAILSCALE-ALIASES-START" >> /etc/hosts.new
                      ${pkgs.coreutils}/bin/cat "$TEMP_FILE" >> /etc/hosts.new
                      echo "# TAILSCALE-ALIASES-END" >> /etc/hosts.new
                    fi

                    # Move new file into place
                    ${pkgs.coreutils}/bin/mv -f /etc/hosts.new /etc/hosts

                    echo "Tailscale host aliases synchronized successfully"
                  ''}";
                };
              };

              # Open firewall ports for Tailscale
              networking.firewall = {
                # Enable checksum offload as recommended by Tailscale
                checkReversePath = "loose";
                trustedInterfaces = [ "tailscale0" ];
                allowedUDPPorts = [ 41641 ]; # Tailscale UDP port
              };

              # Configure NAT for exit nodes
              networking.nat = lib.mkIf settings.exitNode {
                enable = true;
                # If already configured, preserve the existing settings
                externalInterface = lib.mkDefault (lib.mkIf (config.networking.interfaces ? "eth0") "eth0");
                internalInterfaces = [ "tailscale0" ];
              };
            };
        };
    };
  };
  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Install Tailscale package on all machines
        environment.systemPackages = [ pkgs.tailscale ];

        # Make the Tailscale service persistent
        systemd.services.tailscaled.wantedBy = [ "multi-user.target" ];
      };
  };
}
