#!/usr/bin/env bash
set -euo pipefail

# Read API token (strip any trailing newlines)
API_TOKEN=$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/api_token")

echo "Setting up Cloudflare tunnel: $TUNNEL_NAME"
echo "Ensuring DNS records are up to date for all configured hostnames..."

get_base_domain() {
    local hostname="$1"
    # Remove subdomain(s) - everything before the domain.tld
    echo "$hostname" | grep -oE '[^.]+\.[^.]+$'
}

# Step 1: Verify token
echo "Verifying API token..."
VERIFY_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

if [ "$(echo "$VERIFY_RESPONSE" | jq -r '.success')" != "true" ]; then
  echo "ERROR: Token verification failed"
  exit 1
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
if [ -f "${TUNNEL_CREDENTIALS_FILE}" ]; then
  echo "Found existing tunnel credentials, loading them..."
  TUNNEL_ID=$(jq -r '.TunnelID' < "${TUNNEL_CREDENTIALS_FILE}")
  TUNNEL_SECRET=$(jq -r '.TunnelSecret' < "${TUNNEL_CREDENTIALS_FILE}")
  EXISTING_ACCOUNT_ID=$(jq -r '.AccountTag' < "${TUNNEL_CREDENTIALS_FILE}")
  
  # Verify the account ID matches
  if [ "$EXISTING_ACCOUNT_ID" != "$ACCOUNT_ID" ]; then
    echo "WARNING: Account ID mismatch. Recreating tunnel..."
    rm -f "${TUNNEL_CREDENTIALS_FILE}"
    TUNNEL_ID=""
    TUNNEL_SECRET=""
  else
    echo "Using existing tunnel: $TUNNEL_ID"
  fi
else
  TUNNEL_ID=""
  TUNNEL_SECRET=""
fi

# Step 4: If no local credentials, check if tunnel exists remotely
if [ -z "$TUNNEL_ID" ]; then
  echo "Checking for existing tunnel in Cloudflare..."
  EXISTING_TUNNELS=$(curl -sf \
    "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel?name=$TUNNEL_NAME" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

  # Filter out deleted tunnels (those with a deleted_at field)
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
# Process each hostname from HOSTNAMES environment variable (space-separated)
# shellcheck disable=SC2153  # HOSTNAMES is provided by Nix module environment
for HOSTNAME in $HOSTNAMES; do
  echo "Setting up DNS for ${HOSTNAME}..."

  BASE_DOMAIN=$(get_base_domain "$HOSTNAME")
  # Get everything before the base domain as subdomain
  SUBDOMAIN="${HOSTNAME%."$BASE_DOMAIN"}"

  # Get zone ID for this domain
  ZONE_RESPONSE=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$BASE_DOMAIN" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

  ZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')

  if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
    echo "ERROR: Could not find zone for domain: $BASE_DOMAIN"
    exit 1
  fi

  # Check/Create DNS record
  DNS_RECORDS=$(curl -sf \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=${HOSTNAME}" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

  RECORD_COUNT=$(echo "$DNS_RECORDS" | jq -r '.result | length')
  TUNNEL_TARGET="$TUNNEL_ID.cfargotunnel.com"

  if [ "$RECORD_COUNT" -gt 0 ]; then
    RECORD_ID=$(echo "$DNS_RECORDS" | jq -r '.result[0].id')
    CURRENT_TARGET=$(echo "$DNS_RECORDS" | jq -r '.result[0].content')

    if [ "$CURRENT_TARGET" = "$TUNNEL_TARGET" ]; then
      echo "✓ DNS record for ${HOSTNAME} already correct"
    else
      echo "Updating DNS record for ${HOSTNAME}..."
      curl -sf -X PUT \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
          \"type\": \"CNAME\",
          \"name\": \"$SUBDOMAIN\",
          \"content\": \"$TUNNEL_TARGET\",
          \"proxied\": true
        }" > /dev/null
      echo "✓ DNS record for ${HOSTNAME} updated"
    fi
  else
    echo "Creating DNS record for ${HOSTNAME}..."
    curl -sf -X POST \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\": \"CNAME\",
        \"name\": \"$SUBDOMAIN\",
        \"content\": \"$TUNNEL_TARGET\",
        \"proxied\": true
      }" > /dev/null
    echo "✓ DNS record for ${HOSTNAME} created"
  fi
done

# Step 6: Write/Update credentials file
cat > "${TUNNEL_CREDENTIALS_FILE}" <<EOF
{
  "AccountTag": "$ACCOUNT_ID",
  "TunnelID": "$TUNNEL_ID",
  "TunnelSecret": "$TUNNEL_SECRET"
}
EOF

chmod 600 "${TUNNEL_CREDENTIALS_FILE}"

echo "Cloudflare tunnel setup complete"
echo "Services available at:"
echo "$INGRESS_SUMMARY"
