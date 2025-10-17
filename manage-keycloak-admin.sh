#!/usr/bin/env bash
# Comprehensive Keycloak admin user management script using kcadm.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

KEYCLOAK_URL="https://auth.robitzs.ch"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin-adeci"
KCADM_PATH="/nix/store/qifg0f6jn1blfnvgdj242yz9wjn5k2bb-keycloak-26.3.4/bin/kcadm.sh"

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

# Initialize kcadm.sh session
init_kcadm() {
    log "Initializing kcadm.sh session..."

    if [ ! -f "$KCADM_PATH" ]; then
        KCADM_PATH=$(find /nix/store -name "kcadm.sh" -type f 2>/dev/null | head -1)
        if [ -z "$KCADM_PATH" ]; then
            error "kcadm.sh not found"
            return 1
        fi
    fi

    log "Using kcadm.sh from: $KCADM_PATH"

    # Configure credentials
    result=$("$KCADM_PATH" config credentials --server "$KEYCLOAK_URL" --realm master --user "$ADMIN_USERNAME" --password "$ADMIN_PASSWORD" 2>&1)

    if echo "$result" | grep -q "Logging into"; then
        success "kcadm.sh session initialized successfully"
        return 0
    else
        error "Failed to initialize kcadm.sh session"
        error "Output: $result"
        return 1
    fi
}

# List all realms
list_realms() {
    log "Listing all realms..."

    realms=$("$KCADM_PATH" get realms 2>/dev/null || echo "[]")

    if echo "$realms" | jq -e '.[0].realm' >/dev/null 2>&1; then
        success "Found realms:"
        echo "$realms" | jq -r '.[] | "  - \(.realm) (enabled: \(.enabled))"'
        return 0
    else
        warning "No realms found or cannot list realms"
        return 1
    fi
}

# List users in master realm
list_users() {
    local realm="${1:-master}"
    log "Listing users in realm: $realm"

    users=$("$KCADM_PATH" get users -r "$realm" 2>/dev/null || echo "[]")

    if echo "$users" | jq -e '.[0].username' >/dev/null 2>&1; then
        success "Found users in $realm realm:"
        echo "$users" | jq -r '.[] | "  - \(.username) (\(.firstName) \(.lastName)) - enabled: \(.enabled)"'

        # Show admin user details
        admin_user=$(echo "$users" | jq -r ".[] | select(.username == \"$ADMIN_USERNAME\")")
        if [ "$admin_user" != "null" ] && [ -n "$admin_user" ]; then
            info "Admin user details:"
            echo "$admin_user" | jq '{username, firstName, lastName, email, enabled, emailVerified, createdTimestamp}'
        fi

        return 0
    else
        warning "No users found in $realm realm"
        return 1
    fi
}

# Get realm configuration
get_realm_config() {
    local realm="${1:-master}"
    log "Getting configuration for realm: $realm"

    realm_config=$("$KCADM_PATH" get realms/"$realm" 2>/dev/null || echo "{}")

    if echo "$realm_config" | jq -e '.realm' >/dev/null 2>&1; then
        success "Realm configuration for $realm:"
        echo "$realm_config" | jq '{
            realm,
            enabled,
            displayName,
            loginWithEmailAllowed,
            registrationAllowed,
            verifyEmail,
            resetPasswordAllowed,
            sslRequired,
            accessTokenLifespan,
            accessTokenLifespanForImplicitFlow
        }'
        return 0
    else
        warning "Cannot get realm configuration for $realm"
        return 1
    fi
}

# List clients in master realm
list_clients() {
    local realm="${1:-master}"
    log "Listing clients in realm: $realm"

    clients=$("$KCADM_PATH" get clients -r "$realm" 2>/dev/null || echo "[]")

    if echo "$clients" | jq -e '.[0].clientId' >/dev/null 2>&1; then
        success "Found clients in $realm realm:"
        echo "$clients" | jq -r '.[] | "  - \(.clientId) (enabled: \(.enabled), public: \(.publicClient))"'

        # Check for admin-cli client specifically
        admin_cli=$(echo "$clients" | jq -r '.[] | select(.clientId == "admin-cli")')
        if [ "$admin_cli" != "null" ] && [ -n "$admin_cli" ]; then
            info "admin-cli client details:"
            echo "$admin_cli" | jq '{clientId, enabled, publicClient, directAccessGrantsEnabled, standardFlowEnabled}'
        fi

        return 0
    else
        warning "No clients found in $realm realm"
        return 1
    fi
}

# Create a permanent admin user
create_permanent_admin() {
    local new_username="$1"
    local new_password="$2"
    local email="$3"

    if [ -z "$new_username" ] || [ -z "$new_password" ]; then
        error "Usage: create_permanent_admin <username> <password> [email]"
        return 1
    fi

    log "Creating permanent admin user: $new_username"

    # Create user
    user_data=$(cat <<EOF
{
    "username": "$new_username",
    "email": "$email",
    "firstName": "Admin",
    "lastName": "User",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
        "type": "password",
        "value": "$new_password",
        "temporary": false
    }]
}
EOF
)

    result=$("$KCADM_PATH" create users -r master -b "$user_data" 2>&1)

    if echo "$result" | grep -q "Created new user"; then
        success "User $new_username created successfully"

        # Get user ID
        user_id=$("$KCADM_PATH" get users -r master -q "username=$new_username" | jq -r '.[0].id')

        if [ "$user_id" != "null" ] && [ -n "$user_id" ]; then
            # Add admin role
            log "Adding admin role to user $new_username..."
            "$KCADM_PATH" add-roles -r master --uusername "$new_username" --rolename admin

            success "Admin role added to user $new_username"
            success "Permanent admin user created successfully"

            info "New admin credentials:"
            echo "  Username: $new_username"
            echo "  Password: $new_password"
            echo "  Email: $email"

            return 0
        else
            error "Could not get user ID for $new_username"
            return 1
        fi
    else
        error "Failed to create user $new_username"
        error "Output: $result"
        return 1
    fi
}

# Delete temporary admin user
delete_temp_admin() {
    warning "⚠️  This will delete the temporary admin user: $ADMIN_USERNAME"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        log "Deleting temporary admin user: $ADMIN_USERNAME"

        # Get user ID
        user_id=$("$KCADM_PATH" get users -r master -q "username=$ADMIN_USERNAME" | jq -r '.[0].id')

        if [ "$user_id" != "null" ] && [ -n "$user_id" ]; then
            result=$("$KCADM_PATH" delete users/"$user_id" -r master 2>&1)

            if [ $? -eq 0 ]; then
                success "Temporary admin user $ADMIN_USERNAME deleted"
            else
                error "Failed to delete temporary admin user"
                error "Output: $result"
            fi
        else
            error "Could not find temporary admin user $ADMIN_USERNAME"
        fi
    else
        info "Operation cancelled"
    fi
}

# Test admin console access
test_admin_console() {
    log "Testing admin console access..."

    # Try different paths
    local console_paths=("/admin/" "/admin/master/console/" "/auth/admin/")

    for path in "${console_paths[@]}"; do
        log "Testing: $KEYCLOAK_URL$path"

        response=$(curl -k -s "$KEYCLOAK_URL$path" 2>/dev/null || echo "ERROR")

        if echo "$response" | grep -q "Keycloak Administration Console\|admin\|login"; then
            success "Admin console accessible at: $KEYCLOAK_URL$path"
            return 0
        fi
    done

    warning "Admin console not accessible via standard paths"
    return 1
}

# Main menu
show_menu() {
    echo
    echo -e "${BLUE}🔑 Keycloak Admin Management Menu${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "1. Initialize kcadm.sh session"
    echo "2. List all realms"
    echo "3. List users in master realm"
    echo "4. Get master realm configuration"
    echo "5. List clients in master realm"
    echo "6. Create permanent admin user"
    echo "7. Delete temporary admin user"
    echo "8. Test admin console access"
    echo "9. Run full system status check"
    echo "0. Exit"
    echo
}

# Full system status check
full_status_check() {
    echo -e "\n${PURPLE}🔍 Full Keycloak System Status Check${NC}"
    echo -e "${PURPLE}====================================${NC}\n"

    init_kcadm
    echo

    list_realms
    echo

    list_users
    echo

    get_realm_config
    echo

    list_clients
    echo

    test_admin_console
    echo

    success "System status check complete"
}

# Main function
main() {
    echo -e "\n${BLUE}🔑 Keycloak Admin User Management${NC}"
    echo -e "${BLUE}================================${NC}\n"

    log "Keycloak URL: $KEYCLOAK_URL"
    log "Admin Username: $ADMIN_USERNAME"
    echo

    # Auto-run full status check if no arguments
    if [ $# -eq 0 ]; then
        full_status_check
        echo
        echo -e "${GREEN}💡 Tip: Run with 'interactive' argument for menu mode${NC}"
        return
    fi

    if [ "$1" = "interactive" ]; then
        while true; do
            show_menu
            read -p "Select an option: " choice

            case $choice in
                1) init_kcadm ;;
                2) init_kcadm && list_realms ;;
                3) init_kcadm && list_users ;;
                4) init_kcadm && get_realm_config ;;
                5) init_kcadm && list_clients ;;
                6)
                    read -p "Enter new admin username: " new_user
                    read -s -p "Enter new admin password: " new_pass
                    echo
                    read -p "Enter email (optional): " new_email
                    init_kcadm && create_permanent_admin "$new_user" "$new_pass" "$new_email"
                    ;;
                7) init_kcadm && delete_temp_admin ;;
                8) test_admin_console ;;
                9) full_status_check ;;
                0) echo "Goodbye!"; exit 0 ;;
                *) error "Invalid option" ;;
            esac
            echo
        done
    else
        # Handle command line arguments
        case "$1" in
            "status") full_status_check ;;
            "list-users") init_kcadm && list_users ;;
            "list-realms") init_kcadm && list_realms ;;
            "create-admin")
                if [ $# -ge 3 ]; then
                    init_kcadm && create_permanent_admin "$2" "$3" "$4"
                else
                    error "Usage: $0 create-admin <username> <password> [email]"
                fi
                ;;
            *)
                echo "Usage: $0 [status|list-users|list-realms|create-admin|interactive]"
                echo "  status           - Run full system status check"
                echo "  list-users       - List users in master realm"
                echo "  list-realms      - List all realms"
                echo "  create-admin     - Create permanent admin user"
                echo "  interactive      - Interactive menu mode"
                echo
                echo "Default (no arguments): Run status check"
                ;;
        esac
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi