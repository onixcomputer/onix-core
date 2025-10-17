#!/usr/bin/env bash
# Keycloak Admin User Creation Testing Script
# Tests various methods for creating the initial Keycloak admin user

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

KEYCLOAK_URL="https://auth.robitzs.ch"
TEST_DIR="/tmp/keycloak-admin-tests"
mkdir -p "$TEST_DIR"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test 1: KC_BOOTSTRAP_* Environment Variables (Modern Method)
test_kc_bootstrap_env_vars() {
    log "Testing KC_BOOTSTRAP_* environment variables..."

    cat > "$TEST_DIR/test-kc-bootstrap.nix" << 'EOF'
# Test configuration for KC_BOOTSTRAP_* environment variables
{ lib, config, pkgs, ... }:
{
  services.keycloak = {
    enable = true;

    # Database configuration
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };

    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };

  # Set KC_BOOTSTRAP_* environment variables for Keycloak service
  systemd.services.keycloak = {
    environment = {
      KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
      KC_BOOTSTRAP_ADMIN_PASSWORD = "admin-adeci";
    };
  };

  services.postgresql.enable = true;
}
EOF

    success "KC_BOOTSTRAP_* environment variables test configuration created"
}

# Test 2: KEYCLOAK_ADMIN Environment Variables (Legacy Method)
test_keycloak_admin_env_vars() {
    log "Testing KEYCLOAK_ADMIN environment variables (legacy)..."

    cat > "$TEST_DIR/test-keycloak-admin.nix" << 'EOF'
# Test configuration for KEYCLOAK_ADMIN environment variables
{ lib, config, pkgs, ... }:
{
  services.keycloak = {
    enable = true;

    # Database configuration
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };

    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };

  # Set legacy KEYCLOAK_ADMIN environment variables
  systemd.services.keycloak = {
    environment = {
      KEYCLOAK_ADMIN = "admin";
      KEYCLOAK_ADMIN_PASSWORD = "admin-adeci";
    };
  };

  services.postgresql.enable = true;
}
EOF

    success "KEYCLOAK_ADMIN environment variables test configuration created"
}

# Test 3: initialAdminPassword Option (Current Method)
test_initial_admin_password() {
    log "Testing initialAdminPassword option (current method)..."

    cat > "$TEST_DIR/test-initial-admin.nix" << 'EOF'
# Test configuration for initialAdminPassword option
{ lib, config, pkgs, ... }:
{
  services.keycloak = {
    enable = true;

    # Use initialAdminPassword option
    initialAdminPassword = "admin-adeci";

    # Database configuration
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };

    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };

  services.postgresql.enable = true;
}
EOF

    success "initialAdminPassword test configuration created"
}

# Test 4: Command Line Bootstrap Parameters
test_command_line_bootstrap() {
    log "Testing command line bootstrap parameters..."

    cat > "$TEST_DIR/test-cli-bootstrap.nix" << 'EOF'
# Test configuration for command line bootstrap parameters
{ lib, config, pkgs, ... }:
{
  services.keycloak = {
    enable = true;

    # Database configuration
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };

    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };

  # Override the systemd service to include bootstrap parameters
  systemd.services.keycloak = {
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.keycloak}/bin/kc.sh start --bootstrap-admin-username=admin --bootstrap-admin-password=admin-adeci --optimized";
    };
  };

  services.postgresql.enable = true;
}
EOF

    success "Command line bootstrap test configuration created"
}

# Test 5: Database-Level Admin User Creation
test_database_admin_creation() {
    log "Testing direct database admin user creation..."

    cat > "$TEST_DIR/create-admin-db.sql" << 'EOF'
-- SQL script to create Keycloak admin user directly in database
-- This is for testing purposes and should be done carefully

-- Insert admin user into KEYCLOAK_USER table (realm_id for master realm needed)
-- Note: This is a complex process as Keycloak uses many related tables

-- First, we need the master realm ID
-- INSERT INTO USER_ENTITY (ID, EMAIL, EMAIL_CONSTRAINT, EMAIL_VERIFIED, ENABLED, FEDERATION_LINK, FIRST_NAME, LAST_NAME, REALM_ID, USERNAME, CREATED_TIMESTAMP, SERVICE_ACCOUNT_CLIENT_LINK, NOT_BEFORE)
-- VALUES ('admin-user-id', 'admin@example.com', 'admin@example.com', true, true, null, 'Admin', 'User', 'master', 'admin', extract(epoch from now()) * 1000, null, 0);

-- This requires multiple table inserts and is very complex
-- Better to use Keycloak's own mechanisms
EOF

    cat > "$TEST_DIR/test-db-creation.sh" << 'EOF'
#!/bin/bash
# Database-level admin creation test script

echo "⚠️  Direct database manipulation is complex and not recommended"
echo "   Keycloak uses many interconnected tables for user management"
echo "   This method requires deep knowledge of Keycloak's database schema"
echo "   Prefer using Keycloak's own admin creation mechanisms"

# Example of what would be needed:
echo "Tables that would need to be modified:"
echo "- USER_ENTITY (main user record)"
echo "- CREDENTIAL (password hash)"
echo "- USER_ROLE_MAPPING (assign admin roles)"
echo "- And potentially many others..."
EOF

    chmod +x "$TEST_DIR/test-db-creation.sh"

    warning "Database admin creation is complex - script created but not recommended"
}

# Test 6: kcadm.sh CLI Tool
test_kcadm_cli() {
    log "Testing kcadm.sh CLI tool for admin creation..."

    cat > "$TEST_DIR/test-kcadm.sh" << 'EOF'
#!/bin/bash
# Test script for kcadm.sh admin user creation

KEYCLOAK_URL="https://auth.robitzs.ch"
KCADM="/nix/store/*/bin/kcadm.sh"  # Need to find actual path

echo "Testing kcadm.sh admin user creation..."

# First, need to authenticate with temporary admin
# This requires a temporary admin to already exist
echo "Step 1: Configure kcadm.sh"
$KCADM config credentials --server $KEYCLOAK_URL --realm master --user admin --password admin-adeci

echo "Step 2: Create permanent admin user"
$KCADM create users -r master -s username=permanent-admin -s enabled=true -s email=admin@robitzs.ch

echo "Step 3: Set password for permanent admin"
$KCADM set-password -r master --username permanent-admin --new-password SecurePassword123!

echo "Step 4: Assign admin roles"
$KCADM add-roles -r master --uusername permanent-admin --rolename admin

echo "✅ Permanent admin user created via kcadm.sh"
EOF

    chmod +x "$TEST_DIR/test-kcadm.sh"

    success "kcadm.sh test script created"
}

# Test 7: REST API Admin Creation
test_rest_api_creation() {
    log "Testing REST API admin user creation..."

    cat > "$TEST_DIR/test-rest-api.sh" << 'EOF'
#!/bin/bash
# Test script for REST API admin user creation

KEYCLOAK_URL="https://auth.robitzs.ch"
ADMIN_USER="admin"
ADMIN_PASS="admin-adeci"

echo "Testing REST API admin user creation..."

# Step 1: Get access token
echo "Step 1: Getting access token..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid_connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASS" \
  -d "grant_type=password" \
  -d "client_id=admin-cli")

if [ $? -eq 0 ]; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

    if [ "$ACCESS_TOKEN" != "null" ] && [ "$ACCESS_TOKEN" != "" ]; then
        echo "✅ Successfully obtained access token"

        # Step 2: Create new admin user
        echo "Step 2: Creating new admin user..."
        curl -s -X POST "$KEYCLOAK_URL/admin/realms/master/users" \
          -H "Authorization: Bearer $ACCESS_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "username": "permanent-admin",
            "email": "admin@robitzs.ch",
            "firstName": "Permanent",
            "lastName": "Admin",
            "enabled": true,
            "emailVerified": true,
            "credentials": [{
              "type": "password",
              "value": "SecurePassword123!",
              "temporary": false
            }]
          }'

        if [ $? -eq 0 ]; then
            echo "✅ Admin user created via REST API"
        else
            echo "❌ Failed to create admin user"
        fi
    else
        echo "❌ Failed to get access token"
    fi
else
    echo "❌ Failed to connect to Keycloak"
fi
EOF

    chmod +x "$TEST_DIR/test-rest-api.sh"

    success "REST API test script created"
}

# Test 8: Keycloak Bootstrap Command
test_bootstrap_command() {
    log "Testing Keycloak bootstrap command..."

    cat > "$TEST_DIR/test-bootstrap-command.nix" << 'EOF'
# Test configuration using bootstrap-admin command
{ lib, config, pkgs, ... }:
{
  services.keycloak = {
    enable = true;

    # Database configuration
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };

    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };

  # Create a pre-start script that runs bootstrap-admin before normal startup
  systemd.services.keycloak-bootstrap = {
    description = "Bootstrap Keycloak admin user";
    wantedBy = [ "keycloak.service" ];
    before = [ "keycloak.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "keycloak";
      Group = "keycloak";
    };
    script = ''
      # Only run bootstrap if no admin exists yet
      if ! ${pkgs.keycloak}/bin/kc.sh show-config --db-url-host=localhost --db-username=keycloak 2>/dev/null | grep -q "admin"; then
        ${pkgs.keycloak}/bin/kc.sh bootstrap-admin --bootstrap-admin-username=admin --bootstrap-admin-password=admin-adeci
      fi
    '';
  };

  services.postgresql.enable = true;
}
EOF

    success "Bootstrap command test configuration created"
}

# Main test execution
main() {
    log "Starting Keycloak admin user creation method testing..."

    echo -e "\n${BLUE}🔑 Keycloak Admin User Creation Testing Suite${NC}"
    echo -e "${BLUE}================================================${NC}\n"

    test_kc_bootstrap_env_vars
    test_keycloak_admin_env_vars
    test_initial_admin_password
    test_command_line_bootstrap
    test_database_admin_creation
    test_kcadm_cli
    test_rest_api_creation
    test_bootstrap_command

    echo -e "\n${GREEN}✅ All test configurations created successfully!${NC}"
    echo -e "\n${BLUE}Test files created in: $TEST_DIR${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Review the test configurations"
    echo "2. Apply individual test configurations to test different methods"
    echo "3. Monitor Keycloak logs for admin user creation"
    echo "4. Test admin console access with different credentials"
    echo "5. Document which methods work successfully"

    echo -e "\n${BLUE}Recommended testing order:${NC}"
    echo "1. initialAdminPassword (current method) - test-initial-admin.nix"
    echo "2. KC_BOOTSTRAP_* environment variables - test-kc-bootstrap.nix"
    echo "3. Command line bootstrap - test-cli-bootstrap.nix"
    echo "4. KEYCLOAK_ADMIN environment variables - test-keycloak-admin.nix"
    echo "5. kcadm.sh CLI tool - test-kcadm.sh"
    echo "6. REST API creation - test-rest-api.sh"
    echo "7. Bootstrap command - test-bootstrap-command.nix"
}

# Run the main function
main "$@"