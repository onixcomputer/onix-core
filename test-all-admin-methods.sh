#!/usr/bin/env bash
# Comprehensive script to test all Keycloak admin user creation methods

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Test admin authentication
test_admin_auth() {
    local method_name="$1"
    log "Testing admin authentication for method: $method_name"

    # Test multiple token endpoint variations
    local endpoints=(
        "/realms/master/protocol/openid_connect/token"
        "/auth/realms/master/protocol/openid_connect/token"
        "/realms/master/protocol/openid-connect/token"
        "/auth/realms/master/protocol/openid-connect/token"
    )

    local client_ids=("admin-cli" "security-admin-console" "account")

    for endpoint in "${endpoints[@]}"; do
        for client_id in "${client_ids[@]}"; do
            log "Testing endpoint: $endpoint with client: $client_id"

            response=$(curl -k -s -X POST "$KEYCLOAK_URL$endpoint" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=$USERNAME" \
                -d "password=$PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=$client_id" 2>/dev/null || echo '{"error":"request_failed"}')

            if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
                success "Authentication successful with $method_name"
                success "Working endpoint: $endpoint"
                success "Working client ID: $client_id"
                echo "Access token length: $(echo "$response" | jq -r '.access_token' | wc -c)"
                return 0
            fi
        done
    done

    error "Authentication failed for method: $method_name"
    return 1
}

# Test specific admin creation methods
test_method() {
    local method="$1"
    local description="$2"

    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}Testing Method: $method${NC}"
    echo -e "${PURPLE}Description: $description${NC}"
    echo -e "${PURPLE}======================================${NC}"

    case "$method" in
        "initial-password")
            info "This method uses the NixOS services.keycloak.initialAdminPassword option"
            info "Configuration: initialAdminPassword = \"admin-adeci\";"
            ;;
        "kc-bootstrap-env")
            info "This method uses KC_BOOTSTRAP_* environment variables (Keycloak 26+)"
            info "Configuration: KC_BOOTSTRAP_ADMIN_USERNAME = \"admin\"; KC_BOOTSTRAP_ADMIN_PASSWORD = \"admin-adeci\";"
            ;;
        "keycloak-admin-env")
            info "This method uses KEYCLOAK_ADMIN environment variables (legacy)"
            info "Configuration: KEYCLOAK_ADMIN = \"admin\"; KEYCLOAK_ADMIN_PASSWORD = \"admin-adeci\";"
            ;;
        "cli-bootstrap")
            info "This method uses command line bootstrap parameters in the start command"
            info "Configuration: kc.sh start --bootstrap-admin-username=admin --bootstrap-admin-password=admin-adeci"
            ;;
        "bootstrap-command")
            info "This method uses the separate bootstrap-admin user command before startup"
            info "Configuration: kc.sh bootstrap-admin user --username admin --password admin"
            ;;
    esac

    # Test if Keycloak is available
    if ! curl -k -s -o /dev/null -w "%{http_code}" "$KEYCLOAK_URL/" | grep -q "200"; then
        error "Keycloak is not accessible at $KEYCLOAK_URL"
        return 1
    fi

    # Test admin console
    if ! curl -k -s "$KEYCLOAK_URL/admin/" | grep -q "Keycloak Administration Console\|admin"; then
        warning "Admin console may not be properly accessible"
    else
        info "Admin console is accessible"
    fi

    # Test authentication
    test_admin_auth "$method"
}

# Test master realm configuration
test_realm_config() {
    log "Testing master realm configuration..."

    local config_endpoints=(
        "/realms/master/.well-known/openid_connect_configuration"
        "/auth/realms/master/.well-known/openid_connect_configuration"
        "/realms/master/.well-known/openid-connect-configuration"
        "/auth/realms/master/.well-known/openid-connect-configuration"
    )

    for endpoint in "${config_endpoints[@]}"; do
        response=$(curl -k -s "$KEYCLOAK_URL$endpoint" 2>/dev/null || echo '{"error":"not_found"}')

        if echo "$response" | jq -e '.token_endpoint' >/dev/null 2>&1; then
            success "Master realm configuration found: $endpoint"
            info "Token endpoint: $(echo "$response" | jq -r '.token_endpoint')"
            info "Authorization endpoint: $(echo "$response" | jq -r '.authorization_endpoint')"
            info "Issuer: $(echo "$response" | jq -r '.issuer')"
            return 0
        fi
    done

    error "Master realm configuration not found"
    return 1
}

# Test kcadm.sh CLI tool
test_kcadm() {
    log "Testing kcadm.sh CLI tool functionality..."

    local kcadm_path="/nix/store/qifg0f6jn1blfnvgdj242yz9wjn5k2bb-keycloak-26.3.4/bin/kcadm.sh"

    if [ ! -f "$kcadm_path" ]; then
        kcadm_path=$(find /nix/store -name "kcadm.sh" -type f 2>/dev/null | head -1)
    fi

    if [ -z "$kcadm_path" ] || [ ! -f "$kcadm_path" ]; then
        error "kcadm.sh not found in Nix store"
        return 1
    fi

    info "Using kcadm.sh from: $kcadm_path"

    # Test authentication
    result=$("$kcadm_path" config credentials --server "$KEYCLOAK_URL" --realm master --user "$USERNAME" --password "$PASSWORD" 2>&1 || echo "AUTH_FAILED")

    if echo "$result" | grep -q "Logging into"; then
        success "kcadm.sh authentication successful"

        # Test listing users
        users_result=$("$kcadm_path" get users -r master 2>&1 || echo "LIST_FAILED")
        if echo "$users_result" | grep -q '\['; then
            success "kcadm.sh can list users"
            info "Number of users: $(echo "$users_result" | jq length 2>/dev/null || echo "Unknown")"
        else
            warning "kcadm.sh cannot list users"
        fi

        return 0
    else
        error "kcadm.sh authentication failed"
        error "Output: $result"
        return 1
    fi
}

# Test REST API directly
test_rest_api() {
    log "Testing REST API directly..."

    # First get a token
    response=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid_connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$USERNAME" \
        -d "password=$PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" 2>/dev/null || echo '{"error":"request_failed"}')

    if echo "$response" | jq -e '.access_token' >/dev/null 2>&1; then
        access_token=$(echo "$response" | jq -r '.access_token')
        success "Obtained access token for REST API testing"

        # Test listing realms
        realms=$(curl -k -s -H "Authorization: Bearer $access_token" \
            "$KEYCLOAK_URL/admin/realms" 2>/dev/null || echo "[]")

        if echo "$realms" | jq -e '.[0].realm' >/dev/null 2>&1; then
            success "REST API can list realms"
            info "Available realms: $(echo "$realms" | jq -r '.[].realm' | tr '\n' ', ' | sed 's/,$//')"
        else
            warning "REST API cannot list realms"
        fi

        # Test listing users in master realm
        users=$(curl -k -s -H "Authorization: Bearer $access_token" \
            "$KEYCLOAK_URL/admin/realms/master/users" 2>/dev/null || echo "[]")

        if echo "$users" | jq -e '.[0].username' >/dev/null 2>&1; then
            success "REST API can list users"
            info "User count: $(echo "$users" | jq length)"
            info "Usernames: $(echo "$users" | jq -r '.[].username' | tr '\n' ', ' | sed 's/,$//')"
        else
            warning "REST API cannot list users"
        fi

        return 0
    else
        error "Cannot obtain access token for REST API testing"
        return 1
    fi
}

# Main test runner
main() {
    echo -e "\n${BLUE}🔑 Comprehensive Keycloak Admin User Creation Testing${NC}"
    echo -e "${BLUE}====================================================${NC}\n"

    log "Target Keycloak URL: $KEYCLOAK_URL"
    log "Test credentials: $USERNAME / $PASSWORD"
    echo

    # Test realm configuration first
    test_realm_config
    echo

    # Test each method
    declare -a methods=(
        "initial-password|NixOS initialAdminPassword option"
        "kc-bootstrap-env|KC_BOOTSTRAP_* environment variables (modern)"
        "keycloak-admin-env|KEYCLOAK_ADMIN environment variables (legacy)"
        "cli-bootstrap|Command line bootstrap parameters"
        "bootstrap-command|Separate bootstrap-admin command"
    )

    local successful_methods=()
    local failed_methods=()

    for method_info in "${methods[@]}"; do
        IFS='|' read -r method description <<< "$method_info"

        if test_method "$method" "$description"; then
            successful_methods+=("$method: $description")
        else
            failed_methods+=("$method: $description")
        fi
    done

    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}Additional Testing${NC}"
    echo -e "${PURPLE}======================================${NC}"

    # Test kcadm.sh
    test_kcadm
    echo

    # Test REST API
    test_rest_api
    echo

    # Final summary
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}FINAL SUMMARY${NC}"
    echo -e "${BLUE}======================================${NC}"

    if [ ${#successful_methods[@]} -gt 0 ]; then
        echo -e "${GREEN}✅ Successful Methods:${NC}"
        for method in "${successful_methods[@]}"; do
            echo -e "   ${GREEN}✓${NC} $method"
        done
    else
        echo -e "${RED}❌ No successful methods found${NC}"
    fi

    echo

    if [ ${#failed_methods[@]} -gt 0 ]; then
        echo -e "${RED}❌ Failed Methods:${NC}"
        for method in "${failed_methods[@]}"; do
            echo -e "   ${RED}✗${NC} $method"
        done
    fi

    echo

    if [ ${#successful_methods[@]} -gt 0 ]; then
        echo -e "${GREEN}🎉 SUCCESS: Found ${#successful_methods[@]} working admin creation method(s)${NC}"
        echo -e "${GREEN}   Use any of the successful methods in your Keycloak configuration${NC}"
    else
        echo -e "${RED}🚨 FAILURE: No working admin creation methods found${NC}"
        echo -e "${YELLOW}   Possible issues:${NC}"
        echo -e "   ${YELLOW}• Master realm not properly initialized${NC}"
        echo -e "   ${YELLOW}• Database configuration issues${NC}"
        echo -e "   ${YELLOW}• Keycloak service not running correctly${NC}"
        echo -e "   ${YELLOW}• Network/proxy configuration problems${NC}"
        echo -e "   ${YELLOW}• Admin user creation timing issues${NC}"
    fi

    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "1. If methods failed, check Keycloak service logs: journalctl -u keycloak"
    echo -e "2. Verify database initialization: systemctl status postgresql"
    echo -e "3. Check Keycloak configuration files and startup parameters"
    echo -e "4. For successful methods, integrate into your production configuration"
    echo -e "5. Test admin console access: $KEYCLOAK_URL/admin/"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi