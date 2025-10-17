#!/usr/bin/env bash
# Script to test Keycloak admin login credentials

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

# Test 1: Check if Keycloak is responding
test_keycloak_available() {
    log "Testing Keycloak availability..."

    if curl -k -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/" | grep -q "200"; then
        success "Keycloak is accessible at $KEYCLOAK_URL"
        return 0
    else
        error "Keycloak is not accessible at $KEYCLOAK_URL"
        return 1
    fi
}

# Test 2: Check admin console
test_admin_console() {
    log "Testing admin console availability..."

    if curl -k -s "$KEYCLOAK_URL/admin/" | grep -q "Keycloak Administration Console"; then
        success "Admin console is accessible"
        return 0
    else
        error "Admin console is not accessible"
        return 1
    fi
}

# Test 3: Test different token endpoint paths
test_token_endpoints() {
    log "Testing different token endpoint paths..."

    local paths=(
        "/realms/master/protocol/openid_connect/token"
        "/auth/realms/master/protocol/openid_connect/token"
        "/realms/master/protocol/openid-connect/token"
        "/auth/realms/master/protocol/openid-connect/token"
    )

    for path in "${paths[@]}"; do
        log "Testing endpoint: $KEYCLOAK_URL$path"

        response=$(curl -k -s -X POST "$KEYCLOAK_URL$path" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "username=$USERNAME" \
            -d "password=$PASSWORD" \
            -d "grant_type=password" \
            -d "client_id=admin-cli" 2>/dev/null || echo '{"error":"request_failed"}')

        if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
            success "Token endpoint working: $path"
            echo "Response: $response" | jq '.'
            return 0
        else
            warning "Token endpoint failed: $path"
            echo "Response: $response"
        fi
    done

    error "No working token endpoints found"
    return 1
}

# Test 4: Check master realm configuration
test_master_realm() {
    log "Testing master realm configuration..."

    local paths=(
        "/realms/master/.well-known/openid_connect_configuration"
        "/auth/realms/master/.well-known/openid_connect_configuration"
        "/realms/master/.well-known/openid-connect-configuration"
        "/auth/realms/master/.well-known/openid-connect-configuration"
    )

    for path in "${paths[@]}"; do
        log "Testing realm config: $KEYCLOAK_URL$path"

        response=$(curl -k -s "$KEYCLOAK_URL$path" 2>/dev/null || echo '{"error":"request_failed"}')

        if echo "$response" | jq -e '.token_endpoint' >/dev/null 2>&1; then
            success "Master realm configuration found: $path"
            echo "Token endpoint: $(echo "$response" | jq -r '.token_endpoint')"
            return 0
        else
            warning "Realm config not found: $path"
        fi
    done

    error "Master realm configuration not found"
    return 1
}

# Test 5: Test different client IDs
test_client_ids() {
    log "Testing different client IDs..."

    local token_endpoint="/realms/master/protocol/openid_connect/token"
    local client_ids=("admin-cli" "security-admin-console" "account" "master-realm")

    for client_id in "${client_ids[@]}"; do
        log "Testing client ID: $client_id"

        response=$(curl -k -s -X POST "$KEYCLOAK_URL$token_endpoint" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "username=$USERNAME" \
            -d "password=$PASSWORD" \
            -d "grant_type=password" \
            -d "client_id=$client_id" 2>/dev/null || echo '{"error":"request_failed"}')

        if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
            success "Login successful with client ID: $client_id"
            echo "Access token received"
            return 0
        else
            warning "Login failed with client ID: $client_id"
            echo "Response: $response"
        fi
    done

    error "No working client IDs found"
    return 1
}

# Test 6: Test direct admin API access
test_admin_api() {
    log "Testing direct admin API access..."

    # Try to access admin API endpoints directly
    local endpoints=(
        "/admin/realms"
        "/admin/serverinfo"
        "/admin/realms/master"
    )

    for endpoint in "${endpoints[@]}"; do
        log "Testing endpoint: $KEYCLOAK_URL$endpoint"

        response=$(curl -k -s "$KEYCLOAK_URL$endpoint" 2>/dev/null || echo "request_failed")

        if echo "$response" | grep -q "realm\|Unauthorized\|login"; then
            if echo "$response" | grep -q "Unauthorized"; then
                warning "Endpoint exists but requires authentication: $endpoint"
            else
                success "Endpoint accessible: $endpoint"
            fi
        else
            warning "Endpoint not accessible: $endpoint"
        fi
    done
}

# Test 7: Test different authentication methods
test_auth_methods() {
    log "Testing alternative authentication methods..."

    # Test with different grant types
    local grant_types=("password" "client_credentials")
    local token_endpoint="/realms/master/protocol/openid_connect/token"

    for grant_type in "${grant_types[@]}"; do
        log "Testing grant type: $grant_type"

        if [ "$grant_type" = "password" ]; then
            response=$(curl -k -s -X POST "$KEYCLOAK_URL$token_endpoint" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=$USERNAME" \
                -d "password=$PASSWORD" \
                -d "grant_type=$grant_type" \
                -d "client_id=admin-cli" 2>/dev/null || echo '{"error":"request_failed"}')
        else
            response=$(curl -k -s -X POST "$KEYCLOAK_URL$token_endpoint" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "client_id=admin-cli" \
                -d "grant_type=$grant_type" 2>/dev/null || echo '{"error":"request_failed"}')
        fi

        if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
            success "Authentication successful with grant type: $grant_type"
            return 0
        else
            warning "Authentication failed with grant type: $grant_type"
            echo "Response: $response"
        fi
    done
}

# Main test runner
main() {
    echo -e "\n${BLUE}🔑 Keycloak Admin Login Testing Suite${NC}"
    echo -e "${BLUE}=====================================${NC}\n"

    log "Testing admin login with credentials: $USERNAME / $PASSWORD"
    log "Keycloak URL: $KEYCLOAK_URL"
    echo

    # Run all tests
    test_keycloak_available
    echo

    test_admin_console
    echo

    test_master_realm
    echo

    test_token_endpoints
    echo

    test_client_ids
    echo

    test_admin_api
    echo

    test_auth_methods
    echo

    log "Test suite completed"

    echo -e "\n${YELLOW}Summary:${NC}"
    echo "If any of the token endpoint tests succeeded, the admin user exists and credentials work."
    echo "If all tests failed, the admin user may not be created properly."
    echo "Check the method used in the Keycloak configuration and service logs."
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi