{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    ;
  inherit (lib.types)
    bool
    str
    nullOr
    attrsOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest.name = "vaultwarden";

  roles = {
    server = {
      interface = {
        # Freeform module - any attribute becomes a Vaultwarden environment variable
        freeformType = attrsOf anything;

        options = {
          # Optional secret management
          adminTokenFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to file containing the admin token";
          };

          enableCloudflare = mkOption {
            type = bool;
            default = false;
            description = "Enable Cloudflare tunnel for public access";
          };

          cloudflareHostname = mkOption {
            type = nullOr str;
            default = null;
            description = "Hostname for Cloudflare tunnel (e.g., vault.example.com)";
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                adminTokenFile =
                  mkDefault
                    config.clan.core.vars.generators."vaultwarden-${instanceName}".files.admin_token.path;

                # Minimal defaults
                DOMAIN = mkDefault "https://vaultwarden.localhost";
                ROCKET_PORT = mkDefault 8222;
                WEBSOCKET_ENABLED = mkDefault true;
                WEBSOCKET_PORT = mkDefault 3012;
                SIGNUPS_ALLOWED = mkDefault false;
                INVITATIONS_ALLOWED = mkDefault true;
                SHOW_PASSWORD_HINT = mkDefault false;
              };

              # Extract known options from freeform settings
              inherit (localSettings) adminTokenFile;
              enableCloudflare = localSettings.enableCloudflare or false;
              cloudflareHostname = localSettings.cloudflareHostname or null;

              # Everything else is a Vaultwarden environment variable
              environment = removeAttrs localSettings [
                "adminTokenFile"
                "enableCloudflare"
                "cloudflareHostname"
              ];

              # Tunnel credentials file path
              tunnelCredentialsFile = "/var/lib/cloudflared/vaultwarden-${instanceName}.json";
            in
            {
              # Main Vaultwarden service
              services.vaultwarden = {
                enable = true;
                config =
                  environment
                  // (
                    if enableCloudflare && cloudflareHostname != null then
                      {
                        DOMAIN = "https://${cloudflareHostname}";
                      }
                    else
                      { }
                  );
              };

              # Set admin token if provided
              systemd.services.vaultwarden = mkIf (adminTokenFile != null) {
                serviceConfig = {
                  LoadCredential = [ "admin_token:${adminTokenFile}" ];
                };
                environment.ADMIN_TOKEN_FILE = "%d/admin_token";
              };

              # Cloudflare tunnel setup service (if enabled)
              systemd.services."cloudflare-tunnel-setup-${instanceName}" = mkIf enableCloudflare {
                description = "Setup Cloudflare tunnel for Vaultwarden ${instanceName}";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                before = [ "cloudflared-tunnel-vaultwarden-${instanceName}.service" ];

                # Only run if credentials don't exist
                unitConfig = {
                  ConditionPathExists = "!${tunnelCredentialsFile}";
                };

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "cloudflared";
                  LoadCredential = [
                    "api_token:${config.clan.core.vars.generators."cloudflare-${instanceName}".files.api_token.path}"
                  ];
                };

                script = ''
                  set -euo pipefail

                  # Read API token (strip any trailing newlines)
                  API_TOKEN=$(cat "$CREDENTIALS_DIRECTORY/api_token" | tr -d '\n')

                  TUNNEL_NAME="vaultwarden-${instanceName}"
                  HOSTNAME="${cloudflareHostname}"

                  echo "Setting up Cloudflare tunnel: $TUNNEL_NAME for $HOSTNAME"

                  # Step 1: Verify token
                  echo "Verifying API token..."
                  VERIFY_RESPONSE=$(${pkgs.curl}/bin/curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json")

                  if [ "$(echo "$VERIFY_RESPONSE" | ${pkgs.jq}/bin/jq -r '.success')" != "true" ]; then
                    echo "ERROR: Token verification failed"
                    exit 1
                  fi

                  # Step 2: Extract domain parts
                  SUBDOMAIN=$(echo "$HOSTNAME" | cut -d. -f1)
                  BASE_DOMAIN=$(echo "$HOSTNAME" | cut -d. -f2-)

                  # Step 3: Get zone info (which includes account ID)
                  echo "Getting zone information for $BASE_DOMAIN..."
                  ZONE_RESPONSE=$(${pkgs.curl}/bin/curl -sf "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json")

                  ZONE_ID=$(echo "$ZONE_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result[0].id')
                  ACCOUNT_ID=$(echo "$ZONE_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result[0].account.id')

                  if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
                    echo "ERROR: Could not find zone for domain: $BASE_DOMAIN"
                    echo "Make sure the domain is added to your Cloudflare account"
                    exit 1
                  fi

                  echo "Found zone: $ZONE_ID"
                  echo "Found account: $ACCOUNT_ID"

                  # Step 4: Check if tunnel already exists
                  echo "Checking for existing tunnel..."
                  EXISTING_TUNNELS=$(${pkgs.curl}/bin/curl -sf \
                    "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel?name=$TUNNEL_NAME" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json")

                  # Filter out deleted tunnels (those with a deleted_at field)
                  ACTIVE_TUNNELS=$(echo "$EXISTING_TUNNELS" | ${pkgs.jq}/bin/jq -r '.result | map(select(.deleted_at == null))')
                  TUNNEL_COUNT=$(echo "$ACTIVE_TUNNELS" | ${pkgs.jq}/bin/jq -r 'length')

                  if [ "$TUNNEL_COUNT" -gt 0 ]; then
                    echo "Tunnel already exists, reusing it..."
                    TUNNEL_ID=$(echo "$ACTIVE_TUNNELS" | ${pkgs.jq}/bin/jq -r '.[0].id')
                    TUNNEL_SECRET=$(echo "$ACTIVE_TUNNELS" | ${pkgs.jq}/bin/jq -r '.[0].credentials_file.TunnelSecret // empty')

                    if [ -z "$TUNNEL_SECRET" ]; then
                      echo "ERROR: Tunnel exists but credentials not available"
                      echo "Please delete tunnel '$TUNNEL_NAME' at https://one.dash.cloudflare.com"
                      exit 1
                    fi
                  else
                    echo "Creating new tunnel..."
                    TUNNEL_SECRET=$(${pkgs.openssl}/bin/openssl rand -base64 32)

                    CREATE_RESPONSE=$(${pkgs.curl}/bin/curl -sf -X POST \
                      "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json" \
                      --data "{\"name\":\"$TUNNEL_NAME\",\"tunnel_secret\":\"$TUNNEL_SECRET\"}")

                    if [ "$(echo "$CREATE_RESPONSE" | ${pkgs.jq}/bin/jq -r '.success')" != "true" ]; then
                      echo "ERROR: Failed to create tunnel"
                      echo "$CREATE_RESPONSE" | ${pkgs.jq}/bin/jq '.'
                      exit 1
                    fi

                    TUNNEL_ID=$(echo "$CREATE_RESPONSE" | ${pkgs.jq}/bin/jq -r '.result.id')
                    echo "✓ Tunnel created: $TUNNEL_ID"
                  fi

                  # Step 5: Check/Create DNS record
                  echo "Checking DNS record..."
                  DNS_RECORDS=$(${pkgs.curl}/bin/curl -sf \
                    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$HOSTNAME" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json")

                  RECORD_COUNT=$(echo "$DNS_RECORDS" | ${pkgs.jq}/bin/jq -r '.result | length')
                  TUNNEL_TARGET="$TUNNEL_ID.cfargotunnel.com"

                  if [ "$RECORD_COUNT" -gt 0 ]; then
                    RECORD_ID=$(echo "$DNS_RECORDS" | ${pkgs.jq}/bin/jq -r '.result[0].id')
                    CURRENT_TARGET=$(echo "$DNS_RECORDS" | ${pkgs.jq}/bin/jq -r '.result[0].content')

                    if [ "$CURRENT_TARGET" = "$TUNNEL_TARGET" ]; then
                      echo "✓ DNS record already correct"
                    else
                      echo "Updating DNS record..."
                      ${pkgs.curl}/bin/curl -sf -X PUT \
                        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
                        -H "Authorization: Bearer $API_TOKEN" \
                        -H "Content-Type: application/json" \
                        --data "{
                          \"type\": \"CNAME\",
                          \"name\": \"$SUBDOMAIN\",
                          \"content\": \"$TUNNEL_TARGET\",
                          \"proxied\": true
                        }" > /dev/null
                      echo "✓ DNS record updated"
                    fi
                  else
                    echo "Creating DNS record..."
                    ${pkgs.curl}/bin/curl -sf -X POST \
                      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                      -H "Authorization: Bearer $API_TOKEN" \
                      -H "Content-Type: application/json" \
                      --data "{
                        \"type\": \"CNAME\",
                        \"name\": \"$SUBDOMAIN\",
                        \"content\": \"$TUNNEL_TARGET\",
                        \"proxied\": true
                      }" > /dev/null
                    echo "✓ DNS record created"
                  fi

                  # Step 6: Write credentials file
                  cat > "${tunnelCredentialsFile}" <<EOF
                  {
                    "AccountTag": "$ACCOUNT_ID",
                    "TunnelID": "$TUNNEL_ID",
                    "TunnelSecret": "$TUNNEL_SECRET"
                  }
                  EOF

                  chmod 600 "${tunnelCredentialsFile}"

                  echo "Cloudflare tunnel setup complete"
                  echo "Vaultwarden will be available at: https://$HOSTNAME"
                '';

                path = with pkgs; [
                  curl
                  jq
                  openssl
                  coreutils
                ];

                wantedBy = [ "multi-user.target" ];
              };

              # Cloudflare tunnel service (if enabled)
              services.cloudflared = mkIf enableCloudflare {
                enable = true;
                tunnels."vaultwarden-${instanceName}" = {
                  credentialsFile = tunnelCredentialsFile;
                  default = "http_status:404";
                  ingress = {
                    "${cloudflareHostname}" = {
                      service = "http://localhost:8222";
                    };
                  };
                };
              };

              # Instance-specific admin token generator
              clan.core.vars.generators."vaultwarden-${instanceName}" = {
                files.admin_token = { };
                runtimeInputs = with pkgs; [
                  coreutils
                  openssl
                ];
                script = ''
                  openssl rand -base64 48 > "$out/admin_token"
                '';
              };

              # Cloudflare API token generator (if enabled)
              clan.core.vars.generators."cloudflare-${instanceName}" = mkIf enableCloudflare {
                files.api_token = {
                  secret = true;
                  deploy = true;
                };

                prompts.api_token = {
                  description = ''
                    Cloudflare API token for creating tunnels.
                    (Assumes the domain you set this up for is managed by CloudFlare)

                    To create one:
                    1. Go to https://dash.cloudflare.com/profile/api-tokens
                    2. Click "Create Token" for a User API Token
                    3. At the bottom, select "Create Custom Token"
                    4. Set:
                        - Any name for the token
                        - Permissions:
                          - Account > Cloudflare Tunnel > Edit
                          - Zone > DNS > Edit
                        - Account Resources (appears after you set permission above)
                          - Include > Specific Zone > [your domain]
                        - Zone Resources (appears after you set permission above)
                          - Include > [your account]
                    5. Continue to summary and confirm to get the token
                    6. Copy the token here
                  '';
                  type = "hidden";
                  persist = true;
                };

                runtimeInputs = [ pkgs.coreutils ];

                script = ''
                  cat "$prompts/api_token" | tr -d '\n' > "$out/api_token"
                '';
              };

              # Open firewall ports if configured and not using Cloudflare
              networking.firewall.allowedTCPPorts = mkIf (!enableCloudflare) (
                lib.optional (environment ? ROCKET_PORT) environment.ROCKET_PORT
                ++ lib.optional (environment ? WEBSOCKET_PORT) environment.WEBSOCKET_PORT
              );
            };
        };
    };
  };

}
