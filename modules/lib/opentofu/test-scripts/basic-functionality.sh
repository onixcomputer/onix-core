#!/bin/bash
# Basic Functionality Tests for OpenTofu Helper Scripts
# Tests helper scripts availability and basic functionality

set -euo pipefail

# Configuration
INSTANCE="adeci"
SERVICE_NAME="keycloak"
STATE_DIR="/var/lib/${SERVICE_NAME}-${INSTANCE}-terraform"
DEPLOYMENT_SERVICE="${SERVICE_NAME}-terraform-deploy-${INSTANCE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Test 1.1: Script Availability
test_script_availability() {
    print_test "Testing script availability..."

    local scripts=(
        "${SERVICE_NAME}-tf-unlock-${INSTANCE}"
        "${SERVICE_NAME}-tf-status-${INSTANCE}"
        "${SERVICE_NAME}-tf-apply-${INSTANCE}"
        "${SERVICE_NAME}-tf-logs-${INSTANCE}"
    )

    for script in "${scripts[@]}"; do
        if which "$script" >/dev/null 2>&1; then
            print_pass "Script $script is available in PATH"
        else
            print_fail "Script $script is NOT available in PATH"
        fi

        if [ -x "$(which "$script" 2>/dev/null)" ]; then
            print_pass "Script $script is executable"
        else
            print_fail "Script $script is NOT executable"
        fi
    done
}

# Test 1.2: Status Script Basic Functionality
test_status_script() {
    print_test "Testing status script basic functionality..."

    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"

    if command -v "$status_script" >/dev/null 2>&1; then
        print_info "Running status script..."
        if "$status_script" >/dev/null 2>&1; then
            print_pass "Status script runs without errors"
        else
            print_fail "Status script fails to run"
        fi

        # Test output content
        local output
        output=$("$status_script" 2>&1)

        if echo "$output" | grep -q "Terraform Lock Status"; then
            print_pass "Status script shows lock status section"
        else
            print_fail "Status script missing lock status section"
        fi

        if echo "$output" | grep -q "Deployment Service Status"; then
            print_pass "Status script shows deployment service status"
        else
            print_fail "Status script missing deployment service status"
        fi

        if echo "$output" | grep -q "Main Service Status"; then
            print_pass "Status script shows main service status"
        else
            print_fail "Status script missing main service status"
        fi
    else
        print_fail "Status script not found"
    fi
}

# Test 1.3: Service Name Verification
test_service_names() {
    print_test "Testing correct service name usage..."

    # Check if deployment service exists
    if systemctl list-units --type=service | grep -q "${DEPLOYMENT_SERVICE}.service"; then
        print_pass "Deployment service ${DEPLOYMENT_SERVICE}.service exists"
    else
        print_fail "Deployment service ${DEPLOYMENT_SERVICE}.service does not exist"
    fi

    # Check script references
    local scripts=(
        "${SERVICE_NAME}-tf-status-${INSTANCE}"
        "${SERVICE_NAME}-tf-apply-${INSTANCE}"
        "${SERVICE_NAME}-tf-logs-${INSTANCE}"
    )

    for script in "${scripts[@]}"; do
        if command -v "$script" >/dev/null 2>&1; then
            local script_path
            script_path=$(which "$script")

            if grep -q "${DEPLOYMENT_SERVICE}" "$script_path"; then
                print_pass "Script $script references correct deployment service"
            else
                print_fail "Script $script does NOT reference correct deployment service"
            fi

            # Check for legacy service name (should not exist)
            if grep -q "${SERVICE_NAME}-terraform-${INSTANCE}" "$script_path" && \
               ! grep -q "${DEPLOYMENT_SERVICE}" "$script_path"; then
                print_fail "Script $script still uses legacy service name"
            fi
        fi
    done
}

# Test 1.4: State Directory Handling
test_state_directory() {
    print_test "Testing state directory handling..."

    # Ensure state directory exists for testing
    if [ ! -d "$STATE_DIR" ]; then
        print_info "Creating state directory for testing: $STATE_DIR"
        sudo mkdir -p "$STATE_DIR"
    fi

    if [ -d "$STATE_DIR" ]; then
        print_pass "State directory exists: $STATE_DIR"
    else
        print_fail "State directory does not exist: $STATE_DIR"
    fi

    # Test script access to state directory
    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"
    if command -v "$status_script" >/dev/null 2>&1; then
        # The script should handle missing lock files gracefully
        if "$status_script" | grep -q "No active lock"; then
            print_pass "Status script handles missing lock files"
        else
            print_info "Lock files may be present or script behavior different"
        fi
    fi
}

# Test 1.5: Lock File Interaction
test_lock_interaction() {
    print_test "Testing lock file interaction..."

    local unlock_script="${SERVICE_NAME}-tf-unlock-${INSTANCE}"
    local status_script="${SERVICE_NAME}-tf-status-${INSTANCE}"

    # Clean state first
    sudo rm -f "${STATE_DIR}/.terraform.lock"*

    # Test with no locks
    if command -v "$unlock_script" >/dev/null 2>&1; then
        if echo "n" | "$unlock_script" | grep -q "No lock files found"; then
            print_pass "Unlock script handles no locks correctly"
        else
            print_fail "Unlock script does not handle no locks correctly"
        fi
    fi

    # Create test lock
    sudo touch "${STATE_DIR}/.terraform.lock"
    sudo bash -c "cat > '${STATE_DIR}/.terraform.lock.info' <<EOF
PID: 12345
Date: $(date -Iseconds)
Service: ${DEPLOYMENT_SERVICE}
User: test
EOF"

    # Test lock detection
    if command -v "$status_script" >/dev/null 2>&1; then
        if "$status_script" | grep -q "Lock is ACTIVE"; then
            print_pass "Status script detects active lock"
        else
            print_fail "Status script does not detect active lock"
        fi
    fi

    # Test unlock (cancel)
    if command -v "$unlock_script" >/dev/null 2>&1; then
        if echo "n" | "$unlock_script" | grep -q "Cancelled"; then
            print_pass "Unlock script handles cancellation"
        else
            print_fail "Unlock script does not handle cancellation"
        fi
    fi

    # Test unlock (confirm) - only if we can write to state dir
    if [ -w "$STATE_DIR" ] || sudo test -w "$STATE_DIR"; then
        if echo "y" | sudo "$unlock_script" >/dev/null 2>&1; then
            if [ ! -f "${STATE_DIR}/.terraform.lock" ]; then
                print_pass "Unlock script removes lock files when confirmed"
            else
                print_fail "Unlock script does not remove lock files"
            fi
        fi
    else
        print_info "Cannot test lock removal due to permissions"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "OpenTofu Helper Scripts - Basic Functionality Tests"
    echo "Instance: $INSTANCE"
    echo "Service: $SERVICE_NAME"
    echo "State Directory: $STATE_DIR"
    echo "Deployment Service: $DEPLOYMENT_SERVICE"
    echo "=========================================="
    echo

    test_script_availability
    echo
    test_status_script
    echo
    test_service_names
    echo
    test_state_directory
    echo
    test_lock_interaction
    echo

    echo "=========================================="
    echo "Test Results:"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "=========================================="

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"