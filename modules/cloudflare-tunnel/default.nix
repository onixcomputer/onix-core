{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    ;
  inherit (lib.types)
    str
    nullOr
    attrsOf
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "cloudflare-tunnel";
    readme = "Cloudflare tunnel service for secure internet exposure of local services";
  };

  roles = {
    default = {
      description = "Cloudflare tunnel client that exposes local services to the internet";
      interface = {
        options = {
          tunnelName = mkOption {
            type = nullOr str;
            default = null;
            description = "Name for the Cloudflare tunnel (defaults to machine hostname)";
          };

          ingress = mkOption {
            type = attrsOf str;
            default = { };
            description = ''
              Ingress rules mapping hostnames to backend services.
              Example: { "app.example.com" = "http://localhost:3000"; }
            '';
          };
        };
      };

      perInstance =
        {
          instanceName,
          extendSettings,
          ...
        }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                tunnelName = mkDefault config.networking.hostName;
              };

              inherit (localSettings) tunnelName ingress;

              # Tunnel credentials file path
              tunnelCredentialsFile = "/var/lib/cloudflared/${tunnelName}.json";

              # Extract all hostnames from ingress rules
              hostnames = builtins.attrNames ingress;

              # Generate summary for the script output
              ingressSummary = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (hostname: service: "  - https://${hostname} → ${service}") ingress
              );

              setupTunnelScript = pkgs.writeShellApplication {
                name = "cloudflare-tunnel-setup-${tunnelName}";
                runtimeInputs = with pkgs; [
                  curl
                  jq
                  openssl
                  coreutils
                  gnugrep
                ];
                text = ''
                  # Read API token (strip any trailing newlines)
                  API_TOKEN=$(tr -d '\n' <"$CREDENTIALS_DIRECTORY/api_token")

                  echo "Setting up Cloudflare tunnel: $TUNNEL_NAME"
                  echo "Ensuring DNS records are up to date for all configured hostnames..."

                  # Track whether we have a working API token
                  API_TOKEN_VALID=false

                  get_base_domain() {
                    local hostname="$1"
                    echo "$hostname" | grep -oE '[^.]+\.[^.]+$'
                  }

                  # Step 1: Verify token
                  echo "Verifying API token..."
                  if VERIFY_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" 2>&1); then
                    if [ "$(echo "$VERIFY_RESPONSE" | jq -r '.success')" = "true" ]; then
                      API_TOKEN_VALID=true
                      echo "✓ API token valid"
                    fi
                  fi

                  if [ "$API_TOKEN_VALID" = "false" ]; then
                    if [ -f "''${TUNNEL_CREDENTIALS_FILE}" ]; then
                      echo "WARNING: API token verification failed, but tunnel credentials exist"
                      echo "The tunnel will continue running with existing credentials"
                      echo "DNS records will NOT be updated until the token is refreshed"
                      echo "Regenerate with: clan vars generate --generator cloudflare-<instance>"
                      echo ""
                      echo "Cloudflare tunnel setup skipped (existing credentials preserved)"
                      exit 0
                    else
                      echo "ERROR: API token verification failed and no existing credentials"
                      echo "Regenerate with: clan vars generate --generator cloudflare-<instance>"
                      curl -s "https://api.cloudflare.com/client/v4/user/tokens/verify" \
                        -H "Authorization: Bearer $API_TOKEN" \
                        -H "Content-Type: application/json" 2>&1 | jq '.' || true
                      exit 1
                    fi
                  fi

                  # Step 2: Get account ID from the first domain
                  if [ -n "$FIRST_HOSTNAME" ]; then
                    BASE_DOMAIN=$(get_base_domain "$FIRST_HOSTNAME")
                    echo "Getting account information from domain $BASE_DOMAIN..."

                    ZONE_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json")

                    ACCOUNT_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].account.id')

                    if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "null" ]; then
                      echo "ERROR: Could not find account for domain: $BASE_DOMAIN"
                      echo "Make sure the domain is added to your Cloudflare account"
                      exit 1
                    fi

                    echo "Found account: $ACCOUNT_ID"
                  else
                    echo "ERROR: No hostnames configured"
                    exit 1
                  fi

                  # Step 3: Check if we have existing credentials locally
                  TUNNEL_ID=""
                  TUNNEL_SECRET=""
                  if [ -f "''${TUNNEL_CREDENTIALS_FILE}" ]; then
                    echo "Found existing tunnel credentials, loading them..."
                    TUNNEL_ID=$(jq -r '.TunnelID' <"''${TUNNEL_CREDENTIALS_FILE}")
                    TUNNEL_SECRET=$(jq -r '.TunnelSecret' <"''${TUNNEL_CREDENTIALS_FILE}")
                    EXISTING_ACCOUNT_ID=$(jq -r '.AccountTag' <"''${TUNNEL_CREDENTIALS_FILE}")

                    if [ "$EXISTING_ACCOUNT_ID" != "$ACCOUNT_ID" ]; then
                      echo "WARNING: Account ID mismatch. Recreating tunnel..."
                      rm -f "''${TUNNEL_CREDENTIALS_FILE}"
                      TUNNEL_ID=""
                      TUNNEL_SECRET=""
                    else
                      echo "Using existing tunnel: $TUNNEL_ID"
                    fi
                  fi

                  # Step 4: If no local credentials, check if tunnel exists remotely
                  if [ -z "$TUNNEL_ID" ]; then
                    echo "Checking for existing tunnel in Cloudflare..."
                    EXISTING_TUNNELS=$(curl -sf \
                      "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel?name=$TUNNEL_NAME" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json")

                    ACTIVE_TUNNELS=$(echo "$EXISTING_TUNNELS" | jq -r '.result | map(select(.deleted_at == null))')
                    TUNNEL_COUNT=$(echo "$ACTIVE_TUNNELS" | jq -r 'length')

                    if [ "$TUNNEL_COUNT" -gt 0 ]; then
                      echo "Tunnel already exists in Cloudflare, reusing it..."
                      TUNNEL_ID=$(echo "$ACTIVE_TUNNELS" | jq -r '.[0].id')
                      TUNNEL_SECRET=$(echo "$ACTIVE_TUNNELS" | jq -r '.[0].credentials_file.TunnelSecret // empty')

                      if [ -z "$TUNNEL_SECRET" ]; then
                        echo "ERROR: Tunnel exists but credentials not available"
                        echo "Please delete tunnel '$TUNNEL_NAME' at https://one.dash.cloudflare.com"
                        exit 1
                      fi
                    else
                      echo "Creating new tunnel..."
                      TUNNEL_SECRET=$(openssl rand -base64 32)

                      CREATE_RESPONSE=$(curl -sf -X POST \
                        "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
                        -H "Authorization: Bearer $API_TOKEN" \
                        -H "Content-Type: application/json" \
                        --data "{\"name\":\"$TUNNEL_NAME\",\"tunnel_secret\":\"$TUNNEL_SECRET\"}")

                      if [ "$(echo "$CREATE_RESPONSE" | jq -r '.success')" != "true" ]; then
                        echo "ERROR: Failed to create tunnel"
                        echo "$CREATE_RESPONSE" | jq '.'
                        exit 1
                      fi

                      TUNNEL_ID=$(echo "$CREATE_RESPONSE" | jq -r '.result.id')
                      echo "✓ Tunnel created: $TUNNEL_ID"
                    fi
                  fi

                  # Step 5: Create/Update DNS records for each hostname
                  # shellcheck disable=SC2153  # HOSTNAMES is provided by Nix module environment
                  for HOSTNAME in $HOSTNAMES; do
                    echo "Setting up DNS for ''${HOSTNAME}..."

                    BASE_DOMAIN=$(get_base_domain "$HOSTNAME")
                    SUBDOMAIN="''${HOSTNAME%."$BASE_DOMAIN"}"

                    if [ "$SUBDOMAIN" = "$HOSTNAME" ]; then
                      SUBDOMAIN="@"
                    fi

                    ZONE_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json")

                    ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')

                    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
                      echo "ERROR: Could not find zone for domain: $BASE_DOMAIN"
                      exit 1
                    fi

                    ALL_RECORDS=$(curl -sf \
                      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=''${HOSTNAME}" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json")

                    CNAME_RECORDS=$(echo "$ALL_RECORDS" | jq -r '.result[] | select(.type == "CNAME")')
                    CNAME_COUNT=$(echo "$CNAME_RECORDS" | jq -s 'length')

                    TUNNEL_TARGET="$TUNNEL_ID.cfargotunnel.com"

                    if [ "$CNAME_COUNT" -gt 0 ]; then
                      RECORD_ID=$(echo "$CNAME_RECORDS" | jq -r '.id')
                      CURRENT_TARGET=$(echo "$CNAME_RECORDS" | jq -r '.content')

                      if [ "$CURRENT_TARGET" = "$TUNNEL_TARGET" ]; then
                        echo "✓ DNS record for ''${HOSTNAME} already correct"
                      else
                        echo "Updating DNS record for ''${HOSTNAME}..."
                        curl -sf -X PUT \
                          "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
                          -H "Authorization: Bearer $API_TOKEN" \
                          -H "Content-Type: application/json" \
                          --data "{
                            \"type\": \"CNAME\",
                            \"name\": \"$SUBDOMAIN\",
                            \"content\": \"$TUNNEL_TARGET\",
                            \"proxied\": true
                          }" >/dev/null
                        echo "✓ DNS record for ''${HOSTNAME} updated"
                      fi
                    else
                      CONFLICTING_RECORDS=$(echo "$ALL_RECORDS" | jq -r '.result[] | select(.type == "A" or .type == "AAAA") | .id')

                      if [ -n "$CONFLICTING_RECORDS" ]; then
                        echo "Removing conflicting A/AAAA records for ''${HOSTNAME}..."
                        echo "$CONFLICTING_RECORDS" | while read -r record_id; do
                          if [ -n "$record_id" ]; then
                            curl -sf -X DELETE \
                              "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
                              -H "Authorization: Bearer $API_TOKEN" >/dev/null
                          fi
                        done
                      fi

                      echo "Creating DNS record for ''${HOSTNAME}..."
                      curl -sf -X POST \
                        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                        -H "Authorization: Bearer $API_TOKEN" \
                        -H "Content-Type: application/json" \
                        --data "{
                          \"type\": \"CNAME\",
                          \"name\": \"$SUBDOMAIN\",
                          \"content\": \"$TUNNEL_TARGET\",
                          \"proxied\": true
                        }" >/dev/null
                      echo "✓ DNS record for ''${HOSTNAME} created"
                    fi
                  done

                  # Step 6: Write/Update credentials file
                  cat >"''${TUNNEL_CREDENTIALS_FILE}" <<EOF
                  {
                    "AccountTag": "$ACCOUNT_ID",
                    "TunnelID": "$TUNNEL_ID",
                    "TunnelSecret": "$TUNNEL_SECRET"
                  }
                  EOF

                  chmod 600 "''${TUNNEL_CREDENTIALS_FILE}"

                  echo "Cloudflare tunnel setup complete"
                  echo "Services available at:"
                  echo "$INGRESS_SUMMARY"
                '';
              };
            in
            mkIf (ingress != { }) {
              # Cloudflare tunnel setup service
              systemd.services."cloudflare-tunnel-setup-${tunnelName}" = {
                description = "Setup Cloudflare tunnel ${tunnelName}";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                before = [ "cloudflared-tunnel-${tunnelName}.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "cloudflared";
                  LoadCredential = [
                    "api_token:${config.clan.core.vars.generators."cloudflare-${instanceName}".files.api_token.path}"
                  ];
                  ExecStart = lib.getExe setupTunnelScript;
                  Restart = "on-failure";
                  RestartSec = "30s";
                };

                # Environment variables consumed by the script
                environment = {
                  TUNNEL_NAME = tunnelName;
                  TUNNEL_CREDENTIALS_FILE = tunnelCredentialsFile;
                  HOSTNAMES = lib.concatStringsSep " " hostnames;
                  FIRST_HOSTNAME = if hostnames != [ ] then builtins.head hostnames else "";
                  INGRESS_SUMMARY = ingressSummary;
                };

                wantedBy = [ "multi-user.target" ];
              };

              # Cloudflare tunnel service
              services.cloudflared = {
                enable = true;
                tunnels."${tunnelName}" = {
                  credentialsFile = tunnelCredentialsFile;
                  default = "http_status:404";
                  inherit ingress;
                };
              };

              # Shared API token generator (per instance, shared across machines)
              clan.core.vars.generators."cloudflare-${instanceName}" = {
                share = true; # Share across all machines in the instance
                files.api_token = {
                  secret = true;
                  deploy = true;
                };

                prompts.api_token = {
                  description = ''
                    Cloudflare API token for creating tunnels.

                    To create one:
                    1. Go to https://dash.cloudflare.com/profile/api-tokens
                    2. Click "Create Token"
                    3. Use "Custom token" template with:
                       - Account > Cloudflare Tunnel > Edit
                       - Zone > DNS > Edit
                       - Zone Resources > Include > All zones
                  '';
                  type = "hidden";
                  persist = true;
                };

                runtimeInputs = [ pkgs.coreutils ];

                script = ''
                  cat "$prompts/api_token" | tr -d '\n' > "$out/api_token"
                '';
              };
            };
        };
    };
  };
}
