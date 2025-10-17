#!/usr/bin/env bash
# Test script for updated Keycloak admin creation configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEYCLOAK_URL="https://auth.robitzs.ch"
USERNAME="admin"
PASSWORD="admin-adeci"

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

# Test basic connectivity
test_connectivity() {
    log "Testing basic connectivity to Keycloak..."

    if curl -k -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/" | grep -q "200"; then
        success "Keycloak is accessible at $KEYCLOAK_URL"
        return 0
    else
        error "Keycloak is not accessible at $KEYCLOAK_URL"
        return 1
    fi
}

# Test admin authentication with various endpoints
test_admin_authentication() {
    log "Testing admin authentication..."

    # Define multiple endpoint patterns to try
    local base_paths=("" "/auth")
    local protocol_paths=("protocol/openid_connect" "protocol/openid-connect")
    local client_ids=("admin-cli" "security-admin-console" "account")

    for base in "${base_paths[@]}"; do
        for protocol in "${protocol_paths[@]}"; do
            for client_id in "${client_ids[@]}"; do
                local endpoint="$base/realms/master/$protocol/token"
                log "Testing: $KEYCLOAK_URL$endpoint with client: $client_id"

                response=$(curl -k -s -X POST "$KEYCLOAK_URL$endpoint" \
                    -H "Content-Type: application/x-www-form-urlencoded" \
                    -d "username=$USERNAME" \
                    -d "password=$PASSWORD" \
                    -d "grant_type=password" \
                    -d "client_id=$client_id" 2>/dev/null || echo '{"error":"failed"}')

                if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
                    success "Authentication successful!"
                    success "Working endpoint: $endpoint"
                    success "Working client ID: $client_id"

                    # Get token for further testing
                    access_token=$(echo "$response" | jq -r '.access_token')

                    # Test admin API access
                    log "Testing admin API access..."
                    api_response=$(curl -k -s -H "Authorization: Bearer $access_token" \
                        "$KEYCLOAK_URL/admin/realms" 2>/dev/null || echo "[]")

                    if echo "$api_response" | jq -e '.[0].realm' >/dev/null 2>&1; then
                        success "Admin API access successful"
                        local realm_count=$(echo "$api_response" | jq length)
                        success "Found $realm_count realm(s)"

                        # List realms
                        echo "Available realms:"
                        echo "$api_response" | jq -r '.[].realm' | sed 's/^/  - /'
                    else
                        warning "Admin API access failed"
                    fi

                    return 0
                else
                    echo "  Response: $response"
                fi
            done
        done
    done

    error "No working authentication endpoints found"
    return 1
}

# Test master realm configuration
test_master_realm() {
    log "Testing master realm configuration..."

    local config_paths=(
        "/realms/master/.well-known/openid_connect_configuration"
        "/auth/realms/master/.well-known/openid_connect_configuration"
        "/realms/master/.well-known/openid-connect-configuration"
        "/auth/realms/master/.well-known/openid-connect-configuration"
    )

    for path in "${config_paths[@]}"; do
        log "Testing realm config: $KEYCLOAK_URL$path"

        response=$(curl -k -s "$KEYCLOAK_URL$path" 2>/dev/null || echo '{"error":"not_found"}')

        if echo "$response" | jq -e '.token_endpoint' >/dev/null 2>&1; then
            success "Master realm configuration found"

            echo "Configuration details:"
            echo "  Token endpoint: $(echo "$response" | jq -r '.token_endpoint')"
            echo "  Authorization endpoint: $(echo "$response" | jq -r '.authorization_endpoint')"
            echo "  Issuer: $(echo "$response" | jq -r '.issuer')"
            echo "  Admin console: $KEYCLOAK_URL/admin/"

            return 0
        fi
    done

    error "Master realm configuration not found"
    return 1
}

# Test kcadm.sh tool
test_kcadm_tool() {
    log "Testing kcadm.sh CLI tool..."

    local kcadm_path=$(find /nix/store -name "kcadm.sh" -type f 2>/dev/null | head -1)

    if [ -z "$kcadm_path" ]; then
        error "kcadm.sh not found"
        return 1
    fi

    log "Using kcadm.sh from: $kcadm_path"

    # Test authentication
    result=$("$kcadm_path" config credentials --server "$KEYCLOAK_URL" --realm master --user "$USERNAME" --password "$PASSWORD" 2>&1 || echo "AUTH_FAILED")

    if echo "$result" | grep -q "Logging into"; then
        success "kcadm.sh authentication successful"

        # List users
        users_result=$("$kcadm_path" get users -r master 2>/dev/null || echo "[]")
        if echo "$users_result" | jq -e '.[0].username' >/dev/null 2>&1; then
            success "kcadm.sh can list users"
            local user_count=$(echo "$users_result" | jq length)
            success "Found $user_count user(s)"

            echo "Users in master realm:"
            echo "$users_result" | jq -r '.[].username' | sed 's/^/  - /'
        else
            warning "kcadm.sh cannot list users"
        fi

        return 0
    else
        error "kcadm.sh authentication failed"
        echo "Error: $result"
        return 1
    fi
}

# Test admin console access
test_admin_console() {
    log "Testing admin console access..."

    local console_response=$(curl -k -s "$KEYCLOAK_URL/admin/" 2>/dev/null || echo "ERROR")

    if echo "$console_response" | grep -q "Keycloak Administration Console\|admin\|login"; then
        success "Admin console is accessible"

        # Check if we're redirected to login
        if echo "$console_response" | grep -q "login\|signin"; then
            log "Admin console requires login (expected)"
        else
            log "Admin console loaded successfully"
        fi

        return 0
    else
        error "Admin console is not accessible"
        return 1
    fi
}

# Main test function
main() {
    echo -e "\n${BLUE}🔑 Testing Updated Keycloak Admin Creation Configuration${NC}"
    echo -e "${BLUE}======================================================${NC}\n"

    log "Testing Keycloak instance: $KEYCLOAK_URL"
    log "Admin credentials: $USERNAME / $PASSWORD"
    echo

    local test_results=()

    # Run all tests
    if test_connectivity; then
        test_results+=("✓ Connectivity")
    else
        test_results+=("✗ Connectivity")
    fi
    echo

    if test_admin_console; then
        test_results+=("✓ Admin Console")
    else
        test_results+=("✗ Admin Console")
    fi
    echo

    if test_master_realm; then
        test_results+=("✓ Master Realm")
    else
        test_results+=("✗ Master Realm")
    fi
    echo

    if test_admin_authentication; then
        test_results+=("✓ Admin Authentication")
    else
        test_results+=("✗ Admin Authentication")
    fi
    echo

    if test_kcadm_tool; then
        test_results+=("✓ kcadm.sh Tool")
    else
        test_results+=("✗ kcadm.sh Tool")
    fi
    echo

    # Summary
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}TEST SUMMARY${NC}"
    echo -e "${BLUE}======================================${NC}"

    local success_count=0
    local total_tests=${#test_results[@]}

    for result in "${test_results[@]}"; do
        echo "  $result"
        if [[ "$result" == ✓* ]]; then
            ((success_count++))
        fi
    done

    echo
    if [ $success_count -eq $total_tests ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED ($success_count/$total_tests)${NC}"
        echo -e "${GREEN}The updated Keycloak admin creation configuration is working!${NC}"
        echo
        echo -e "${BLUE}Admin Access Information:${NC}"
        echo -e "  Admin Console: $KEYCLOAK_URL/admin/"
        echo -e "  Username: $USERNAME"
        echo -e "  Password: $PASSWORD"
        echo
        echo -e "${BLUE}Integration Steps:${NC}"
        echo -e "1. The current configuration uses multiple admin creation methods"
        echo -e "2. Admin user should be available immediately after deployment"
        echo -e "3. Access the admin console to complete setup"
        echo -e "4. Create additional admin users and remove temporary account"
    elif [ $success_count -gt 0 ]; then
        echo -e "${YELLOW}⚠️  PARTIAL SUCCESS ($success_count/$total_tests tests passed)${NC}"
        echo -e "${YELLOW}Some admin creation methods are working${NC}"
    else
        echo -e "${RED}❌ ALL TESTS FAILED ($success_count/$total_tests)${NC}"
        echo -e "${RED}Admin user creation is not working${NC}"
        echo
        echo -e "${YELLOW}Troubleshooting Steps:${NC}"
        echo -e "1. Check Keycloak service logs: journalctl -u keycloak"
        echo -e "2. Verify database status: systemctl status postgresql"
        echo -e "3. Check database connectivity: pg_isready -h localhost"
        echo -e "4. Review Keycloak configuration and startup parameters"
        echo -e "5. Ensure proper file permissions in /var/lib/keycloak"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi