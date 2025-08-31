{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tailscale-host-sync;
in
{
  options.services.tailscale-host-sync = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.services.tailscale.enable;
      description = "Sync Tailscale device names to /etc/hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      services.tailscale-host-sync = {
        description = "Sync Tailscale hostnames to /etc/hosts";
        after = [ "tailscaled.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "tailscale-host-sync" ''
            # Exit if tailscale isn't ready
            ${pkgs.tailscale}/bin/tailscale status --json &>/dev/null || exit 0

            # Get current peers
            TEMP=$(mktemp)
            trap 'rm -f $TEMP' EXIT

            ${pkgs.tailscale}/bin/tailscale status --json | \
              ${pkgs.jq}/bin/jq -r '.Peer[] | select(.DNSName and .DNSName != "") | .DNSName as $dns | select($dns | split(".")[0] != "" and ($dns | split(".")[0] != null)) | "\(.TailscaleIPs[0]) \($dns | split(".")[0])"' | \
              grep -v " null$" | \
              sort > "$TEMP"

            # Get existing tailscale entries from /etc/hosts
            OLD_CONTENT=$(${pkgs.gnused}/bin/sed -n '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/p' /etc/hosts 2>/dev/null | \
              ${pkgs.gnused}/bin/sed '1d;$d' | sort)
            NEW_CONTENT=$(cat "$TEMP")

            # Only update if content changed
            if [ "$OLD_CONTENT" != "$NEW_CONTENT" ]; then
              ${pkgs.gnused}/bin/sed '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/d' /etc/hosts > /etc/hosts.new

              if [ -s "$TEMP" ]; then
                echo "# TAILSCALE-ALIASES-START" >> /etc/hosts.new
                cat "$TEMP" >> /etc/hosts.new
                echo "# TAILSCALE-ALIASES-END" >> /etc/hosts.new
              fi

              ${pkgs.coreutils}/bin/mv -f /etc/hosts.new /etc/hosts
            fi
          '';
        };
      };

      timers.tailscale-host-sync = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1min";
        };
      };
    };
  };
}
